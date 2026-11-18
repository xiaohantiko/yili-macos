import { createWriteStream } from 'node:fs';
import { mkdir, mkdtemp, readdir, readFile, rename, rm } from 'node:fs/promises';
import { basename, join, relative, sep } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { packager } from '@electron/packager';
import yazl from 'yazl';

const project = fileURLToPath(new URL('..', import.meta.url));
const output = fileURLToPath(new URL('../../dist/Windows/', import.meta.url));
const manifest = JSON.parse(await readFile(join(project, 'package.json'), 'utf8'));
const supported = ['x64', 'arm64'];
const architectures = process.argv.length > 2 ? process.argv.slice(2) : supported;
const runtimePaths = new Set(['package.json', 'main.cjs', 'preload.cjs', 'openai.cjs', 'smoke.cjs', 'assets', 'core', 'renderer']);

if (architectures.some((arch) => !supported.includes(arch))) {
  throw new Error('Windows architecture must be x64 or arm64.');
}

const bundles = await packager({
  dir: project,
  out: output,
  name: 'YiLi',
  platform: 'win32',
  arch: [...new Set(architectures)],
  electronVersion: manifest.devDependencies.electron,
  icon: join(project, 'assets', 'AppIcon.ico'),
  win32metadata: {
    FileDescription: manifest.description,
    ProductName: manifest.productName,
  },
  asar: true,
  overwrite: true,
  prune: false,
  ignore: (path) => path !== '' && !runtimePaths.has(path.split('/')[1]),
});

await mkdir(output, { recursive: true });
const stage = await mkdtemp(join(output, '.windows-zip-'));
try {
  for (const bundle of bundles) {
    const arch = basename(bundle).split('-').at(-1);
    const name = `YiLi-${manifest.version}-Windows-${arch}.zip`;
    const zip = new yazl.ZipFile();
    const files = await readdir(bundle, { recursive: true, withFileTypes: true });
    for (const file of files) {
      if (file.isFile()) {
        const path = join(file.parentPath, file.name);
        const archivePath = relative(bundle, path).split(sep).join('/');
        zip.addFile(path, `YiLi/${archivePath}`);
      }
    }
    zip.end();
    const temporary = join(stage, name);
    await pipeline(zip.outputStream, createWriteStream(temporary, { flags: 'wx' }));
    const destination = join(output, name);
    await rename(temporary, destination);
    console.log(destination);
  }
} finally {
  await rm(stage, { recursive: true });
}
