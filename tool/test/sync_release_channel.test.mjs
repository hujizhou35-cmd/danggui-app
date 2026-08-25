import assert from 'node:assert/strict';
import test from 'node:test';
import {
  collectChecksumVerifiedTags,
  DEFAULT_REPOSITORY,
  normalizePublishedRelease,
  parseChecksumFile,
  selectReleaseChannel,
  verifyReleaseChecksums,
} from '../sync_release_channel.mjs';

function release({
  id = 1,
  version = '1.1.3',
  prerelease = true,
  draft = false,
  publishedAt = '2026-08-25T14:16:57Z',
  missing = null,
} = {}) {
  const tag = `v${version}`;
  const assets = [
    'danggui-android-universal-release.apk',
    `danggui-developer-assets-${tag}.zip`,
    `danggui-ios-source-${tag}.zip`,
    'SHA256SUMS',
  ]
    .filter((name) => name !== missing)
    .map((name, index) => ({
      name,
      state: 'uploaded',
      size: 100 + index,
      digest: `sha256:${String(index + 1).repeat(64)}`,
      browser_download_url: `https://github.com/${DEFAULT_REPOSITORY}/releases/download/${tag}/${name}`,
    }));

  return {
    id,
    tag_name: tag,
    draft,
    prerelease,
    published_at: publishedAt,
    html_url: `https://github.com/${DEFAULT_REPOSITORY}/releases/tag/${tag}`,
    assets,
  };
}

function checksumFile(candidate, overrides = {}) {
  const entries = candidate.assets
    .filter((asset) => asset.name !== 'SHA256SUMS')
    .map((asset) => [asset.name, asset.digest.slice('sha256:'.length)]);
  const checksums = new Map(entries);
  for (const [name, digest] of Object.entries(overrides)) {
    if (digest === null) checksums.delete(name);
    else checksums.set(name, digest);
  }
  return `${[...checksums].map(([name, digest]) => `${digest}  ${name}`).join('\n')}\n`;
}

function textResponse(contents, { ok = true, status = 200 } = {}) {
  return { ok, status, text: async () => contents };
}

test('uses the newest complete preview when no stable release exists', () => {
  const manifest = selectReleaseChannel([
    release({ version: '1.1.2', publishedAt: '2026-08-20T00:00:00Z' }),
    release({ version: '1.1.3', publishedAt: '2026-08-25T00:00:00Z' }),
  ], { generatedAt: '2026-08-25T01:00:00Z' });

  assert.equal(manifest.stable, null);
  assert.equal(manifest.preview.tag, 'v1.1.3');
  assert.equal(manifest.recommended, 'preview');
});

test('keeps stable recommended while exposing a newer preview separately', () => {
  const manifest = selectReleaseChannel([
    release({ version: '1.1.2', prerelease: false, publishedAt: '2026-08-20T00:00:00Z' }),
    release({ version: '1.2.0', prerelease: true, publishedAt: '2026-08-25T00:00:00Z' }),
  ]);

  assert.equal(manifest.stable.tag, 'v1.1.2');
  assert.equal(manifest.preview.tag, 'v1.2.0');
  assert.equal(manifest.recommended, 'stable');
});

test('ignores drafts, malformed URLs, and incomplete releases', () => {
  const badUrl = release({ version: '2.0.0' });
  badUrl.html_url = 'https://example.com/not-danggui';
  const missingDigest = release({ version: '1.1.5' });
  missingDigest.assets[0].digest = null;
  const manifest = selectReleaseChannel([
    release({ version: '1.2.0', draft: true }),
    missingDigest,
    release({ version: '1.1.4', missing: 'SHA256SUMS' }),
    badUrl,
    release({ version: '1.1.3' }),
  ]);

  assert.equal(manifest.preview.tag, 'v1.1.3');
});

test('rejects a lone tag-shaped object without a published Release contract', () => {
  assert.equal(normalizePublishedRelease({ tag_name: 'v1.1.4' }), null);
  const manifest = selectReleaseChannel([{ tag_name: 'v1.1.4' }]);
  assert.equal(manifest.recommended, null);
});

test('falls back to the previous complete release after a release is removed', () => {
  const before = selectReleaseChannel([
    release({ version: '1.1.4', publishedAt: '2026-09-01T00:00:00Z' }),
    release({ version: '1.1.3', publishedAt: '2026-08-25T00:00:00Z' }),
  ]);
  const after = selectReleaseChannel([
    release({ version: '1.1.3', publishedAt: '2026-08-25T00:00:00Z' }),
  ]);

  assert.equal(before.preview.tag, 'v1.1.4');
  assert.equal(after.preview.tag, 'v1.1.3');
});

test('compares semantic versions numerically and hides an older preview', () => {
  const manifest = selectReleaseChannel([
    release({ version: '1.9.9', prerelease: true, publishedAt: '2026-09-02T00:00:00Z' }),
    release({ version: '1.10.0', prerelease: false, publishedAt: '2026-09-01T00:00:00Z' }),
  ]);

  assert.equal(manifest.stable.tag, 'v1.10.0');
  assert.equal(manifest.preview, null);
  assert.equal(manifest.recommended, 'stable');
});

test('downloads and verifies all three payload checksums for eligible releases', async () => {
  const candidate = release({ version: '1.1.3' });
  const normalized = normalizePublishedRelease(candidate);
  const requested = [];
  const fetcher = async (url, options) => {
    requested.push({ url, options });
    return textResponse(checksumFile(candidate));
  };

  assert.equal(await verifyReleaseChecksums(normalized, { fetcher }), true);
  const verified = await collectChecksumVerifiedTags([candidate], { fetcher });

  assert.deepEqual([...verified], ['v1.1.3']);
  assert.equal(requested.length, 2);
  assert.equal(requested[0].url, normalized.assets.checksums.downloadUrl);
  assert.equal(requested[0].options.headers.Accept, 'text/plain');
});

test('checksum mismatch invalidates only that release and falls back', async () => {
  const newest = release({ version: '1.1.4', publishedAt: '2026-09-01T00:00:00Z' });
  const previous = release({ version: '1.1.3', publishedAt: '2026-08-25T00:00:00Z' });
  const files = new Map([
    [
      newest.assets.find((asset) => asset.name === 'SHA256SUMS').browser_download_url,
      checksumFile(newest, { 'danggui-android-universal-release.apk': 'f'.repeat(64) }),
    ],
    [
      previous.assets.find((asset) => asset.name === 'SHA256SUMS').browser_download_url,
      checksumFile(previous),
    ],
  ]);
  const verified = await collectChecksumVerifiedTags([newest, previous], {
    fetcher: async (url) => textResponse(files.get(url)),
  });
  const manifest = selectReleaseChannel([newest, previous], { checksumVerifiedTags: verified });

  assert.deepEqual([...verified], ['v1.1.3']);
  assert.equal(manifest.preview.tag, 'v1.1.3');
});

test('strict checksum parsing rejects malformed, extra, and missing entries', async () => {
  const candidate = release({ version: '1.1.3' });
  const normalized = normalizePublishedRelease(candidate);
  const valid = checksumFile(candidate);
  const payloadNames = candidate.assets
    .filter((asset) => asset.name !== 'SHA256SUMS')
    .map((asset) => asset.name);
  const malformed = valid.replace(/^[0-9a-f]{64}/, 'not-a-digest');
  const extra = `${valid}${'a'.repeat(64)}  unexpected.zip\n`;
  const missing = valid.split('\n').slice(0, 2).join('\n');

  assert.ok(parseChecksumFile(valid, payloadNames) instanceof Map);
  for (const contents of [malformed, extra, missing]) {
    assert.equal(parseChecksumFile(contents, payloadNames), null);
    assert.equal(
      await verifyReleaseChecksums(normalized, {
        fetcher: async () => textResponse(contents),
      }),
      false,
    );
  }
});

test('network and non-OK checksum fetch failures abort verification', async () => {
  const candidate = release({ version: '1.1.3' });

  await assert.rejects(
    collectChecksumVerifiedTags([candidate], {
      fetcher: async () => {
        throw new Error('offline');
      },
    }),
    /Failed to download SHA256SUMS for v1\.1\.3/,
  );
  await assert.rejects(
    collectChecksumVerifiedTags([candidate], {
      fetcher: async () => textResponse('', { ok: false, status: 503 }),
    }),
    /HTTP 503/,
  );
});
