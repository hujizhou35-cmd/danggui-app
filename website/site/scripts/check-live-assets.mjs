const origin = (process.argv[2] || 'https://danggui.hujizhou35.workers.dev').replace(/\/$/, '');
const pageUrl = `${origin}/zh-CN`;

const page = await fetch(pageUrl, {
  headers: { 'cache-control': 'no-cache' },
  redirect: 'follow',
});

if (!page.ok) {
  throw new Error(`${pageUrl} returned ${page.status}.`);
}

const html = await page.text();
const assetPaths = [...html.matchAll(/(?:href|src)="([^"#?]*\/_next\/static\/[^"#?]+)"/g)]
  .map((match) => match[1])
  .filter((value, index, values) => values.indexOf(value) === index);

if (assetPaths.length === 0) {
  throw new Error(`No _next/static assets were found in ${pageUrl}.`);
}

const failures = [];
for (const assetPath of assetPaths) {
  const assetUrl = new URL(assetPath, origin);
  const response = await fetch(assetUrl, {
    headers: { 'cache-control': 'no-cache' },
    redirect: 'follow',
  });
  const contentType = response.headers.get('content-type') || '';
  const isCss = assetUrl.pathname.endsWith('.css');
  const isJs = assetUrl.pathname.endsWith('.js');
  const validType = (isCss && contentType.includes('text/css'))
    || (isJs && contentType.includes('javascript'))
    || (!isCss && !isJs);

  if (!response.ok || !validType) {
    failures.push(`${assetUrl.pathname}: ${response.status} ${contentType || 'unknown content type'}`);
  }
}

if (failures.length > 0) {
  throw new Error(`Cloudflare asset smoke test failed:\n${failures.join('\n')}`);
}

console.log(`Verified ${assetPaths.length} live _next/static assets from ${pageUrl}.`);
