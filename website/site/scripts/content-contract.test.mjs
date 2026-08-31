import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { basename, dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const locales = ['zh-CN', 'en', 'ja', 'ru'];
const publicNames = {
  'xiaodanggui-hero-quiet-growth.webp': 'hero.webp',
  'feature-local-only.webp': 'feature-local-only.webp',
  'feature-growing-past.webp': 'feature-growing-past.webp',
  'feature-notes-reminders.webp': 'feature-notes-reminders.webp',
  'story-01-only-here-it-sprouts.webp': 'story-01.webp',
  'story-03-past-has-rings.webp': 'story-03.webp',
  'story-04-gentle-reminder.webp': 'story-04.webp',
  'story-05-blank-page-kept.webp': 'story-05.webp',
  'story-06-unsent-paper-plane.webp': 'story-06.webp',
  'story-08-rain-in-wooden-box.webp': 'story-08.webp',
  'pose-holding-note.png': 'pose-holding-note.png',
  'pose-guarding-seed.png': 'pose-guarding-seed.png',
};

async function loadNarratives() {
  return Promise.all(locales.map(async (locale) => {
    const value = JSON.parse(await readFile(join(root, 'content', `stories.${locale}.json`), 'utf8'));
    return [locale, value];
  }));
}

test('four locale narratives keep one shared contract', async () => {
  const entries = await loadNarratives();
  const reference = entries[0][1];
  const expectedStoryIds = reference.stories.map(({ id }) => id);
  const expectedFeatureIds = reference.features.map(({ id }) => id);
  const expectedStoryImages = reference.stories.map(({ image }) => image);
  const expectedFeatureImages = reference.features.map(({ image }) => image);

  for (const [locale, narrative] of entries) {
    assert.equal(narrative.locale, locale);
    assert.equal(narrative.features.length, 3);
    assert.equal(narrative.stories.length, 8);
    assert.deepEqual(narrative.features.map(({ id }) => id), expectedFeatureIds);
    assert.deepEqual(narrative.stories.map(({ id }) => id), expectedStoryIds);
    assert.deepEqual(narrative.features.map(({ image }) => image), expectedFeatureImages);
    assert.deepEqual(narrative.stories.map(({ image }) => image), expectedStoryImages);
  }
});

test('narrative image references resolve to shipped website assets', async () => {
  const [, reference] = (await loadNarratives())[0];
  const references = [
    reference.hero.image,
    ...reference.features.map(({ image }) => image),
    ...reference.stories.map(({ image }) => image),
  ];
  for (const source of new Set(references)) {
    const publicName = publicNames[basename(source)];
    assert.ok(publicName, `No public mapping for ${source}`);
    assert.ok((await stat(join(root, 'public', 'assets', publicName))).size > 0);
  }
});

test('localized terminology and character identity remain intact', async () => {
  const entries = Object.fromEntries(await loadNarratives());
  const english = JSON.stringify(entries.en);
  const japanese = JSON.stringify(entries.ja);
  const russian = JSON.stringify(entries.ru);

  for (const term of ['Tasks', 'Past', 'Notes', 'Reminders']) assert.match(english, new RegExp(term));
  for (const term of ['事項', '過往', 'ノート', '通知']) assert.match(japanese, new RegExp(term));
  for (const term of ['Дела', 'Прошлое', 'Заметки', 'Напоминания']) assert.match(russian, new RegExp(term));
  assert.equal(english.match(/Little Danggui/g)?.length, 1);
  assert.doesNotMatch(japanese, /当帰|小当帰|リマインダー/);
});

test('v1.1.5 ships six real UI frames for Chinese and English', async () => {
  const names = [
    '01-startup.png',
    '02-tasks-reminders.png',
    '03-task-detail.png',
    '04-past.png',
    '05-notes.png',
    '06-export-settings.png',
  ];
  for (const locale of ['zh', 'en']) {
    for (const name of names) {
      const file = join(root, 'public', 'assets', 'ui', 'v1.1.5', locale, name);
      const bytes = await readFile(file);
      assert.ok(bytes.length > 100_000, `${file} is unexpectedly small`);
      assert.deepEqual([...bytes.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    }
  }
});

test('public copy has no stale screenshot or pre-release status claim', async () => {
  const copy = await readFile(join(root, 'content', 'site-copy.ts'), 'utf8');
  assert.doesNotMatch(copy, /v1\.1\.2/);
  assert.doesNotMatch(copy, /仍按预发布|still distributed as a pre-release|プレリリースとして配布|как предварительная версия/);
  assert.equal(copy.match(/v1\.1\.5/g)?.length, 4, 'Only the four screenshot-capture labels may pin v1.1.5');
});
