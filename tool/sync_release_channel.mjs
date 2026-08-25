#!/usr/bin/env node

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const DEFAULT_REPOSITORY = 'hujizhou35-cmd/danggui-app';
export const SCHEMA_VERSION = 1;

const TAG_PATTERN = /^v((0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))$/;
const REQUIRED_ANDROID_ASSET = 'danggui-android-universal-release.apk';
const REQUIRED_CHECKSUM_ASSET = 'SHA256SUMS';
const MAX_CHECKSUM_FILE_SIZE = 16 * 1024;

function requiredPayloadAssetNames(tag) {
  return [
    REQUIRED_ANDROID_ASSET,
    `danggui-developer-assets-${tag}.zip`,
    `danggui-ios-source-${tag}.zip`,
  ];
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function compareVersions(left, right) {
  for (let index = 0; index < 3; index += 1) {
    const difference = right.versionParts[index] - left.versionParts[index];
    if (difference !== 0) return difference;
  }
  return Date.parse(right.publishedAt) - Date.parse(left.publishedAt);
}

function normalizeAsset(asset, repository, tag, expectedName) {
  if (!isRecord(asset) || asset.state !== 'uploaded' || asset.name !== expectedName) {
    return null;
  }

  const expectedPrefix = `https://github.com/${repository}/releases/download/${tag}/`;
  if (
    typeof asset.browser_download_url !== 'string' ||
    !asset.browser_download_url.startsWith(expectedPrefix) ||
    !Number.isSafeInteger(asset.size) ||
    asset.size <= 0 ||
    typeof asset.digest !== 'string' ||
    !/^sha256:[0-9a-f]{64}$/i.test(asset.digest)
  ) {
    return null;
  }

  return {
    name: asset.name,
    downloadUrl: asset.browser_download_url,
    size: asset.size,
    digest: asset.digest.toLowerCase(),
  };
}

export function normalizePublishedRelease(
  release,
  repository = DEFAULT_REPOSITORY,
  sourceCommit = null,
) {
  if (
    !isRecord(release) ||
    release.draft !== false ||
    typeof release.tag_name !== 'string' ||
    typeof release.published_at !== 'string' ||
    Number.isNaN(Date.parse(release.published_at)) ||
    !Array.isArray(release.assets)
  ) {
    return null;
  }

  const tagMatch = TAG_PATTERN.exec(release.tag_name);
  if (!tagMatch) return null;

  const tag = release.tag_name;
  const version = tagMatch[1];
  const versionParts = [Number(tagMatch[2]), Number(tagMatch[3]), Number(tagMatch[4])];
  const expectedReleaseUrl = `https://github.com/${repository}/releases/tag/${tag}`;
  if (release.html_url !== expectedReleaseUrl) return null;

  const expectedAssetNames = [
    ...requiredPayloadAssetNames(tag),
    REQUIRED_CHECKSUM_ASSET,
  ];
  const actualAssetNames = release.assets.map((asset) => asset?.name);
  if (
    actualAssetNames.length !== expectedAssetNames.length ||
    new Set(actualAssetNames).size !== expectedAssetNames.length ||
    !expectedAssetNames.every((name) => actualAssetNames.includes(name))
  ) {
    return null;
  }

  const findAsset = (name) => release.assets.find((asset) => asset?.name === name);
  const android = normalizeAsset(
    findAsset(REQUIRED_ANDROID_ASSET),
    repository,
    tag,
    REQUIRED_ANDROID_ASSET,
  );
  const iosName = `danggui-ios-source-${tag}.zip`;
  const iosSource = normalizeAsset(findAsset(iosName), repository, tag, iosName);
  const developerName = `danggui-developer-assets-${tag}.zip`;
  const developer = normalizeAsset(
    findAsset(developerName),
    repository,
    tag,
    developerName,
  );
  const checksums = normalizeAsset(
    findAsset(REQUIRED_CHECKSUM_ASSET),
    repository,
    tag,
    REQUIRED_CHECKSUM_ASSET,
  );

  if (!android || !iosSource || !developer || !checksums) return null;

  return {
    releaseId: Number.isSafeInteger(release.id) ? release.id : null,
    version,
    versionParts,
    tag,
    channel: release.prerelease === true ? 'preview' : 'stable',
    prerelease: release.prerelease === true,
    publishedAt: release.published_at,
    sourceCommit,
    releaseUrl: expectedReleaseUrl,
    assets: { android, iosSource, developer, checksums },
  };
}

export function parseChecksumFile(contents, expectedNames) {
  if (
    typeof contents !== 'string' ||
    contents.length === 0 ||
    contents.length > MAX_CHECKSUM_FILE_SIZE ||
    !Array.isArray(expectedNames) ||
    expectedNames.length !== 3 ||
    new Set(expectedNames).size !== expectedNames.length
  ) {
    return null;
  }

  const lines = contents.split(/\r?\n/);
  if (lines.at(-1) === '') lines.pop();
  if (lines.length !== expectedNames.length || lines.some((line) => line.length === 0)) {
    return null;
  }

  const expected = new Set(expectedNames);
  const checksums = new Map();
  for (const line of lines) {
    const match = /^([0-9a-f]{64})[ \t]+\*?([^/\\\r\n]+)$/i.exec(line);
    if (!match || !expected.has(match[2]) || checksums.has(match[2])) return null;
    checksums.set(match[2], match[1].toLowerCase());
  }

  return checksums.size === expected.size ? checksums : null;
}

export async function verifyReleaseChecksums(
  release,
  { fetcher = globalThis.fetch, timeoutMs = 15_000 } = {},
) {
  if (
    !isRecord(release) ||
    typeof release.tag !== 'string' ||
    !isRecord(release.assets) ||
    !isRecord(release.assets.checksums) ||
    typeof release.assets.checksums.downloadUrl !== 'string' ||
    typeof fetcher !== 'function'
  ) {
    throw new TypeError('A normalized published release and fetch implementation are required.');
  }

  let response;
  try {
    response = await fetcher(release.assets.checksums.downloadUrl, {
      headers: {
        Accept: 'text/plain',
        'User-Agent': 'danggui-release-channel',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw new Error(`Failed to download ${REQUIRED_CHECKSUM_ASSET} for ${release.tag}.`, {
      cause: error,
    });
  }

  if (!response?.ok) {
    throw new Error(
      `Failed to download ${REQUIRED_CHECKSUM_ASSET} for ${release.tag}: HTTP ${response?.status ?? 'unknown'}.`,
    );
  }

  let contents;
  try {
    contents = await response.text();
  } catch (error) {
    throw new Error(`Failed to read ${REQUIRED_CHECKSUM_ASSET} for ${release.tag}.`, {
      cause: error,
    });
  }

  const payloadAssets = [
    release.assets.android,
    release.assets.developer,
    release.assets.iosSource,
  ];
  if (
    payloadAssets.some(
      (asset) =>
        !isRecord(asset) ||
        typeof asset.name !== 'string' ||
        typeof asset.digest !== 'string' ||
        !/^sha256:[0-9a-f]{64}$/i.test(asset.digest),
    )
  ) {
    throw new TypeError(`Release ${release.tag} is missing normalized payload assets.`);
  }

  const expectedNames = requiredPayloadAssetNames(release.tag);
  const checksums = parseChecksumFile(contents, expectedNames);
  if (!checksums) return false;

  return payloadAssets.every(
    (asset) => checksums.get(asset.name) === asset.digest.slice('sha256:'.length).toLowerCase(),
  );
}

export async function collectChecksumVerifiedTags(
  releases,
  { repository = DEFAULT_REPOSITORY, fetcher = globalThis.fetch, timeoutMs = 15_000 } = {},
) {
  if (!Array.isArray(releases)) throw new TypeError('GitHub Releases response must be an array.');

  const eligible = releases
    .map((release) => normalizePublishedRelease(release, repository))
    .filter(Boolean);
  const results = await Promise.all(
    eligible.map(async (release) => ({
      tag: release.tag,
      verified: await verifyReleaseChecksums(release, { fetcher, timeoutMs }),
    })),
  );

  return new Set(results.filter((result) => result.verified).map((result) => result.tag));
}

export function selectReleaseChannel(
  releases,
  {
    repository = DEFAULT_REPOSITORY,
    generatedAt = new Date().toISOString(),
    sourceCommits = null,
    checksumVerifiedTags = null,
  } = {},
) {
  if (!Array.isArray(releases)) throw new TypeError('GitHub Releases response must be an array.');
  if (checksumVerifiedTags && typeof checksumVerifiedTags.has !== 'function') {
    throw new TypeError('checksumVerifiedTags must be a Set-like value.');
  }

  const published = releases
    .map((release) => {
      const sourceCommit = sourceCommits?.get(release?.tag_name) ?? null;
      if (sourceCommits && !sourceCommit) return null;
      if (checksumVerifiedTags && !checksumVerifiedTags.has(release?.tag_name)) return null;
      return normalizePublishedRelease(release, repository, sourceCommit);
    })
    .filter(Boolean)
    .sort(compareVersions);

  const stable = published.find((release) => !release.prerelease) ?? null;
  const newestPreview = published.find((release) => release.prerelease) ?? null;
  const preview =
    stable && newestPreview && compareVersions(newestPreview, stable) >= 0
      ? null
      : newestPreview;
  const recommended = stable ? 'stable' : preview ? 'preview' : null;

  const stripInternalFields = (release) => {
    if (!release) return null;
    const { versionParts: _versionParts, ...publicRelease } = release;
    return publicRelease;
  };

  return {
    schemaVersion: SCHEMA_VERSION,
    repository,
    generatedAt,
    stable: stripInternalFields(stable),
    preview: stripInternalFields(preview),
    recommended,
  };
}

function collectReachableTagCommits(releases) {
  const commits = new Map();
  for (const release of releases) {
    if (!TAG_PATTERN.test(release?.tag_name ?? '')) continue;
    const revision = `${release.tag_name}^{commit}`;
    const resolved = spawnSync('git', ['rev-parse', '--verify', revision], {
      encoding: 'utf8',
    });
    if (resolved.status !== 0) continue;
    const commit = resolved.stdout.trim();
    const reachable = spawnSync(
      'git',
      ['merge-base', '--is-ancestor', commit, 'refs/remotes/origin/main'],
      { encoding: 'utf8' },
    );
    if (reachable.status === 0) commits.set(release.tag_name, commit);
  }
  return commits;
}

async function fetchPublishedReleases(repository, token) {
  const releases = [];

  for (let page = 1; page <= 5; page += 1) {
    const response = await fetch(
      `https://api.github.com/repos/${repository}/releases?per_page=100&page=${page}`,
      {
        headers: {
          Accept: 'application/vnd.github+json',
          'User-Agent': 'danggui-release-channel',
          'X-GitHub-Api-Version': '2022-11-28',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        signal: AbortSignal.timeout(15_000),
      },
    );

    if (!response.ok) {
      throw new Error(`GitHub Releases request failed with ${response.status}.`);
    }

    const pageItems = await response.json();
    if (!Array.isArray(pageItems)) throw new Error('GitHub Releases returned invalid JSON.');
    releases.push(...pageItems);
    if (pageItems.length < 100) break;
  }

  return releases;
}

function parseArguments(argv) {
  const args = { output: 'release-channel/current.json' };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--repository') args.repository = argv[++index];
    else if (argument === '--output') args.output = argv[++index];
    else if (argument === '--input') args.input = argv[++index];
    else if (argument === '--generated-at') args.generatedAt = argv[++index];
    else if (argument === '--verify-git') args.verifyGit = true;
    else throw new Error(`Unknown argument: ${argument}`);
  }
  return args;
}

async function main() {
  const args = parseArguments(process.argv.slice(2));
  const repository = args.repository || process.env.GITHUB_REPOSITORY || DEFAULT_REPOSITORY;
  if (repository !== DEFAULT_REPOSITORY) {
    throw new Error(`Refusing to publish a release channel for unexpected repository: ${repository}`);
  }

  const releases = args.input
    ? JSON.parse(await readFile(path.resolve(args.input), 'utf8'))
    : await fetchPublishedReleases(repository, process.env.GH_TOKEN || process.env.GITHUB_TOKEN);
  const checksumVerifiedTags = await collectChecksumVerifiedTags(releases, { repository });
  const manifest = selectReleaseChannel(releases, {
    repository,
    generatedAt: args.generatedAt || new Date().toISOString(),
    sourceCommits: args.verifyGit ? collectReachableTagCommits(releases) : null,
    checksumVerifiedTags,
  });

  const output = path.resolve(args.output);
  await mkdir(path.dirname(output), { recursive: true });
  await writeFile(output, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  const selected = manifest.recommended ? manifest[manifest.recommended] : null;
  process.stdout.write(`${selected?.tag ?? 'none'}\n`);
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (import.meta.url === invokedPath) {
  main().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  });
}
