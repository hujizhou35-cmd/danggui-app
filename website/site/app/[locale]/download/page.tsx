import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ReleaseDownloadPanels } from '@/components/release-status';
import { SiteFooter } from '@/components/site-footer';
import { SiteHeader } from '@/components/site-header';
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
  return createPageMetadata({ locale, title: ui.download.title, description: ui.download.intro, suffix: '/download' });
}

export default async function DownloadPage({ params }: PageProps) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { ui } = getLocaleData(locale);

  return (
    <>
      <a className="skip-link" href="#main-content">{ui.skipLink}</a>
      <SiteHeader locale={locale} routeSuffix="/download" />
      <main className="inner-main" id="main-content">
        <header className="page-hero download-hero">
          <p className="eyebrow">{ui.download.eyebrow}</p>
          <h1>{ui.download.title}</h1>
          <p>{ui.download.intro}</p>
        </header>
        <ReleaseDownloadPanels locale={locale} common={ui.common} copy={ui.download} />
        <section className="before-panel">
          <h2>{ui.download.beforeTitle}</h2>
          <ol>
            {ui.download.beforeItems.map((item) => <li key={item}>{item}</li>)}
          </ol>
        </section>
      </main>
      <SiteFooter locale={locale} />
    </>
  );
}
