import type { Metadata } from 'next';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { locales } from '@/content/types';
import { getLocaleData, getStory, isLocale, localePath } from '@/lib/content';
import { createPageMetadata } from '@/lib/metadata';

type PageProps = { params: Promise<{ locale: string; storyId: string }> };

export function generateStaticParams() {
  return locales.flatMap((locale) =>
    getLocaleData(locale).narrative.stories.map((story) => ({ locale, storyId: story.id })),
  );
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale, storyId } = await params;
  if (!isLocale(locale)) return {};
  const story = getStory(locale, storyId);
  if (!story) return {};
  return createPageMetadata({
    locale,
    title: story.title,
    description: story.excerpt,
    suffix: `/stories/${storyId}`,
  });
}

export default async function StoryDetailPage({ params }: PageProps) {
  const { locale, storyId } = await params;
  if (!isLocale(locale)) notFound();
  const { narrative, ui } = getLocaleData(locale);
  const storyIndex = narrative.stories.findIndex((story) => story.id === storyId);
  if (storyIndex < 0) notFound();
  const story = narrative.stories[storyIndex];
  const previous = narrative.stories[(storyIndex - 1 + narrative.stories.length) % narrative.stories.length];
  const next = narrative.stories[(storyIndex + 1) % narrative.stories.length];

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} routeSuffix={`/stories/${story.id}`} />
      <main className="story-detail-main" id="main-content">
        <a className="back-link" href={localePath(locale, '/stories')}>← {ui.common.backToStories}</a>
        <article className="story-detail">
          <div className="story-detail-copy">
            <p className="eyebrow">{ui.stories.detailEyebrow} · {story.productTheme}</p>
            <h1>{story.title}</h1>
            <p className="story-lead">{story.excerpt}</p>
            <p className="story-body">{story.body}</p>
          </div>
          <figure className="story-detail-image">
            <Image src={story.image} alt={story.alt} fill priority sizes="(max-width: 760px) 92vw, 46vw" />
          </figure>
        </article>
        <nav className="story-pagination" aria-label={ui.stories.relatedTitle}>
          <a href={localePath(locale, `/stories/${previous.id}`)}>
            <span>{ui.common.previousStory}</span>
            <strong>{previous.title}</strong>
          </a>
          <a href={localePath(locale, `/stories/${next.id}`)}>
            <span>{ui.common.nextStory}</span>
            <strong>{next.title}</strong>
          </a>
        </nav>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
