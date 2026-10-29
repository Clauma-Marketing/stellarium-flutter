#!/usr/bin/env node
// Add new App Store listing locales (metadata + screenshots) via the ASC API.
//
// Reads tool/store_metadata/locales.json and, for each locale under
// `newLocales`:
//   1. ensures an editable appStoreVersion exists (creates --version if not),
//   2. creates the appInfoLocalization (name/subtitle),
//   3. creates the appStoreVersionLocalization (description/keywords/whatsNew),
//   4. uploads screenshots from tool/store_screenshots/out/<locale>/.
// Also patches whatsNew onto the existing locales (`existingWhatsNew`).
//
// Usage: node tool/asc_localize.mjs --version 3.6.0 [--dry-run] [--skip-shots]

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AscClient } from './app_store_events/asc_client.mjs';

const APP_ID = '1542535191'; // Star Guide: Night Sky Map (iOS)
const EDITABLE = new Set([
  'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED',
  'METADATA_REJECTED', 'INVALID_BINARY', 'WAITING_FOR_REVIEW',
]);
const SETS = {
  APP_IPHONE_67: [1, 2, 3, 4, 5].map((i) => `APP_IPHONE_67_${i}.png`),
  APP_IPAD_PRO_3GEN_129: [1, 2, 3].map((i) => `APP_IPAD_PRO_3GEN_129_${i}.png`),
};

const here = path.dirname(fileURLToPath(import.meta.url));
const env = Object.fromEntries(
  fs.readFileSync(path.join(here, 'release.env'), 'utf8').split('\n')
    .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/)).filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const meta = JSON.parse(
  fs.readFileSync(path.join(here, 'store_metadata/locales.json'), 'utf8'));
const shotsDir = path.join(here, 'store_screenshots/out');

const args = process.argv.slice(2);
const arg = (n) => { const i = args.indexOf(`--${n}`); return i >= 0 ? args[i + 1] : undefined; };
const dryRun = args.includes('--dry-run');
const skipShots = args.includes('--skip-shots');
const newVersionString = arg('version') ?? '3.6.0';

const asc = new AscClient({
  issuerId: env.ASC_ISSUER_ID,
  keyId: env.ASC_KEY_ID,
  privateKeyPath: path.join(os.homedir(), `.appstoreconnect/private_keys/AuthKey_${env.ASC_KEY_ID}.p8`),
});

async function editableVersion() {
  const res = await asc.request('GET',
    `/v1/apps/${APP_ID}/appStoreVersions?limit=10&fields[appStoreVersions]=versionString,appStoreState,platform`);
  const v = res.data.find((v) => EDITABLE.has(v.attributes.appStoreState));
  if (v) {
    console.log(`using editable version ${v.attributes.versionString} (${v.attributes.appStoreState})`);
    return v;
  }
  console.log(`no editable version — creating ${newVersionString}`);
  if (dryRun) return { id: 'DRY', attributes: { versionString: newVersionString } };
  const created = await asc.request('POST', '/v1/appStoreVersions', {
    data: {
      type: 'appStoreVersions',
      attributes: { platform: 'IOS', versionString: newVersionString },
      relationships: { app: { data: { type: 'apps', id: APP_ID } } },
    },
  });
  return created.data;
}

async function editableAppInfo() {
  const res = await asc.request('GET',
    `/v1/apps/${APP_ID}/appInfos?fields[appInfos]=appStoreState,state`);
  const infos = res.data;
  return infos.find((i) => i.attributes.appStoreState !== 'READY_FOR_SALE'
      && i.attributes.state !== 'READY_FOR_SALE') ?? infos[0];
}

async function uploadScreenshots(locale, locId) {
  for (const [dtype, files] of Object.entries(SETS)) {
    const existing = await asc.request('GET',
      `/v1/appStoreVersionLocalizations/${locId}/appScreenshotSets?fields[appScreenshotSets]=screenshotDisplayType`);
    let setId = existing.data.find((s) => s.attributes.screenshotDisplayType === dtype)?.id;
    if (setId) {
      // replace mode: drop whatever the set currently holds
      const cur = await asc.request('GET', `/v1/appScreenshotSets/${setId}/appScreenshots?limit=50`);
      for (const s of cur.data) {
        await asc.request('DELETE', `/v1/appScreenshots/${s.id}`);
      }
      if (cur.data.length) console.log(`  ${locale} ${dtype}: cleared ${cur.data.length} existing`);
    }
    if (!setId) {
      const s = await asc.request('POST', '/v1/appScreenshotSets', {
        data: {
          type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: dtype },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: locId } } },
        },
      });
      setId = s.data.id;
    }
    for (const fname of files) {
      const buf = fs.readFileSync(path.join(shotsDir, locale, fname));
      const shot = await asc.request('POST', '/v1/appScreenshots', {
        data: {
          type: 'appScreenshots',
          attributes: { fileName: `${locale}-${fname}`, fileSize: buf.length },
          relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
        },
      });
      for (const op of shot.data.attributes.uploadOperations) {
        const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
        const res = await fetch(op.url, {
          method: op.method, headers,
          body: buf.subarray(op.offset, op.offset + op.length),
        });
        if (!res.ok) throw new Error(`upload chunk ${res.status} for ${fname}`);
      }
      await asc.request('PATCH', `/v1/appScreenshots/${shot.data.id}`, {
        data: {
          type: 'appScreenshots', id: shot.data.id,
          attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(buf).digest('hex') },
        },
      });
      console.log(`  ${locale} ${fname} uploaded+committed`);
    }
  }
}

const version = await editableVersion();

// ---- app info localizations (name / subtitle) ----
const appInfo = await editableAppInfo();
const infoLocs = await asc.request('GET',
  `/v1/appInfos/${appInfo.id}/appInfoLocalizations?fields[appInfoLocalizations]=locale,name,subtitle`);
const haveInfo = new Set(infoLocs.data.map((l) => l.attributes.locale));
for (const [locale, m] of Object.entries(meta.newLocales)) {
  if (haveInfo.has(locale)) { console.log(`appInfo ${locale}: exists, skipping`); continue; }
  console.log(`appInfo ${locale}: "${m.name}" / "${m.subtitle}"`);
  if (dryRun) continue;
  await asc.request('POST', '/v1/appInfoLocalizations', {
    data: {
      type: 'appInfoLocalizations',
      attributes: { locale, name: m.name, subtitle: m.subtitle },
      relationships: { appInfo: { data: { type: 'appInfos', id: appInfo.id } } },
    },
  });
}

// ---- version localizations (description / keywords / whatsNew) ----
const verLocs = await asc.request('GET',
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale`);
const haveVer = new Map(verLocs.data.map((l) => [l.attributes.locale, l.id]));

for (const [locale, m] of Object.entries(meta.newLocales)) {
  let locId = haveVer.get(locale);
  if (locId) {
    console.log(`versionLoc ${locale}: exists, updating text`);
    if (!dryRun) {
      await asc.request('PATCH', `/v1/appStoreVersionLocalizations/${locId}`, {
        data: {
          type: 'appStoreVersionLocalizations', id: locId,
          attributes: { description: m.description, keywords: m.keywords, whatsNew: m.whatsNew },
        },
      });
    }
  } else {
    console.log(`versionLoc ${locale}: creating`);
    if (dryRun) continue;
    const created = await asc.request('POST', '/v1/appStoreVersionLocalizations', {
      data: {
        type: 'appStoreVersionLocalizations',
        attributes: { locale, description: m.description, keywords: m.keywords, whatsNew: m.whatsNew },
        relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
      },
    });
    locId = created.data.id;
  }
  if (!skipShots && !dryRun) await uploadScreenshots(locale, locId);
}

for (const [locale, whatsNew] of Object.entries(meta.existingWhatsNew)) {
  const locId = haveVer.get(locale);
  if (!locId) { console.log(`whatsNew ${locale}: localization missing on version, skipping`); continue; }
  console.log(`whatsNew ${locale}: patching`);
  if (dryRun) continue;
  await asc.request('PATCH', `/v1/appStoreVersionLocalizations/${locId}`, {
    data: { type: 'appStoreVersionLocalizations', id: locId, attributes: { whatsNew } },
  });
}

console.log('DONE');
