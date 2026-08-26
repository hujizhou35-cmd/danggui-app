import type { Metadata } from 'next';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
import { locales } from '@/content/types';
import { getLocaleData, isLocale, repositoryUrl } from '@/lib/content';
import { createPageMetadata } from '@/lib/metadata';
import { SUPPORT_EMAIL } from '@/lib/site-config';

type PageProps = { params: Promise<{ locale: string }> };

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const { ui } = getLocaleData(locale);
  return createPageMetadata({ locale, title: ui.privacy.title, description: ui.privacy.intro, suffix: '/privacy' });
}

export default async function PrivacyPage({ params }: PageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { ui } = getLocaleData(locale);

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} routeSuffix="/privacy" />
      <main className="privacy-main" id="main-content">
        <header className="privacy-hero">
          <div>
            <p className="eyebrow">{ui.privacy.eyebrow}</p>
            <h1>{ui.privacy.title}</h1>
            <p>{ui.privacy.intro}</p>
          </div>
          <Image src="/assets/pose-listening.png" width={390} height={390} alt="" priority />
        </header>
        <section className="principle-grid">
          {ui.privacy.principles.map((principle, index) => (
            <article key={principle.title}>
              <span aria-hidden="true">0{index + 1}</span>
              <h2>{principle.title}</h2>
              <p>{principle.body}</p>
            </article>
          ))}
        </section>
        <section className="privacy-policy" aria-labelledby="privacy-policy-title">
          <header className="privacy-policy-heading">
            <p className="eyebrow">{ui.privacy.policyEyebrow}</p>
            <div>
              <h2 id="privacy-policy-title">{ui.privacy.policyTitle}</h2>
              <p className="policy-updated">{ui.privacy.policyUpdated}</p>
            </div>
          </header>
          <div className="privacy-controller">
            <h3>{ui.privacy.controllerTitle}</h3>
            <p>{ui.privacy.controllerBody}</p>
          </div>
          <div className="privacy-policy-grid">
            {ui.privacy.policySections.map((section) => (
              <article key={section.title}>
                <h3>{section.title}</h3>
                <p>{section.body}</p>
              </article>
            ))}
          </div>
        </section>
        <section className="proof-section">
          <div>
            <p className="eyebrow">{ui.privacy.proofEyebrow}</p>
            <h2>{ui.privacy.proofTitle}</h2>
            <p>{ui.privacy.proofBody}</p>
          </div>
          <div className="proof-actions">
            <a className="button button-light" href="/go/privacy-audit" target="_blank" rel="noreferrer">{ui.privacy.proofCta}</a>
            <a className="button button-dark-outline" href={repositoryUrl} target="_blank" rel="noreferrer">GitHub</a>
          </div>
        </section>
        <aside className="site-privacy-note">
          <h2>{ui.privacy.siteTitle}</h2>
          <div>
            <p>{ui.privacy.siteBody}</p>
            <a className="text-link" href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent('[Danggui] Privacy')}`}>
              {ui.privacy.contactCta}: {SUPPORT_EMAIL}
            </a>
          </div>
        </aside>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
