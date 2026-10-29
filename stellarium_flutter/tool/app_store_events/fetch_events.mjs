import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

import './env.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const EVENTS_FILE = path.join(HERE, 'events.yaml');

const LOCALES = ['en', 'de', 'es', 'fr', 'zh'];

/**
 * Major annual meteor showers (approximate peak night, month is 1-based).
 * Peaks drift by ~a day between years - always sanity-check against the
 * IMO calendar (imo.net) before submitting to Apple.
 */
const METEOR_SHOWERS = [
  { slug: 'quadrantids', name: 'Quadrantid Meteor Shower', month: 1, day: 3, zhr: 120 },
  { slug: 'lyrids', name: 'Lyrid Meteor Shower', month: 4, day: 22, zhr: 18 },
  { slug: 'eta-aquariids', name: 'Eta Aquariid Meteor Shower', month: 5, day: 5, zhr: 50 },
  { slug: 'perseids', name: 'Perseid Meteor Shower', month: 8, day: 12, zhr: 100 },
  { slug: 'orionids', name: 'Orionid Meteor Shower', month: 10, day: 21, zhr: 20 },
  { slug: 'leonids', name: 'Leonid Meteor Shower', month: 11, day: 17, zhr: 15 },
  { slug: 'geminids', name: 'Geminid Meteor Shower', month: 12, day: 13, zhr: 150 },
];

function iso(year, month, day, hour = 0) {
  return new Date(Date.UTC(year, month - 1, day, hour)).toISOString().replace('.000', '');
}

function showerToEvent(shower, year) {
  const peak = new Date(Date.UTC(year, shower.month - 1, shower.day));
  const dayBefore = new Date(peak.getTime() - 86_400_000);
  const dayAfter = new Date(peak.getTime() + 86_400_000);
  const publish = new Date(peak.getTime() - 15 * 86_400_000);
  return {
    id: `${shower.slug}-${year}`,
    baseName: shower.name,
    baseShort: `Up to ${shower.zhr} meteors per hour - find the best viewing time for your location.`,
    baseLong:
      `The ${shower.name.replace(' Meteor Shower', 's')} peak around ` +
      `${peak.toISOString().slice(0, 10)}. Open the live sky view to find the radiant ` +
      `above your horizon and the best viewing window for your exact location.`,
    publishStart: iso(publish.getUTCFullYear(), publish.getUTCMonth() + 1, publish.getUTCDate()),
    eventStart: iso(dayBefore.getUTCFullYear(), dayBefore.getUTCMonth() + 1, dayBefore.getUTCDate(), 18),
    eventEnd: iso(dayAfter.getUTCFullYear(), dayAfter.getUTCMonth() + 1, dayAfter.getUTCDate(), 6),
    imagePrompt:
      'A meteor shower over a dramatic dark landscape at night, several bright ' +
      'meteor streaks radiating from one point in a star-filled sky, Milky Way visible',
  };
}

/** Very small ICS parser - good enough for all-day astronomy calendars. */
function parseIcs(text) {
  const events = [];
  // Unfold continuation lines, then split into VEVENT blocks
  const unfolded = text.replace(/\r?\n[ \t]/g, '');
  for (const block of unfolded.split('BEGIN:VEVENT').slice(1)) {
    const field = (name) =>
      block.match(new RegExp(`^${name}[^:]*:(.*)$`, 'm'))?.[1]?.trim();
    const dt = (v) => {
      if (!v) return null;
      const m = v.match(/(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?/);
      if (!m) return null;
      return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +(m[4] ?? 0), +(m[5] ?? 0)));
    };
    const summary = field('SUMMARY');
    const start = dt(field('DTSTART'));
    if (!summary || !start) continue;
    events.push({
      summary,
      description: field('DESCRIPTION')?.replace(/\\n/g, ' ').replace(/\\,/g, ',') ?? '',
      start,
      end: dt(field('DTEND')) ?? new Date(start.getTime() + 86_400_000),
    });
  }
  return events;
}

function icsToEvent(v) {
  const slug = v.summary.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
  const publish = new Date(v.start.getTime() - 15 * 86_400_000);
  return {
    id: `${slug}-${v.start.getUTCFullYear()}`,
    baseName: v.summary,
    baseShort: `${v.summary} - see it live in the app.`,
    baseLong: v.description || `${v.summary}. Open the live sky view to watch from your exact location.`,
    publishStart: publish.toISOString().replace('.000', ''),
    eventStart: v.start.toISOString().replace('.000', ''),
    eventEnd: v.end.toISOString().replace('.000', ''),
    imagePrompt:
      `${v.summary}, dramatic astronomical scene in a dark night sky over a scenic landscape`,
  };
}

/** Localize copy for one event via OpenAI chat; falls back to English everywhere. */
async function localizeCopy(event) {
  const english = {
    name: event.baseName,
    shortDescription: event.baseShort,
    longDescription: event.baseLong,
  };
  const fallback = Object.fromEntries(LOCALES.map((l) => [l, english]));
  if (!process.env.OPENAI_API_KEY) return fallback;

  try {
    const res = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: process.env.COPY_MODEL ?? 'gpt-5-mini',
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content:
              'Translate App Store event copy. Reply with JSON: keys en, de, es, fr, zh; ' +
              'each an object with name, shortDescription (max 50 chars), ' +
              'longDescription (max 120 chars). German uses informal "du". ' +
              'Keep astronomy terms accurate; do not add marketing fluff.',
          },
          { role: 'user', content: JSON.stringify(english) },
        ],
      }),
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json.error?.message ?? `HTTP ${res.status}`);
    const parsed = JSON.parse(json.choices[0].message.content);
    for (const l of LOCALES) {
      if (!parsed[l]?.name) throw new Error(`missing locale ${l}`);
    }
    return parsed;
  } catch (e) {
    console.warn(`  localization failed (${e.message}) - using English for all locales`);
    return fallback;
  }
}

/**
 * Import events into events.yaml. Returns the ids that were added.
 * source: { year?, icsUrl? } - meteor showers for `year` and/or an ICS feed.
 * New entries are appended as YAML text so hand-written comments survive.
 */
export async function importEvents({ year, icsUrl } = {}) {
  const doc = yaml.load(fs.readFileSync(EVENTS_FILE, 'utf8'));
  const existing = new Set(doc.events.map((e) => e.id));

  const candidates = [];
  if (year) candidates.push(...METEOR_SHOWERS.map((s) => showerToEvent(s, year)));
  if (icsUrl) {
    const res = await fetch(icsUrl);
    if (!res.ok) throw new Error(`ICS fetch failed: ${res.status}`);
    candidates.push(...parseIcs(await res.text()).map(icsToEvent));
  }

  const fresh = candidates.filter(
    (e) => !existing.has(e.id) && new Date(e.eventEnd) > Date.now(),
  );

  const added = [];
  let appendix = '';
  for (const event of fresh) {
    console.log(`importing ${event.id}...`);
    const copy = await localizeCopy(event);
    const entry = {
      id: event.id,
      name: Object.fromEntries(LOCALES.map((l) => [l, copy[l].name])),
      shortDescription: Object.fromEntries(LOCALES.map((l) => [l, copy[l].shortDescription])),
      longDescription: Object.fromEntries(LOCALES.map((l) => [l, copy[l].longDescription])),
      publishStart: event.publishStart,
      eventStart: event.eventStart,
      eventEnd: event.eventEnd,
      imagePrompt: event.imagePrompt,
    };
    appendix += '\n' + yaml
      .dump([entry], { lineWidth: 90 })
      .split('\n')
      .map((line) => (line ? `  ${line}` : line))
      .join('\n');
    added.push(event.id);
  }

  if (appendix) fs.appendFileSync(EVENTS_FILE, appendix);
  return added;
}

// CLI: node fetch_events.mjs [--year 2026] [--ics <url>]
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const year = args.includes('--year')
    ? Number(args[args.indexOf('--year') + 1])
    : new Date().getFullYear();
  const icsUrl = args.includes('--ics') ? args[args.indexOf('--ics') + 1] : null;
  importEvents({ year, icsUrl }).then((added) => {
    console.log(added.length ? `Added: ${added.join(', ')}` : 'Nothing new to import.');
  });
}
