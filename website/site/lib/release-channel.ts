export const repositoryUrl = 'https://github.com/hujizhou35-cmd/danggui-app';
export const releasesUrl = `${repositoryUrl}/releases`;
export const releaseManifestUrl =
  'https://raw.githubusercontent.com/hujizhou35-cmd/danggui-app/release-channel/current.json';

export type ReleaseChannel = 'stable' | 'preview';
export type ReleaseAssetKey = 'android' | 'iosSource' | 'developer' | 'checksums';

export interface ReleaseAsset {
  name: string;
  downloadUrl: string;
  size: number;
  digest: string;
}

export interface PublishedRelease {
  releaseId: number | null;
  version: string;
  tag: string;
  channel: ReleaseChannel;
  prerelease: boolean;
  publishedAt: string;
  sourceCommit: string;
  releaseUrl: string;
  assets: Record<ReleaseAssetKey, ReleaseAsset>;
}

export interface ReleaseChannelManifest {
  schemaVersion: 1;
  repository: 'hujizhou35-cmd/danggui-app';
  generatedAt: string;
  stable: PublishedRelease | null;
  preview: PublishedRelease | null;
  recommended: ReleaseChannel | null;
}

const TAG_PATTERN = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const DIGEST_PATTERN = /^sha256:[0-9a-f]{64}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function parseAsset(
  value: unknown,
  tag: string,
  expectedName: string,
): ReleaseAsset | null {
  if (!isRecord(value)) return null;
  const expectedUrl = `${repositoryUrl}/releases/download/${tag}/${expectedName}`;
  if (
    value.name !== expectedName ||
    value.downloadUrl !== expectedUrl ||
    typeof value.size !== 'number' ||
    !Number.isSafeInteger(value.size) ||
    value.size <= 0 ||
    typeof value.digest !== 'string' ||
    !DIGEST_PATTERN.test(value.digest)
  ) {
    return null;
  }
  return {
    name: value.name,
    downloadUrl: value.downloadUrl,
    size: value.size,
    digest: value.digest,
  };
}

function parseRelease(value: unknown, expectedChannel: ReleaseChannel): PublishedRelease | null {
  if (!isRecord(value) || typeof value.tag !== 'string' || !TAG_PATTERN.test(value.tag)) {
    return null;
  }
  const version = value.tag.slice(1);
  if (
    value.version !== version ||
    value.channel !== expectedChannel ||
    value.prerelease !== (expectedChannel === 'preview') ||
    typeof value.publishedAt !== 'string' ||
    Number.isNaN(Date.parse(value.publishedAt)) ||
    typeof value.sourceCommit !== 'string' ||
    !COMMIT_PATTERN.test(value.sourceCommit) ||
    value.releaseUrl !== `${repositoryUrl}/releases/tag/${value.tag}` ||
    !(value.releaseId === null || (typeof value.releaseId === 'number' && Number.isSafeInteger(value.releaseId))) ||
    !isRecord(value.assets)
  ) {
    return null;
  }

  const names = {
    android: 'danggui-android-universal-release.apk',
    iosSource: `danggui-ios-source-${value.tag}.zip`,
    developer: `danggui-developer-assets-${value.tag}.zip`,
    checksums: 'SHA256SUMS',
  } as const;
  const android = parseAsset(value.assets.android, value.tag, names.android);
  const iosSource = parseAsset(value.assets.iosSource, value.tag, names.iosSource);
  const developer = parseAsset(value.assets.developer, value.tag, names.developer);
  const checksums = parseAsset(value.assets.checksums, value.tag, names.checksums);
  if (!android || !iosSource || !developer || !checksums) return null;

  return {
    releaseId: value.releaseId as number | null,
    version,
    tag: value.tag,
    channel: expectedChannel,
    prerelease: expectedChannel === 'preview',
    publishedAt: value.publishedAt,
    sourceCommit: value.sourceCommit,
    releaseUrl: value.releaseUrl,
    assets: { android, iosSource, developer, checksums },
  };
}

export function parseReleaseChannelManifest(value: unknown): ReleaseChannelManifest | null {
  if (
    !isRecord(value) ||
    value.schemaVersion !== 1 ||
    value.repository !== 'hujizhou35-cmd/danggui-app' ||
    typeof value.generatedAt !== 'string' ||
    Number.isNaN(Date.parse(value.generatedAt)) ||
    !(value.recommended === null || value.recommended === 'stable' || value.recommended === 'preview')
  ) {
    return null;
  }

  const stable = value.stable === null ? null : parseRelease(value.stable, 'stable');
  const preview = value.preview === null ? null : parseRelease(value.preview, 'preview');
  if ((value.stable !== null && !stable) || (value.preview !== null && !preview)) return null;
  if (value.recommended && !{ stable, preview }[value.recommended]) return null;
  if (stable && value.recommended !== 'stable') return null;
  if (!stable && preview && value.recommended !== 'preview') return null;

  return {
    schemaVersion: 1,
    repository: 'hujizhou35-cmd/danggui-app',
    generatedAt: value.generatedAt,
    stable,
    preview,
    recommended: value.recommended,
  };
}

export function compareReleaseVersions(left: string, right: string) {
  const leftParts = left.split('.').map(Number);
  const rightParts = right.split('.').map(Number);
  for (let index = 0; index < 3; index += 1) {
    if (leftParts[index] !== rightParts[index]) return leftParts[index] - rightParts[index];
  }
  return 0;
}

export function getRecommendedRelease(manifest: ReleaseChannelManifest): PublishedRelease | null {
  return manifest.recommended ? manifest[manifest.recommended] : null;
}

export async function fetchReleaseChannel(
  fetcher: typeof fetch = fetch,
  timeoutMs = 3_500,
): Promise<ReleaseChannelManifest | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetcher(releaseManifestUrl, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    if (!response.ok) return null;
    return parseReleaseChannelManifest(await response.json());
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export function releaseDocumentUrl(tag: string, documentPath: string) {
  return `${repositoryUrl}/blob/${tag}/${documentPath}`;
}
