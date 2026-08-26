import en from '@/content/stories.en.json';
import ja from '@/content/stories.ja.json';
import ru from '@/content/stories.ru.json';
import zhCN from '@/content/stories.zh-CN.json';
import { locales, type Locale, type NarrativeContent, type Story } from '@/content/types';
import { uiCopy } from '@/content/site-copy';
import { repositoryUrl } from '@/lib/release-channel';

const narratives: Record<Locale, NarrativeContent> = {
  'zh-CN': zhCN as NarrativeContent,
  en: en as NarrativeContent,
  ja: ja as NarrativeContent,
  ru: ru as NarrativeContent,
};

const imageMap: Record<string, string> = {
  'xiaodanggui-hero-quiet-growth.webp': '/assets/hero.webp',
  'feature-local-only.webp': '/assets/feature-local-only.webp',
  'feature-growing-past.webp': '/assets/feature-growing-past.webp',
  'feature-notes-reminders.webp': '/assets/feature-notes-reminders.webp',
  'story-01-only-here-it-sprouts.webp': '/assets/story-01.webp',
  'story-03-past-has-rings.webp': '/assets/story-03.webp',
  'story-04-gentle-reminder.webp': '/assets/story-04.webp',
  'story-06-unsent-paper-plane.webp': '/assets/story-06.webp',
  'pose-holding-note.png': '/assets/pose-holding-note.png',
  'pose-guarding-seed.png': '/assets/pose-guarding-seed.png',
};

export { repositoryUrl };
export const releaseUrl = '/go/release';
export const iosGuideUrl = '/go/ios-guide';
export const privacyAuditUrl = '/go/privacy-audit';
export const licenseUrl = '/go/license';
export const trademarkUrl = '/go/trademark';

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export function getLocaleData(locale: Locale) {
  const narrative = narratives[locale];
  return {
    narrative: {
      ...narrative,
      hero: { ...narrative.hero, image: resolveImage(narrative.hero.image) },
      features: narrative.features.map((feature) => ({
        ...feature,
        image: resolveImage(feature.image),
      })),
      stories: narrative.stories.map((story) => ({
        ...story,
        image: resolveImage(story.image),
      })),
    },
    ui: uiCopy[locale],
  };
}

export function getStory(locale: Locale, storyId: string): Story | undefined {
  return getLocaleData(locale).narrative.stories.find((story) => story.id === storyId);
}

export function localePath(locale: Locale, suffix = '') {
  return `/${locale}${suffix}`;
}

function resolveImage(source: string) {
  const fileName = source.split('/').at(-1) ?? '';
  return imageMap[fileName] ?? '/assets/hero.webp';
}
