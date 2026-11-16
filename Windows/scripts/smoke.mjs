import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const target = process.argv[2];
const architectures = ['x64', 'arm64'];
const root = fileURLToPath(new URL('..', import.meta.url));
const packaged = architectures.includes(target)
  ? fileURLToPath(new URL(`../../dist/Windows/YiLi-win32-${target}/YiLi.exe`, import.meta.url))
  : target;
const binary = packaged ? resolve(packaged) : (await import('electron')).default;
const args = target ? ['--smoke-test'] : [root, '--smoke-test'];

const child = spawn(binary, args, { stdio: 'inherit', windowsHide: true });
const timeout = setTimeout(() => child.kill(), 60_000);
try {
  const [code, signal] = await once(child, 'exit');
  if (code !== 0) {
    throw new Error(`YiLi smoke test failed (${signal ?? `exit ${code}`}).`);
  }
  console.log('YiLi smoke test passed.');
} finally {
  clearTimeout(timeout);
}
