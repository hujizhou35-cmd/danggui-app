import type { Metadata } from 'next';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { AppShowcase } from '@/components/app-showcase';
import { ArcSectionNav } from '@/components/arc-section-nav';
import { ReleaseActionLink, ReleaseBadge } from '@/components/release-status';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { StoryDeck } from '@/components/story-deck';
import { locales } from '@/content/types';
import { getLocaleData, isLocale, localePath } from '@/lib/content';
import { createPageMetadata } from '@/lib/metadata';

type PageProps = { params: Promise<{ locale: string }> };

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const { narrative, ui } = getLocaleData(locale);
  return createPageMetadata({ locale, title: narrative.hero.title, description: ui.metaDescription });
}

export default async function LocaleHome({ params }: PageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { narrative, ui } = getLocaleData(locale);
  const featuredStories = [0, 1, 2, 3, 5].map((index) => narrative.stories[index]);

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} />
      <main className="home-main" id="main-content">
        <ArcSectionNav copy={ui.home.sectionNav} />
        <div className="home-content">
          <section className="hero home-section" id="top">
            <div className="hero-copy">
              <div className="status-row">
                <span className="status-dot" aria-hidden="true" />
                <ReleaseBadge copy={ui.common} />
              </div>
              <p className="eyebrow">{ui.home.promise}</p>
              <h1>{narrative.hero.title}</h1>
              <p className="hero-description">{narrative.hero.description}</p>
              <div className="hero-actions">
                <ReleaseActionLink
                  className="button button-primary"
                  readyLabel={ui.home.primaryCta}
                  unavailableLabel={ui.download.allReleasesCta}
                />
                <a className="button button-quiet" href="#preview">{ui.home.secondaryCta}</a>
              </div>
              <p className="release-note">{ui.home.releaseNote}</p>
            </div>
            <div className="hero-art">
              <Image
                src={narrative.hero.image}
                fill
                priority
                sizes="(max-width: 760px) 92vw, 44vw"
                alt={narrative.hero.alt}
                style={{ objectFit: 'contain' }}
              />
            </div>
          </section>

          <section className="preview-section home-section" id="preview">
            <div className="section-heading section-heading-left">
              <p className="eyebrow">{ui.home.previewEyebrow}</p>
              <h2>{ui.home.previewTitle}</h2>
              <p>{ui.home.previewDescription}</p>
            </div>
            <AppShowcase
              locale={locale}
              copy={ui.home.showcaseItems}
              capture={ui.home.showcaseCapture}
              alt={ui.home.previewAlt}
            />
          </section>

          <section className="features-section home-section" id="features">
            <div className="section-heading section-heading-left">
              <p className="eyebrow">{ui.home.featuresEyebrow}</p>
              <h2>{ui.home.featuresTitle}</h2>
            </div>
            <div className="feature-grid">
              {narrative.features.map((feature, index) => (
                <article className="feature-card" key={feature.id}>
                  <div className="feature-visual">
                    <Image src={feature.image} alt={feature.alt} fill sizes="(max-width: 760px) 92vw, 30vw" />
                  </div>
                  <div className="feature-copy">
                    <span className="feature-mark" aria-hidden="true">0{index + 1}</span>
                    <h3>{feature.title}</h3>
                    <p>{feature.description}</p>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <section className="stories-home home-section" id="stories">
            <div className="section-heading section-heading-left stories-heading">
              <div>
                <p className="eyebrow">{ui.home.storiesEyebrow}</p>
                <h2>{ui.home.storiesTitle}</h2>
                <p>{ui.home.storiesDescription}</p>
              </div>
              <a className="text-link" href={localePath(locale, '/stories')}>
                {ui.common.viewAllStories}<span aria-hidden="true"> →</span>
              </a>
            </div>
            <StoryDeck
              stories={featuredStories}
              locale={locale}
              readLabel={ui.common.readStory}
              ariaLabel={ui.home.storiesTitle}
            />
          </section>

          <section className="privacy-promise home-section" id="privacy">
            <div className="privacy-character">
              <Image
                src="/assets/pose-guarding-seed.png"
                width={360}
                height={360}
                alt=""
                sizes="(max-width: 760px) 42vw, 22vw"
              />
            </div>
            <div className="privacy-copy">
              <p className="eyebrow">{ui.home.privacyEyebrow}</p>
              <h2>{ui.home.privacyTitle}</h2>
              <p>{ui.home.privacyDescription}</p>
              <ul>
                {ui.home.privacyPoints.map((point) => <li key={point}>{point}</li>)}
              </ul>
              <a className="text-link" href={localePath(locale, '/privacy')}>
                {ui.nav.privacy}<span aria-hidden="true"> →</span>
              </a>
            </div>
          </section>

          <section className="download-band home-section" id="download">
            <div>
              <div className="status-row status-row-light">
                <span className="status-dot" aria-hidden="true" />
                <ReleaseBadge copy={ui.common} />
              </div>
              <p className="eyebrow">{ui.home.downloadEyebrow}</p>
              <h2>{ui.home.downloadTitle}</h2>
              <p>{ui.home.downloadDescription}</p>
            </div>
            <div className="download-actions">
              <a className="button button-light" href={localePath(locale, '/download')}>{ui.home.androidCta}</a>
              <a className="button button-dark-outline" href={localePath(locale, '/download')}>{ui.home.iosCta}</a>
            </div>
          </section>
        </div>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
