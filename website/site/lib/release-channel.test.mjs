import assert from 'node:assert/strict';
import test from 'node:test';
import {
  fetchReleaseChannel,
  parseReleaseChannelManifest,
} from './release-channel.ts';

function manifest() {
  const tag = 'v1.1.3';
  const base = `https://github.com/hujizhou35-cmd/danggui-app/releases/download/${tag}`;
  const asset = (name, digit) => ({
    name,
    downloadUrl: `${base}/${name}`,
    size: 100,
    digest: `sha256:${digit.repeat(64)}`,
  });
  return {
    schemaVersion: 1,
    repository: 'hujizhou35-cmd/danggui-app',
    generatedAt: '2026-08-25T15:15:04.031Z',
    stable: null,
    preview: {
      releaseId: 376461451,
      version: '1.1.3',
      tag,
      channel: 'preview',
      prerelease: true,
      publishedAt: '2026-08-25T14:16:57Z',
      sourceCommit: '6ff8da384eee69496bc9f506e2440321c28eaf18',
      releaseUrl: `https://github.com/hujizhou35-cmd/danggui-app/releases/tag/${tag}`,
      assets: {
        android: asset('danggui-android-universal-release.apk', '1'),
        iosSource: asset(`danggui-ios-source-${tag}.zip`, '2'),
        developer: asset(`danggui-developer-assets-${tag}.zip`, '3'),
        checksums: asset('SHA256SUMS', '4'),
      },
    },
    recommended: 'preview',
  };
}

test('accepts a complete, repository-bound public manifest', () => {
  const parsed = parseReleaseChannelManifest(manifest());
  assert.equal(parsed?.preview?.tag, 'v1.1.3');
  assert.equal(parsed?.recommended, 'preview');
});

test('rejects a foreign asset URL, missing digest, and dangling recommendation', () => {
  const foreign = manifest();
  foreign.preview.assets.android.downloadUrl = 'https://example.com/danggui.apk';
  assert.equal(parseReleaseChannelManifest(foreign), null);

  const missingDigest = manifest();
  missingDigest.preview.assets.checksums.digest = null;
  assert.equal(parseReleaseChannelManifest(missingDigest), null);

  const dangling = manifest();
  dangling.preview = null;
  assert.equal(parseReleaseChannelManifest(dangling), null);
});

test('returns no release when the upstream request times out', async () => {
  const never = (_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
  });
  assert.equal(await fetchReleaseChannel(never, 5), null);
});

test('returns no release for malformed upstream JSON', async () => {
  const malformed = async () => new Response(JSON.stringify({ schemaVersion: 99 }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
  assert.equal(await fetchReleaseChannel(malformed, 50), null);
});
