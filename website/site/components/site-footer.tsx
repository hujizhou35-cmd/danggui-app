import Image from 'next/image';
import type { Locale } from '@/content/types';
import {
  getLocaleData,
  licenseUrl,
  localePath,
  repositoryUrl,
  trademarkUrl,
} from '@/lib/content';

export function SiteFooter({ locale }: { locale: Locale }) {
  const { ui } = getLocaleData(locale);

  return (
    <footer className="site-footer">
      <div className="footer-main">
        <div className="footer-brand">
          <Image src="/assets/app-icon.webp" width={48} height={48} alt="" />
          <div>
            <strong translate="no">当归</strong>
            <p>{ui.footer.tagline}</p>
          </div>
        </div>
        <nav aria-label={ui.nav.menu}>
          <a href={localePath(locale, '/stories')}>{ui.nav.stories}</a>
          <a href={localePath(locale, '/download')}>{ui.nav.download}</a>
          <a href={localePath(locale, '/privacy')}>{ui.nav.privacy}</a>
          <a href={localePath(locale, '/support')}>{ui.nav.support}</a>
          <a href={repositoryUrl} target="_blank" rel="noreferrer">
            {ui.footer.source}
          </a>
        </nav>
      </div>
      <div className="footer-legal">
        <a href={localePath(locale, '/download')}>{ui.footer.status}</a>
        <span aria-hidden="true">·</span>
        <a href={licenseUrl} target="_blank" rel="noreferrer">
          {ui.footer.license}
        </a>
        <span aria-hidden="true">·</span>
        <a href={trademarkUrl} target="_blank" rel="noreferrer">
          {ui.footer.trademark}
        </a>
      </div>
    </footer>
  );
}
