export const DEFAULT_SITE_ORIGIN = 'https://danggui.hujizhou35.workers.dev';
export const SUPPORT_EMAIL = 'opusdog@163.com';
export const SOCIAL_IMAGE_PATH = '/assets/og.jpg';

function resolveSiteOrigin(value: string | undefined) {
  try {
    const candidate = new URL(value?.trim() || DEFAULT_SITE_ORIGIN);
    if (candidate.protocol !== 'https:' && candidate.protocol !== 'http:') {
      return DEFAULT_SITE_ORIGIN;
    }
    return candidate.origin;
  } catch {
    return DEFAULT_SITE_ORIGIN;
  }
}

export const siteOrigin = resolveSiteOrigin(process.env.NEXT_PUBLIC_SITE_ORIGIN);
export const siteUrl = new URL(`${siteOrigin}/`);

export function absoluteSiteUrl(pathname = '/') {
  return new URL(pathname, siteUrl).toString();
}
