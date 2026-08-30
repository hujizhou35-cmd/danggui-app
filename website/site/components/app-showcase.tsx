import Image from 'next/image';
import type { Locale, UiCopy } from '@/content/types';

const workflowFrames = [
  ['01-startup.png', '02-tasks-reminders.png'],
  ['03-task-detail.png', '04-past.png'],
  ['05-notes.png', '06-export-settings.png'],
] as const;

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
              {workflowFrames[index].map((file, frameIndex) => (
                <div className="showcase-device" key={file}>
                  <Image
                    src={`/assets/ui/v1.1.5/${language}/${file}`}
                    alt={`${alt}：${item.title} · ${frameIndex + 1}`}
                    fill
                    loading="eager"
                    sizes="(max-width: 600px) 36vw, (max-width: 1100px) 17vw, 12vw"
                  />
                </div>
              ))}
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
