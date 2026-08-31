import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { locales } from '@/content/types';
import { getLocaleData, isLocale, localePath, repositoryUrl } from '@/lib/content';
import { createPageMetadata } from '@/lib/metadata';
import { SUPPORT_EMAIL } from '@/lib/site-config';

type PageProps = { params: Promise<{ locale: string }> };

const issuesUrl = `${repositoryUrl}/issues`;

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const { ui } = getLocaleData(locale);
  return createPageMetadata({
    locale,
    title: ui.support.title,
    description: ui.support.intro,
    suffix: '/support',
  });
}

export default async function SupportPage({ params }: PageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { ui } = getLocaleData(locale);
  const mailto = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(`[当归] ${ui.support.title}`)}`;

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} routeSuffix="/support" />
      <main className="support-main" id="main-content">
        <header className="support-hero">
          <div className="support-hero-copy">
            <p className="eyebrow">{ui.support.eyebrow}</p>
            <h1>{ui.support.title}</h1>
            <p>{ui.support.intro}</p>
          </div>

          <aside className="support-contact-card" aria-labelledby="support-contact-title">
            <p className="eyebrow">{ui.support.contactEyebrow}</p>
            <h2 id="support-contact-title">{ui.support.contactTitle}</h2>
            <p>{ui.support.contactBody}</p>
            <a className="support-email" href={mailto}>
              <span>{ui.support.emailCta}</span>
              <strong>{SUPPORT_EMAIL}</strong>
            </a>
            <div className="support-actions">
              <a className="button button-light" href={mailto}>{ui.support.emailCta}</a>
              <a className="button button-dark-outline" href={issuesUrl} target="_blank" rel="noreferrer">
                {ui.support.issuesCta}
                <span className="sr-only"> ({ui.common.openNewWindow})</span>
              </a>
            </div>
            <a className="support-release-link" href={localePath(locale, '/download')}>
              {ui.support.downloadCta} →
            </a>
          </aside>
        </header>

        <aside className="support-warning">
          <span aria-hidden="true">!</span>
          <div>
            <h2>{ui.support.warningTitle}</h2>
            <p>{ui.support.warningBody}</p>
          </div>
        </aside>

        <section className="support-faq" aria-labelledby="support-faq-title">
          <header>
            <p className="eyebrow">{ui.support.faqEyebrow}</p>
            <h2 id="support-faq-title">{ui.support.faqTitle}</h2>
          </header>
          <div className="faq-list">
            {ui.support.faqs.map((faq, index) => (
              <details key={faq.question} open={index === 0}>
                <summary>
                  <span aria-hidden="true">{String(index + 1).padStart(2, '0')}</span>
                  <strong>{faq.question}</strong>
                </summary>
                <div className="faq-answer">
                  <p>{faq.answer}</p>
                </div>
              </details>
            ))}
          </div>
        </section>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
