import type { Metadata } from 'next';
import { locales, type Locale } from '@/content/types';
import { getLocaleData, localePath } from '@/lib/content';
import { absoluteSiteUrl, SOCIAL_IMAGE_PATH } from '@/lib/site-config';

const openGraphLocales: Record<Locale, string> = {
  'zh-CN': 'zh_CN',
  en: 'en_US',
  ja: 'ja_JP',
  ru: 'ru_RU',
};

export function createPageMetadata({
  locale,
  title,
  description,
  suffix = '',
  includeSocialImage = true,
}: {
  locale: Locale;
  title: string;
  description: string;
  suffix?: string;
  includeSocialImage?: boolean;
}): Metadata {
  const { ui } = getLocaleData(locale);
  const languageAlternates = Object.fromEntries(
    locales.map((candidate) => [candidate, absoluteSiteUrl(localePath(candidate, suffix))]),
  );
  const canonicalUrl = absoluteSiteUrl(localePath(locale, suffix));
  const socialImageUrl = absoluteSiteUrl(SOCIAL_IMAGE_PATH);

  return {
    title,
    description,
    alternates: {
      canonical: canonicalUrl,
      languages: {
        ...languageAlternates,
        'x-default': absoluteSiteUrl(localePath('zh-CN', suffix)),
      },
    },
    openGraph: {
      type: 'website',
      url: canonicalUrl,
      title,
      description,
      siteName: '当归',
      locale: openGraphLocales[locale],
      alternateLocale: locales
        .filter((candidate) => candidate !== locale)
        .map((candidate) => openGraphLocales[candidate]),
      images: includeSocialImage
        ? [{ url: socialImageUrl, width: 1280, height: 640, alt: `当归 · ${ui.footer.tagline}` }]
        : [],
    },
    twitter: {
      card: includeSocialImage ? 'summary_large_image' : 'summary',
      title,
      description,
      images: includeSocialImage ? [socialImageUrl] : [],
    },
  };
}
