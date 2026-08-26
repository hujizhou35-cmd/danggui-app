'use client';

import { useEffect, useState } from 'react';
import type { CSSProperties } from 'react';
import type { UiCopy } from '@/content/types';

const sectionIds = ['top', 'preview', 'features', 'stories', 'privacy', 'download'] as const;

export function ArcSectionNav({ copy }: { copy: UiCopy['home']['sectionNav'] }) {
  const [activeId, setActiveId] = useState<(typeof sectionIds)[number]>('top');
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    let frame = 0;
    const update = () => {
      frame = 0;
      const baseline = Math.max(120, window.innerHeight * 0.5);
      let current: (typeof sectionIds)[number] = 'top';
      for (const id of sectionIds) {
        const section = document.getElementById(id);
        if (section && section.getBoundingClientRect().top <= baseline) current = id;
      }
      setActiveId(current);
    };
    const schedule = () => {
      if (!frame) frame = window.requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule);
    return () => {
      window.removeEventListener('scroll', schedule);
      window.removeEventListener('resize', schedule);
      if (frame) window.cancelAnimationFrame(frame);
    };
  }, []);

  const labels = copy.items;
  const activeIndex = sectionIds.indexOf(activeId);

  return (
    <>
      <aside className="arc-nav-rail" aria-label={copy.label} data-hidden={hidden}>
        <button
          className="arc-nav-toggle"
          type="button"
          onClick={() => setHidden((value) => !value)}
          aria-expanded={!hidden}
        >
          <span aria-hidden="true">{hidden ? '›' : '‹'}</span>
          <span className="sr-only">{hidden ? copy.show : copy.hide}</span>
        </button>
        <nav className="arc-nav" hidden={hidden}>
          <span className="arc-baseline" aria-hidden="true" />
          {sectionIds.map((id, index) => {
            const distance = Math.abs(index - activeIndex);
            const style = {
              '--arc-shift': `${Math.min(54, distance * distance * 7)}px`,
              '--arc-y': `${(index - activeIndex) * 52}px`,
            } as CSSProperties;
            return (
              <a
                href={`#${id}`}
                key={id}
                style={style}
                aria-current={id === activeId ? 'location' : undefined}
              >
                <span aria-hidden="true">0{index + 1}</span>{labels[id]}
              </a>
            );
          })}
        </nav>
      </aside>
      <details className="mobile-section-nav">
        <summary>{copy.label}</summary>
        <nav aria-label={copy.label}>
          {sectionIds.map((id) => <a href={`#${id}`} key={id}>{labels[id]}</a>)}
        </nav>
      </details>
    </>
  );
}
