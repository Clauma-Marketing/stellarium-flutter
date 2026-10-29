#!/usr/bin/env node
// Replace App Store screenshots for ALL locales of the editable version with
// the rendered sets in tool/store_screenshots/out/<lang>/.
//
// Usage: node tool/asc_upload_shots.mjs [--version 3.6.0] [--locale tr ...]

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AscClient } from './app_store_events/asc_client.mjs';

const APP_ID = '1542535191';
const LOCALE_DIRS = {
  'en-US': 'en', 'de-DE': 'de', 'es-ES': 'es', 'es-MX': 'es', 'fr-FR': 'fr',
  'zh-Hans': 'zh', tr: 'tr', it: 'it', pl: 'pl', ro: 'ro',
};
const SETS = {
  APP_IPHONE_67: [1, 2, 3, 4, 5, 6, 7].map((i) => `APP_IPHONE_67_${i}.png`),
  APP_IPAD_PRO_3GEN_129: [1, 2, 3].map((i) => `APP_IPAD_PRO_3GEN_129_${i}.png`),
};

const here = path.dirname(fileURLToPath(import.meta.url));
const env = Object.fromEntries(
  fs.readFileSync(path.join(here, 'release.env'), 'utf8').split('\n')
    .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/)).filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const shotsDir = path.join(here, 'store_screenshots/out');

const args = process.argv.slice(2);
const arg = (n) => { const i = args.indexOf(`--${n}`); return i >= 0 ? args[i + 1] : undefined; };
const versionString = arg('version') ?? '3.6.0';
const onlyLocales = args.flatMap((a, i) => (args[i - 1] === '--locale' ? [a] : []));

const asc = new AscClient({
  issuerId: env.ASC_ISSUER_ID,
  keyId: env.ASC_KEY_ID,
  privateKeyPath: path.join(os.homedir(), `.appstoreconnect/private_keys/AuthKey_${env.ASC_KEY_ID}.p8`),
});

const vers = await asc.request('GET',
  `/v1/apps/${APP_ID}/appStoreVersions?limit=5&fields[appStoreVersions]=versionString,appStoreState`);
const version = vers.data.find((v) => v.attributes.versionString === versionString);
if (!version) throw new Error(`version ${versionString} not found`);
console.log(`version ${versionString} (${version.attributes.appStoreState})`);

const locs = await asc.request('GET',
  `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale`);

for (const loc of locs.data) {
  const locale = loc.attributes.locale;
  const dir = LOCALE_DIRS[locale];
  if (!dir) { console.log(`${locale}: no local shots mapping, skipping`); continue; }
  if (onlyLocales.length && !onlyLocales.includes(locale)) continue;

  const existingSets = await asc.request('GET',
    `/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?fields[appScreenshotSets]=screenshotDisplayType`);
  for (const [dtype, files] of Object.entries(SETS)) {
    let setId = existingSets.data.find((s) => s.attributes.screenshotDisplayType === dtype)?.id;
    if (setId) {
      const cur = await asc.request('GET', `/v1/appScreenshotSets/${setId}/appScreenshots?limit=50`);
      for (const s of cur.data) await asc.request('DELETE', `/v1/appScreenshots/${s.id}`);
      if (cur.data.length) console.log(`${locale} ${dtype}: cleared ${cur.data.length}`);
    } else {
      const s = await asc.request('POST', '/v1/appScreenshotSets', {
        data: {
          type: 'appScreenshotSets',
          attributes: { screenshotDisplayType: dtype },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } },
        },
      });
      setId = s.data.id;
    }
    for (const fname of files) {
      const buf = fs.readFileSync(path.join(shotsDir, dir, fname));
      const shot = await asc.request('POST', '/v1/appScreenshots', {
        data: {
          type: 'appScreenshots',
          attributes: { fileName: `${dir}-${fname}`, fileSize: buf.length },
          relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
        },
      });
      for (const op of shot.data.attributes.uploadOperations) {
        const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]));
        const res = await fetch(op.url, {
          method: op.method, headers,
          body: buf.subarray(op.offset, op.offset + op.length),
        });
        if (!res.ok) throw new Error(`upload chunk ${res.status} for ${locale}/${fname}`);
      }
      await asc.request('PATCH', `/v1/appScreenshots/${shot.data.id}`, {
        data: {
          type: 'appScreenshots', id: shot.data.id,
          attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(buf).digest('hex') },
        },
      });
      console.log(`  ${locale} ${fname} up`);
    }
  }
}
console.log('ALL DONE');
