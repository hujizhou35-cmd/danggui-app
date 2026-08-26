import Image from 'next/image';
import type { Locale, UiCopy } from '@/content/types';

const files = ['01-plan.png', '02-reflect.png', '03-export.png'];

export function AppShowcase({
  locale,
  copy,
  capture,
  alt,
}: {
  locale: Locale;
  copy: UiCopy['home']['showcaseItems'];
  capture: string;
  alt: string;
}) {
  const language = locale === 'zh-CN' ? 'zh' : 'en';
  return (
    <div className="showcase-wrap">
      <p className="capture-label"><span aria-hidden="true">●</span>{capture}</p>
      <div className="showcase-grid">
        {copy.map((item, index) => (
          <figure className="showcase-card" key={item.title}>
            <div className="showcase-image">
              <Image
                src={`/assets/ui/v1.1.2/${language}/${files[index]}`}
                alt={`${alt}：${item.title}`}
                fill
                sizes="(max-width: 760px) 92vw, (max-width: 1100px) 44vw, 30vw"
              />
            </div>
            <figcaption>
              <span aria-hidden="true">0{index + 1}</span>
              <div><h3>{item.title}</h3><p>{item.body}</p></div>
            </figcaption>
          </figure>
        ))}
      </div>
    </div>
  );
}
