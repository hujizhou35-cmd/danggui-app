import type { MetadataRoute } from 'next';
import { locales } from '@/content/types';
import { getLocaleData, localePath } from '@/lib/content';
import { absoluteSiteUrl } from '@/lib/site-config';

export default function sitemap(): MetadataRoute.Sitemap {
  const entries: MetadataRoute.Sitemap = [];

  for (const locale of locales) {
    const baseRoutes = [
      { suffix: '', changeFrequency: 'monthly' as const, priority: 1 },
      { suffix: '/download', changeFrequency: 'weekly' as const, priority: 0.9 },
      { suffix: '/support', changeFrequency: 'monthly' as const, priority: 0.8 },
      { suffix: '/privacy', changeFrequency: 'yearly' as const, priority: 0.6 },
      { suffix: '/stories', changeFrequency: 'monthly' as const, priority: 0.7 },
    ];

    for (const route of baseRoutes) {
      entries.push({
        url: absoluteSiteUrl(localePath(locale, route.suffix)),
        changeFrequency: route.changeFrequency,
        priority: route.priority,
      });
    }

    for (const story of getLocaleData(locale).narrative.stories) {
      entries.push({
        url: absoluteSiteUrl(localePath(locale, `/stories/${story.id}`)),
        changeFrequency: 'yearly',
        priority: 0.5,
      });
    }
  }

  return entries;
}
