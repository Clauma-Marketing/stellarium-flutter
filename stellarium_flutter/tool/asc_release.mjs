#!/usr/bin/env node
// Release an uploaded iOS build on App Store Connect via the ASC API:
// create the version (if needed), wait for build processing, attach the
// build, set localized "What's New" notes, and submit for review.
//
// Usage:
//   node tool/asc_release.mjs --version 3.5.8 --build 250 [--notes notes.json] [--dry-run]
//
// Credentials come from tool/release.env (ASC_KEY_ID / ASC_ISSUER_ID); the
// .p8 must be at ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8.
// notes.json maps language prefixes to "What's New" text, e.g. {"en": "...", "de": "..."}.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AscClient } from './app_store_events/asc_client.mjs';

const APP_ID = '1542535191'; // Star Guide: Night Sky Map (iOS)

const here = path.dirname(fileURLToPath(import.meta.url));
const env = Object.fromEntries(
  fs.readFileSync(path.join(here, 'release.env'), 'utf8').split('\n')
    .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/)).filter(Boolean)
    .map((m) => [m[1], m[2]]),
);

const args = process.argv.slice(2);
const arg = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const versionString = arg('version');
const buildNumber = arg('build');
const dryRun = args.includes('--dry-run');
if (!versionString || !buildNumber) {
  console.error('Usage: node tool/asc_release.mjs --version 3.5.8 --build 250');
  process.exit(1);
}

const DEFAULT_NOTES = {
  en: '• New privacy settings with consent options\n• Fixed star name labels with special characters\n• Performance and stability improvements',
  de: '• Neue Datenschutz-Einstellungen mit Einwilligungsoptionen\n• Sternennamen mit Sonderzeichen werden jetzt korrekt angezeigt\n• Leistungs- und Stabilitätsverbesserungen',
  es: '• Nuevas opciones de privacidad y consentimiento\n• Los nombres de estrellas con caracteres especiales ahora se muestran correctamente\n• Mejoras de rendimiento y estabilidad',
  fr: '• Nouvelles options de confidentialité et de consentement\n• Les noms d’étoiles avec des caractères spéciaux s’affichent désormais correctement\n• Améliorations des performances et de la stabilité',
  zh: '• 新增隐私同意选项\n• 修复了包含特殊字符的星星名称显示问题\n• 性能与稳定性改进',
};
const notes = arg('notes')
  ? JSON.parse(fs.readFileSync(arg('notes'), 'utf8'))
  : DEFAULT_NOTES;

const asc = new AscClient({
  issuerId: env.ASC_ISSUER_ID,
  keyId: env.ASC_KEY_ID,
  privateKeyPath: path.join(
    os.homedir(), '.appstoreconnect/private_keys', `AuthKey_${env.ASC_KEY_ID}.p8`),
});

const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));

async function main() {
  // 1. Find or create the app store version.
  let versions = await asc.request('GET',
    `/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5`);
  let version = versions.data.find(
    (v) => v.attributes.versionString === versionString);
  if (version) {
    console.log(`Version ${versionString} exists (${version.attributes.appStoreState})`);
  } else {
    // Reuse the previous version's release type (manual vs after-approval).
    const releaseType = versions.data[0]?.attributes.releaseType ?? 'AFTER_APPROVAL';
    console.log(`Creating version ${versionString} (releaseType: ${releaseType})`);
    if (dryRun) return;
    version = (await asc.request('POST', '/v1/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: { platform: 'IOS', versionString, releaseType },
        relationships: { app: { data: { type: 'apps', id: APP_ID } } },
      },
    })).data;
  }

  // 2. Wait for the uploaded build to finish processing (up to ~30 min).
  let build;
  for (let i = 0; i < 60; i++) {
    const res = await asc.request('GET',
      `/v1/builds?filter[app]=${APP_ID}&filter[version]=${buildNumber}` +
      `&sort=-uploadedDate&limit=1`);
    build = res.data[0];
    const state = build?.attributes.processingState;
    if (state === 'VALID') break;
    if (state === 'FAILED' || state === 'INVALID') {
      throw new Error(`Build ${buildNumber} processing state: ${state}`);
    }
    console.log(`Build ${buildNumber}: ${state ?? 'not visible yet'} - waiting 30s...`);
    await sleep(30);
  }
  if (build?.attributes.processingState !== 'VALID') {
    throw new Error(`Build ${buildNumber} still not processed - try again later.`);
  }
  console.log(`Build ${buildNumber} processed (${build.id})`);

  // 3. Attach the build to the version.
  await asc.request('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, {
    data: { type: 'builds', id: build.id },
  });
  console.log('Build attached');

  // 4. Set localized release notes (language-prefix match, EN fallback).
  const locs = await asc.request('GET',
    `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`);
  for (const loc of locs.data) {
    const lang = loc.attributes.locale.split('-')[0].toLowerCase();
    const whatsNew = notes[lang] ?? notes.en;
    await asc.request('PATCH', `/v1/appStoreVersionLocalizations/${loc.id}`, {
      data: { type: 'appStoreVersionLocalizations', id: loc.id,
              attributes: { whatsNew } },
    });
    console.log(`Notes set for ${loc.attributes.locale}`);
  }

  // 5. Submit for review (review submissions API). Reuse an open submission
  // if one exists, else create one; then add the version and submit.
  let submission;
  const open = await asc.request('GET',
    `/v1/reviewSubmissions?filter[app]=${APP_ID}&filter[state]=READY_FOR_REVIEW&limit=1`);
  if (open.data.length) {
    submission = open.data[0];
    console.log(`Reusing open review submission ${submission.id}`);
  } else {
    submission = (await asc.request('POST', '/v1/reviewSubmissions', {
      data: {
        type: 'reviewSubmissions',
        attributes: { platform: 'IOS' },
        relationships: { app: { data: { type: 'apps', id: APP_ID } } },
      },
    })).data;
    console.log(`Created review submission ${submission.id}`);
  }

  await asc.request('POST', '/v1/reviewSubmissionItems', {
    data: {
      type: 'reviewSubmissionItems',
      relationships: {
        reviewSubmission: { data: { type: 'reviewSubmissions', id: submission.id } },
        appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } },
      },
    },
  });
  console.log('Version added to submission');

  await asc.request('PATCH', `/v1/reviewSubmissions/${submission.id}`, {
    data: { type: 'reviewSubmissions', id: submission.id,
            attributes: { submitted: true } },
  });
  console.log(`Submitted ${versionString} (${buildNumber}) for App Review.`);
}

main().catch((e) => { console.error(e.message); process.exit(1); });
