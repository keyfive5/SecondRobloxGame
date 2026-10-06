// Batch renders for marketing: node tools/photo.mjs <jobs.json>
// jobs.json = [{ "name": "dragon_sprout", "kind": "dragon", "args": { "sp": "sprout" } }, ...]
// Each job places the subject with build/photo.luau, captures it with Studio's
// screen_capture, and saves scratch/captures/<name>.jpg (key it with tools/key.py).
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const template = readFileSync(join(root, 'build', 'photo.luau'), 'utf8');

function runLuau(code) {
  const expanded = code.replace(/^--#include\s+(\S+)\s*$/gm, (_, p) => readFileSync(join(root, p), 'utf8'));
  const tmp = join(mkdtempSync(join(tmpdir(), 'rbx-')), 'args.json');
  writeFileSync(tmp, JSON.stringify({ datamodel_type: 'Edit', code: expanded }));
  return execFileSync('node', [join(here, 'studio.mjs'), 'call', 'execute_luau', '@' + tmp], { encoding: 'utf8', maxBuffer: 64 << 20 }).trim();
}

for (const job of jobs) {
  const code = template.replace('%KIND%', job.kind).replace('%ARGS%', JSON.stringify(job.args || {}));
  const out = runLuau(code);
  const nums = out.split(/\s+/).map(Number);
  if (nums.length < 6 || nums.some(Number.isNaN)) { console.error(job.name, 'failed:', out); continue; }
  const cap = execFileSync('node', [join(here, 'cap.mjs'), job.name, ...nums.map(String)], { encoding: 'utf8' }).trim();
  console.log(cap);
}
runLuau(template.replace('%KIND%', 'clear').replace('%ARGS%', '{}'));
