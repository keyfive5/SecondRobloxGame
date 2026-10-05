// Push everything under src/ into the open Roblox Studio place (Rojo-style layout).
//   src/<Service>/<Folder>/<Name>.luau         -> ModuleScript
//   src/<Service>/<Folder>/<Name>.server.luau  -> Script
//   src/<Service>/<Folder>/<Name>.client.luau  -> LocalScript
// Folders are created as needed. Scripts this tool created earlier that no longer
// exist in src/ are removed. Every file is syntax-checked inside Studio first.
import { readdirSync, readFileSync, statSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, relative, sep, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', 'src');

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (name.endsWith('.luau') || name.endsWith('.lua')) out.push(p);
  }
  return out;
}

function classify(file) {
  const rel = relative(root, file).split(sep);
  let name = rel.pop().replace(/\.luau?$/, '');
  let cls = 'ModuleScript';
  if (name.endsWith('.server')) { cls = 'Script'; name = name.slice(0, -7); }
  else if (name.endsWith('.client')) { cls = 'LocalScript'; name = name.slice(0, -7); }
  return { path: [...rel, name], cls, source: readFileSync(file, 'utf8').replace(/\r\n/g, '\n') };
}

function longString(s) {
  let n = 0;
  while (s.includes(']' + '='.repeat(n) + ']')) n++;
  const eq = '='.repeat(n);
  return `[${eq}[\n${s}]${eq}]`;
}

const files = walk(root).map(classify);
const header = `
local function ensure(path, className)
	local cur = game:GetService(path[1])
	for i = 2, #path - 1 do
		local nxt = cur:FindFirstChild(path[i])
		if not nxt then nxt = Instance.new("Folder"); nxt.Name = path[i]; nxt.Parent = cur end
		cur = nxt
	end
	local name = path[#path]
	local inst = cur:FindFirstChild(name)
	if inst and inst.ClassName ~= className then inst:Destroy(); inst = nil end
	if not inst then inst = Instance.new(className); inst.Name = name; inst.Parent = cur end
	inst:SetAttribute("Synced", true)
	return inst
end
local errors, count = {}, 0
local function put(path, className, src)
	local _, err = loadstring(src, table.concat(path, "."))
	if err then table.insert(errors, err) end
	local s = ensure(path, className)
	if s.Source ~= src then s.Source = src; count += 1 end
end
`;

const batches = [];
let cur = [], size = 0;
for (const f of files) {
  const stmt = `put(${JSON.stringify(f.path).replace(/^\[/, '{').replace(/\]$/, '}')}, "${f.cls}", ${longString(f.source)})\n`;
  if (size + stmt.length > 180000 && cur.length) { batches.push(cur); cur = []; size = 0; }
  cur.push(stmt); size += stmt.length;
}
if (cur.length) batches.push(cur);

const keep = files.map(f => f.path.join('.'));
const cleanup = `
local keep = {}
for _, k in ipairs(${JSON.stringify(keep).replace(/^\[/, '{').replace(/\]$/, '}')}) do keep[k] = true end
local removed = 0
for _, svc in ipairs({ "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterGui", "Workspace" }) do
	for _, d in ipairs(game:GetService(svc):GetDescendants()) do
		if d:IsA("LuaSourceContainer") and d:GetAttribute("Synced") then
			local parts, x = {}, d
			while x and x ~= game do table.insert(parts, 1, x.Name); x = x.Parent end
			if not keep[table.concat(parts, ".")] then d:Destroy(); removed += 1 end
		end
	end
end
return removed
`;

function run(code) {
  const tmp = join(mkdtempSync(join(tmpdir(), 'rbx-')), 'args.json');
  writeFileSync(tmp, JSON.stringify({ datamodel_type: 'Edit', code }));
  return execFileSync('node', [join(here, 'studio.mjs'), 'call', 'execute_luau', '@' + tmp], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim();
}

let failed = false;
for (const b of batches) {
  const out = run(header + b.join('') + `\nreturn (#errors > 0 and ("SYNTAX ERRORS:\\n" .. table.concat(errors, "\\n")) or "") .. "\\nupdated " .. count`);
  console.log(out);
  if (out.includes('SYNTAX ERRORS') || out.includes('[isError]')) failed = true;
}
console.log('removed stale:', run(cleanup));
console.log(`${files.length} files synced`);
process.exit(failed ? 1 : 0);
