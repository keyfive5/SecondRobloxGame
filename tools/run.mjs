// Run a Luau file (or inline code) in Studio via execute_luau.
// Usage: node tools/run.mjs file.luau [Edit|Server|Client]
//        node tools/run.mjs -e "return 1+1" [Edit|Server|Client]
// A line `--#include path/to/lib.luau` is replaced by that file's contents
// (paths relative to the repo root), so build scripts can share helpers.
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const expand = src => src.replace(/^--#include\s+(\S+)\s*$/gm, (_, p) => expand(readFileSync(join(root, p), 'utf8')));
let [, , a, b, c] = process.argv;
let code, dm;
if (a === '-e') { code = b; dm = c || 'Edit'; } else { code = expand(readFileSync(a, 'utf8')); dm = b || 'Edit'; }
const tmp = join(mkdtempSync(join(tmpdir(), 'rbx-')), 'args.json');
writeFileSync(tmp, JSON.stringify({ datamodel_type: dm, code }));
try {
  const out = execFileSync('node', [join(here, 'studio.mjs'), 'call', 'execute_luau', '@' + tmp], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  process.stdout.write(out);
  if (out.includes('[isError]')) process.exit(1);
} catch (e) { process.stdout.write(e.stdout || ''); process.stderr.write(e.stderr || ''); process.exit(1); }
