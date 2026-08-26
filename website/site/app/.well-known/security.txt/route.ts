import { absoluteSiteUrl, SUPPORT_EMAIL } from '@/lib/site-config';

export function GET() {
  const expires = new Date();
  expires.setUTCFullYear(expires.getUTCFullYear() + 1);

  const body = [
    `Contact: mailto:${SUPPORT_EMAIL}`,
    `Contact: ${absoluteSiteUrl('/en/support')}`,
    `Expires: ${expires.toISOString()}`,
    'Preferred-Languages: zh-CN, en, ja, ru',
    `Canonical: ${absoluteSiteUrl('/.well-known/security.txt')}`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Cache-Control': 'public, max-age=86400',
      'Content-Type': 'text/plain; charset=utf-8',
    },
  });
}
