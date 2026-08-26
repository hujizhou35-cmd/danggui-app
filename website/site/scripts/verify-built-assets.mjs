import { access, readFile, readdir, stat } from 'node:fs/promises';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const configPath = join(projectRoot, 'dist', 'server', 'wrangler.json');

async function listFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await listFiles(path));
    if (entry.isFile()) files.push(path);
  }
  return files;
}

const config = JSON.parse(await readFile(configPath, 'utf8'));
if (!config.assets?.directory) {
  throw new Error('Generated Wrangler config does not declare a Static Assets directory.');
}

const assetsRoot = resolve(dirname(configPath), config.assets.directory);
const staticRoot = join(assetsRoot, '_next', 'static');
await access(staticRoot);

const files = await listFiles(staticRoot);
const cssFiles = files.filter((file) => extname(file) === '.css');
const jsFiles = files.filter((file) => extname(file) === '.js');

if (cssFiles.length === 0 || jsFiles.length === 0) {
  throw new Error(`Incomplete client build: found ${cssFiles.length} CSS and ${jsFiles.length} JavaScript files.`);
}

for (const file of files) {
  const info = await stat(file);
  if (info.size === 0) {
    throw new Error(`Generated asset is empty: ${relative(assetsRoot, file)}`);
  }
}

console.log(`Verified Cloudflare assets: ${cssFiles.length} CSS and ${jsFiles.length} JavaScript files in ${relative(projectRoot, assetsRoot)}.`);
