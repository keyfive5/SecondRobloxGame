// Edit-mode screenshot from a given camera: node tools/cap.mjs <name> cx cy cz lx ly lz
// Saves scratch/captures/<name>.png and prints the path.
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const here = dirname(fileURLToPath(import.meta.url));
const [, , name = 'cap', ...nums] = process.argv;
const args = { capture_id: name };
if (nums.length >= 6) {
  const n = nums.map(Number);
  args.camera_position = n.slice(0, 3);
  args.look_at_position = n.slice(3, 6);
}
const out = execFileSync('node', [join(here, 'studio.mjs'), 'call', 'screen_capture', JSON.stringify(args)], {
  encoding: 'utf8', env: { ...process.env, CAP_NAME: name }, maxBuffer: 64 * 1024 * 1024,
});
process.stdout.write(out);
