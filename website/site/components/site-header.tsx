import Image from 'next/image';
import { locales, type Locale } from '@/content/types';
import { getLocaleData, localePath, repositoryUrl } from '@/lib/content';

interface SiteHeaderProps {
  locale: Locale;
  routeSuffix?: string;
}

export function SiteHeader({ locale, routeSuffix = '' }: SiteHeaderProps) {
  const { ui } = getLocaleData(locale);
  const home = localePath(locale);
  const links = [
    { href: `${home}#features`, label: ui.nav.features },
    { href: localePath(locale, '/stories'), label: ui.nav.stories },
    { href: localePath(locale, '/download'), label: ui.nav.download },
    { href: localePath(locale, '/privacy'), label: ui.nav.privacy },
    { href: localePath(locale, '/support'), label: ui.nav.support },
  ];

  return (
    <header className="site-header">
      <div className="header-inner">
        <a className="brand" href={home} aria-label={ui.brandAria}>
          <Image src="/assets/app-icon.webp" width={42} height={42} alt="" priority />
          <span translate="no">当归</span>
        </a>

        <nav className="desktop-nav" aria-label={ui.nav.menu}>
          {links.map((link) => (
            <a href={link.href} key={link.href}>
              {link.label}
            </a>
          ))}
          <a href={repositoryUrl} target="_blank" rel="noreferrer">
            {ui.nav.github}
            <span className="sr-only"> ({ui.common.openNewWindow})</span>
          </a>
        </nav>

        <div className="header-actions">
          <LanguageSwitcher locale={locale} routeSuffix={routeSuffix} />
          <a className="header-download" href={localePath(locale, '/download')}>
            {ui.nav.download}
          </a>
          <details className="mobile-menu" name="header-popover">
            <summary aria-label={ui.nav.menu}>
              <span />
              <span />
            </summary>
            <div className="mobile-menu-panel">
              {links.map((link) => (
                <a href={link.href} key={link.href}>
                  {link.label}
                </a>
              ))}
              <a href={repositoryUrl} target="_blank" rel="noreferrer">
                {ui.nav.github}
                <span className="sr-only"> ({ui.common.openNewWindow})</span>
              </a>
            </div>
          </details>
        </div>
      </div>
    </header>
  );
}

function LanguageSwitcher({
  locale,
  routeSuffix,
}: {
  locale: Locale;
  routeSuffix: string;
}) {
  const { ui } = getLocaleData(locale);

  return (
    <details className="language-switcher" name="header-popover">
      <summary aria-label={ui.nav.language}>
        <span aria-hidden="true">{ui.shortLocale}</span>
      </summary>
      <ul>
        {locales.map((candidate) => {
          const copy = getLocaleData(candidate).ui;
          return (
            <li key={candidate}>
              <a
                href={localePath(candidate, routeSuffix)}
                hrefLang={candidate}
                lang={candidate}
                aria-current={candidate === locale ? 'page' : undefined}
              >
                {copy.localeName}
              </a>
            </li>
          );
        })}
      </ul>
    </details>
  );
}
