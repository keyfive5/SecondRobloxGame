// Tiny MCP client for Roblox Studio's built-in StudioMCP.exe (stdio JSON-RPC).
// Usage: node tools/studio.mjs list
//        node tools/studio.mjs call <tool> '<json args>'
//        node tools/studio.mjs call <tool> @file.json
//
// Several Studio windows can be open at once (each registers with the proxy a few
// seconds after it starts). Calls go to the window whose name contains
// $STUDIO_NAME, or the text in tools/studio-target.txt, waiting for it to connect.
import { spawn } from 'node:child_process';
import { readdirSync, readFileSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const versions = join(process.env.LOCALAPPDATA, 'Roblox', 'Versions');
const exe = readdirSync(versions).map(v => join(versions, v, 'StudioMCP.exe')).find(existsSync);
if (!exe) { console.error('StudioMCP.exe not found'); process.exit(1); }

const targetFile = join(here, 'studio-target.txt');
const target = process.env.STUDIO_NAME || (existsSync(targetFile) ? readFileSync(targetFile, 'utf8').trim() : '');

const [, , cmd = 'list', tool, rawArgs] = process.argv;
let args = {};
if (rawArgs) args = rawArgs.startsWith('@') ? JSON.parse(readFileSync(rawArgs.slice(1), 'utf8')) : JSON.parse(rawArgs);

const child = spawn(exe, ['--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = '', id = 0;
const pending = new Map();
child.stdout.on('data', d => {
  buf += d.toString();
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id != null && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  }
});
child.stderr.on('data', d => { if (process.env.MCP_DEBUG) process.stderr.write(d); });
const send = (method, params) => new Promise(res => {
  const mid = ++id; pending.set(mid, res);
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: mid, method, params }) + '\n');
});
const notify = (method, params) => child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
const sleep = ms => new Promise(r => setTimeout(r, ms));

const timeout = setTimeout(() => { console.error('timeout'); child.kill(); process.exit(2); }, Number(process.env.MCP_TIMEOUT || 180000));
await send('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'secondrobloxgame', version: '1' } });
notify('notifications/initialized', {});

async function studios() {
  const r = await send('tools/call', { name: 'list_roblox_studios', arguments: {} });
  try { return JSON.parse(r.result.content[0].text).studios || []; } catch { return []; }
}
const matches = s => !target || (s.name || '').toLowerCase().includes(target.toLowerCase());

let out;
if (cmd === 'list') {
  out = await send('tools/list', {});
  if (out.result) out = out.result.tools.map(t => ({ name: t.name, description: t.description, input: t.inputSchema }));
} else {
  // Studio windows retry the proxy every ~5 s, so give every open window time to connect.
  let list = [], pick;
  for (let i = 0; i < 50 && !pick; i++) {
    list = await studios();
    pick = list.find(s => s.name && matches(s));
    if (!pick) await sleep(500);
  }
  if (tool === 'list_roblox_studios') { console.log(JSON.stringify(list, null, 2)); child.kill(); process.exit(0); }
  if (!pick) { console.error(`No Studio matching "${target}" connected. Seen: ${JSON.stringify(list)}`); child.kill(); process.exit(3); }
  if (!args.studio_id) args.studio_id = pick.id;
  out = await send('tools/call', { name: tool, arguments: args });
  if (out.result?.content) {
    const capDir = join(here, '..', 'scratch', 'captures'); let n = 0;
    out = out.result.content.map(c => {
      if (c.type === 'image' && c.data) {
        mkdirSync(capDir, { recursive: true });
        const ext = (c.mimeType || 'image/png').split('/')[1].replace('jpeg', 'jpg');
        const f = join(capDir, (process.env.CAP_NAME || ('cap_' + Date.now())) + (n++ ? '_' + n : '') + '.' + ext);
        writeFileSync(f, Buffer.from(c.data, 'base64'));
        return '[image saved] ' + f;
      }
      return c.text ?? JSON.stringify(c);
    }).join('\n') + (out.result.isError ? '\n[isError]' : '');
  }
}
clearTimeout(timeout);
console.log(typeof out === 'string' ? out : JSON.stringify(out, null, 2));
child.kill();
process.exit(0);
