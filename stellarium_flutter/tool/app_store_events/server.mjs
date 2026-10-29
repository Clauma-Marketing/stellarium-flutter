import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';
import { importEvents } from './fetch_events.mjs';
import { generateEventArt, ASSET_SPECS } from './openai_image.mjs';

import './env.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ASSET_DIR = path.join(HERE, 'assets');
const PORT = Number(process.env.PORT ?? 4321);

function loadEvents() {
  const doc = yaml.load(fs.readFileSync(path.join(HERE, 'events.yaml'), 'utf8'));
  return doc.events.map((e) => ({ ...doc.defaults, ...e }));
}

function state() {
  const now = Date.now();
  const events = loadEvents().map((e) => {
    const card = path.join(ASSET_DIR, `${e.id}-event_card.png`);
    const details = path.join(ASSET_DIR, `${e.id}-event_details_page.png`);
    return {
      ...e,
      hasCard: fs.existsSync(card),
      hasDetails: fs.existsSync(details),
      past: new Date(e.eventEnd).getTime() < now,
    };
  });
  return {
    events,
    env: {
      openai: Boolean(process.env.OPENAI_API_KEY),
      imageModel: process.env.IMAGE_MODEL ?? 'gpt-image-2',
      ascKey: Boolean(process.env.ASC_KEY_PATH && fs.existsSync(process.env.ASC_KEY_PATH)),
      ascReady: Boolean(
        process.env.ASC_ISSUER_ID && process.env.ASC_KEY_ID &&
        process.env.ASC_KEY_PATH && process.env.ASC_APP_ID,
      ),
    },
  };
}

function json(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

async function readBody(req) {
  let data = '';
  for await (const chunk of req) data += chunk;
  return data ? JSON.parse(data) : {};
}

function runSync(args) {
  return new Promise((resolve) => {
    execFile('node', [path.join(HERE, 'index.mjs'), ...args], { timeout: 600_000 },
      (err, stdout, stderr) => resolve({ ok: !err, output: `${stdout}${stderr}` }));
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  try {
    if (req.method === 'GET' && url.pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(fs.readFileSync(path.join(HERE, 'public', 'index.html')));
      return;
    }
    if (req.method === 'GET' && url.pathname === '/api/state') {
      return json(res, 200, state());
    }
    if (req.method === 'GET' && url.pathname.startsWith('/assets/')) {
      const file = path.join(ASSET_DIR, path.basename(url.pathname));
      if (!fs.existsSync(file)) return json(res, 404, { error: 'not found' });
      res.writeHead(200, { 'Content-Type': 'image/png' });
      res.end(fs.readFileSync(file));
      return;
    }
    if (req.method === 'POST' && url.pathname.startsWith('/api/events/')) {
      const [, , , id, action] = url.pathname.split('/');
      if (action !== 'art') return json(res, 404, { error: 'unknown action' });
      const event = loadEvents().find((e) => e.id === id);
      if (!event) return json(res, 404, { error: `no event ${id}` });
      fs.mkdirSync(ASSET_DIR, { recursive: true });
      const prompt = `${event.imagePrompt}. Style: ${event.imageStyle}`;
      for (const [type, spec] of Object.entries(ASSET_SPECS)) {
        const file = path.join(ASSET_DIR, `${id}-${type.toLowerCase()}.png`);
        const force = url.searchParams.get('force') === '1';
        if (fs.existsSync(file) && !force) continue;
        fs.writeFileSync(file, await generateEventArt(prompt, spec));
      }
      return json(res, 200, { ok: true });
    }
    if (req.method === 'POST' && url.pathname === '/api/import') {
      const body = await readBody(req);
      const added = await importEvents({
        year: body.year ?? new Date().getFullYear(),
        icsUrl: body.icsUrl || null,
      });
      return json(res, 200, { added });
    }
    if (req.method === 'POST' && url.pathname === '/api/sync') {
      const body = await readBody(req);
      const args = [];
      if (body.dryRun) args.push('--dry-run');
      if (body.only) args.push('--only', body.only);
      if (body.windowDays) args.push('--window-days', String(body.windowDays));
      return json(res, 200, await runSync(args));
    }
    json(res, 404, { error: 'not found' });
  } catch (e) {
    json(res, 500, { error: e.message });
  }
});

server.listen(PORT, () => {
  console.log(`In-app events dashboard: http://localhost:${PORT}`);
});
