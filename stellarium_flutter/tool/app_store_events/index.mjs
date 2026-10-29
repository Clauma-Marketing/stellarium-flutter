import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';
import { AscClient } from './asc_client.mjs';
import { generateEventArt, ASSET_SPECS } from './openai_image.mjs';

import './env.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ASSET_DIR = path.join(HERE, 'assets');

// App locale -> App Store Connect locale
const ASC_LOCALES = { en: 'en-US', de: 'de-DE', es: 'es-ES', fr: 'fr-FR', zh: 'zh-Hans' };

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const SKIP_IMAGES = args.includes('--skip-images');
const NO_SUBMIT = args.includes('--no-submit');
const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null;
const windowDays = args.includes('--window-days')
  ? Number(args[args.indexOf('--window-days') + 1])
  : 60;

function requireEnv(name) {
  const v = process.env[name];
  if (!v) {
    console.error(`Missing env var ${name} (see README.md)`);
    process.exit(1);
  }
  return v;
}

function loadCalendar() {
  const doc = yaml.load(fs.readFileSync(path.join(HERE, 'events.yaml'), 'utf8'));
  return doc.events.map((e) => ({ ...doc.defaults, ...e }));
}

/** Generate (or reuse cached) art for one event and asset type. */
async function eventArt(event, assetType) {
  fs.mkdirSync(ASSET_DIR, { recursive: true });
  const file = path.join(ASSET_DIR, `${event.id}-${assetType.toLowerCase()}.png`);
  if (fs.existsSync(file)) {
    console.log(`  image cached: ${path.basename(file)}`);
    return fs.readFileSync(file);
  }
  const prompt = `${event.imagePrompt}. Style: ${event.imageStyle}`;
  console.log(`  generating ${assetType} image via OpenAI...`);
  const buffer = await generateEventArt(prompt, ASSET_SPECS[assetType]);
  fs.writeFileSync(file, buffer);
  return buffer;
}

async function main() {
  const events = loadCalendar()
    .filter((e) => !only || e.id === only)
    .filter((e) => {
      const daysOut = (new Date(e.publishStart) - Date.now()) / 86_400_000;
      return daysOut < windowDays && new Date(e.eventEnd) > Date.now();
    });

  if (events.length === 0) {
    console.log(`No events due within ${windowDays} days.`);
    return;
  }

  if (DRY_RUN) {
    console.log(`DRY RUN - would sync ${events.length} event(s):\n`);
    for (const e of events) {
      console.log(`- ${e.id}: "${e.name.en}" [${e.badge}]`);
      console.log(`    publish ${e.publishStart}  event ${e.eventStart} -> ${e.eventEnd}`);
      console.log(`    locales: ${Object.keys(e.name).join(', ')}  deepLink: ${e.deepLink}`);
    }
    return;
  }

  const appId = requireEnv('ASC_APP_ID');
  if (!SKIP_IMAGES) requireEnv('OPENAI_API_KEY');
  const asc = new AscClient({
    issuerId: requireEnv('ASC_ISSUER_ID'),
    keyId: requireEnv('ASC_KEY_ID'),
    privateKeyPath: requireEnv('ASC_KEY_PATH'),
  });

  // The API requires explicit territories per schedule (no "all" default)
  const territories = await asc.listTerritoryIds();
  console.log(`${territories.length} App Store territories.`);

  const existing = await asc.listEvents(appId);
  const existingByName = new Map(existing.map((e) => [e.attributes.referenceName, e]));
  console.log(`${existing.length} event(s) already in App Store Connect.`);
  if (existing.length + events.length > 10) {
    console.warn(
      'WARNING: Apple allows ~10 approved in-app events at a time - archive old events if creation fails.',
    );
  }

  for (const event of events) {
    // A DRAFT left by an interrupted run is resumed (missing localizations /
    // media are filled in and it is submitted); anything past DRAFT is done.
    const prior = existingByName.get(event.id);
    if (prior && prior.attributes.eventState !== 'DRAFT') {
      console.log(`skip ${event.id}: already exists (${prior.attributes.eventState})`);
      continue;
    }
    console.log(`\n${prior ? 'resuming draft' : 'creating'} ${event.id}...`);

    // Apple rejects publishStart values in the past, and allows at most 14
    // days between publishStart and eventStart - clamp to whichever is later.
    const minPublish = new Date(
      Math.max(
        Date.now() + 10 * 60_000,
        new Date(event.eventStart).getTime() - 14 * 86_400_000 + 3_600_000,
      ),
    );
    const publishStart =
      new Date(event.publishStart) < minPublish
        ? minPublish.toISOString().replace(/\.\d{3}Z$/, 'Z')
        : event.publishStart;
    if (publishStart !== event.publishStart) {
      console.log(`  publishStart clamped: ${event.publishStart} -> ${publishStart}`);
    }

    let eventId;
    if (prior) {
      eventId = prior.id;
    } else {
      const created = await asc.createEvent(appId, {
        referenceName: event.id,
        badge: event.badge,
        deepLink: event.deepLink,
        purpose: event.purpose,
        priority: event.priority,
        purchaseRequirement: 'NO_COST_ASSOCIATED',
        primaryLocale: ASC_LOCALES.en,
        territorySchedules: [
          {
            publishStart,
            eventStart: event.eventStart,
            eventEnd: event.eventEnd,
            territories,
          },
        ],
      });
      eventId = created.id;
      console.log(`  event created: ${eventId}`);
    }

    const card = SKIP_IMAGES ? null : await eventArt(event, 'EVENT_CARD');
    const details = SKIP_IMAGES ? null : await eventArt(event, 'EVENT_DETAILS_PAGE');

    const priorLocs = prior ? await asc.listLocalizations(eventId) : [];
    const locByLocale = new Map(priorLocs.map((l) => [l.attributes.locale, l]));

    for (const [appLocale, ascLocale] of Object.entries(ASC_LOCALES)) {
      let loc = locByLocale.get(ascLocale);
      if (!loc) {
        loc = await asc.createLocalization(eventId, {
          locale: ascLocale,
          name: event.name[appLocale],
          shortDescription: event.shortDescription[appLocale],
          longDescription: event.longDescription[appLocale],
        });
      }
      console.log(`  localization ${ascLocale}: ${loc.id}`);
      if (card) {
        await asc.uploadScreenshot(loc.id, 'EVENT_CARD', `${event.id}-card.png`, card);
        await asc.uploadScreenshot(loc.id, 'EVENT_DETAILS_PAGE', `${event.id}-details.png`, details);
        console.log(`  media uploaded for ${ascLocale}`);
      }
    }

    if (NO_SUBMIT) {
      console.log('  --no-submit: staged, not submitted for review');
      continue;
    }

    // Apple needs a minute to process uploaded media before it accepts the
    // review submission ("not in valid state") - poll until it goes through.
    let submissionId = null;
    for (let attempt = 1; attempt <= 12 && !submissionId; attempt++) {
      try {
        submissionId = await asc.submitEvent(appId, eventId);
      } catch (err) {
        if (attempt === 12 || !/not in valid state/i.test(err.message)) throw err;
        console.log(`  submit attempt ${attempt} rejected (media still processing), retrying in 30s...`);
        await new Promise((r) => setTimeout(r, 30_000));
      }
    }
    console.log(`  submitted for review: ${submissionId}`);
  }

  console.log('\nDone.');
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
