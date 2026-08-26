import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { StoryCard } from '@/components/story-card';
import { locales } from '@/content/types';
import { getLocaleData, isLocale } from '@/lib/content';
import { createPageMetadata } from '@/lib/metadata';

type PageProps = { params: Promise<{ locale: string }> };

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const { ui } = getLocaleData(locale);
  return createPageMetadata({ locale, title: ui.stories.title, description: ui.stories.intro, suffix: '/stories' });
}

export default async function StoriesPage({ params }: PageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { narrative, ui } = getLocaleData(locale);

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} routeSuffix="/stories" />
      <main className="inner-main" id="main-content">
        <header className="page-hero">
          <p className="eyebrow">{ui.stories.eyebrow}</p>
          <h1>{ui.stories.title}</h1>
          <p>{ui.stories.intro}</p>
        </header>
        <section className="story-grid story-grid-all" aria-label={ui.stories.title}>
          {narrative.stories.map((story, index) => (
            <StoryCard story={story} locale={locale} priority={index < 2} key={story.id} />
          ))}
        </section>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
