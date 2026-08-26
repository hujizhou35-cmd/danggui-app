'use client';

import Image from 'next/image';
import { useRef, useState } from 'react';
import type { KeyboardEvent } from 'react';
import type { Locale, Story } from '@/content/types';
import { localePath } from '@/lib/content';

export function StoryDeck({
  stories,
  locale,
  readLabel,
  ariaLabel,
}: {
  stories: Story[];
  locale: Locale;
  readLabel: string;
  ariaLabel: string;
}) {
  const [activeIndex, setActiveIndex] = useState(0);
  const tabs = useRef<Array<HTMLButtonElement | null>>([]);

  function activateOnHover(index: number) {
    if (window.matchMedia('(hover: hover)').matches) setActiveIndex(index);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLButtonElement>, index: number) {
    const keys: Record<string, number> = {
      ArrowRight: (index + 1) % stories.length,
      ArrowDown: (index + 1) % stories.length,
      ArrowLeft: (index - 1 + stories.length) % stories.length,
      ArrowUp: (index - 1 + stories.length) % stories.length,
      Home: 0,
      End: stories.length - 1,
    };
    const next = keys[event.key];
    if (next === undefined) return;
    event.preventDefault();
    setActiveIndex(next);
    tabs.current[next]?.focus();
  }

  return (
    <div className="story-deck" role="tablist" aria-label={ariaLabel}>
      {stories.map((story, index) => {
        const active = activeIndex === index;
        const tabId = `story-tab-${story.id}`;
        const panelId = `story-panel-${story.id}`;
        return (
          <article className="story-deck-card" data-active={active} role="presentation" key={story.id}>
            <button
              ref={(node) => { tabs.current[index] = node; }}
              className="story-deck-tab"
              type="button"
              role="tab"
              id={tabId}
              aria-selected={active}
              aria-controls={panelId}
              tabIndex={active ? 0 : -1}
              onClick={() => setActiveIndex(index)}
              onFocus={() => setActiveIndex(index)}
              onPointerEnter={() => activateOnHover(index)}
              onKeyDown={(event) => handleKeyDown(event, index)}
            >
              <Image src={story.image} alt="" fill sizes="(max-width: 760px) 92vw, 52vw" />
              <span className="story-deck-number" aria-hidden="true">0{index + 1}</span>
              <span className="story-deck-compact-title">{story.title}</span>
            </button>
            <div
              className="story-deck-panel"
              id={panelId}
              role="tabpanel"
              aria-labelledby={tabId}
              hidden={!active}
            >
              <p>{story.productTheme}</p>
              <h3>{story.title}</h3>
              <div className="story-deck-summary">{story.excerpt}</div>
              <a href={localePath(locale, `/stories/${story.id}`)}>{readLabel}<span aria-hidden="true"> →</span></a>
            </div>
          </article>
        );
      })}
    </div>
  );
}
