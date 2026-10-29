import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Load .env and let it OVERRIDE shell variables - this tool's .env is the
// source of truth (a stale OPENAI_API_KEY exported by the user's shell
// profile would otherwise silently win over the key configured here).
const envFile = path.join(path.dirname(fileURLToPath(import.meta.url)), '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith('#')) process.env[m[1]] = m[2];
  }
}
