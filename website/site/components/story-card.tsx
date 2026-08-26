import Image from 'next/image';
import type { Locale, Story } from '@/content/types';
import { getLocaleData, localePath } from '@/lib/content';

export function StoryCard({
  story,
  locale,
  priority = false,
}: {
  story: Story;
  locale: Locale;
  priority?: boolean;
}) {
  const { ui } = getLocaleData(locale);
  return (
    <article className="story-card">
      <a className="story-image-link" href={localePath(locale, `/stories/${story.id}`)}>
        <Image
          src={story.image}
          alt={story.alt}
          fill
          priority={priority}
          sizes="(max-width: 760px) 92vw, 31vw"
        />
      </a>
      <div className="story-card-copy">
        <p className="story-theme">{story.productTheme}</p>
        <h2>
          <a href={localePath(locale, `/stories/${story.id}`)}>{story.title}</a>
        </h2>
        <p>{story.excerpt}</p>
        <a className="text-link" href={localePath(locale, `/stories/${story.id}`)}>
          {ui.common.readStory}
          <span aria-hidden="true"> →</span>
        </a>
      </div>
    </article>
  );
}
