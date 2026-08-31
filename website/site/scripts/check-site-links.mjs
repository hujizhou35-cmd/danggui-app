const baseUrl = (process.env.SMOKE_BASE_URL ?? 'http://localhost:3000').replace(/\/$/, '');
const locales = ['zh-CN', 'en', 'ja', 'ru'];
const stories = Array.from({ length: 8 }, (_, index) => `story-${String(index + 1).padStart(2, '0')}`);

const pages = ['/'];
for (const locale of locales) {
  pages.push(
    `/${locale}`,
    `/${locale}/download`,
    `/${locale}/privacy`,
    `/${locale}/support`,
    `/${locale}/stories`,
    ...stories.map((story) => `/${locale}/stories/${story}`),
  );
}

const failures = [];
const internalLinks = new Set();
const mailLinks = new Set();

for (const path of pages) {
  const response = await fetch(`${baseUrl}${path}`, { redirect: 'manual' });
  if (path === '/') {
    if (response.status < 300 || response.status >= 400) failures.push(`${path} returned ${response.status}, expected redirect`);
    continue;
  }
  if (response.status !== 200) {
    failures.push(`${path} returned ${response.status}`);
    continue;
  }

  const html = await response.text();
  for (const match of html.matchAll(/href=["']([^"']+)["']/g)) {
    const href = match[1].replaceAll('&amp;', '&');
    if (!href || href === '#') failures.push(`${path} contains an empty link target`);
    else if (href.startsWith('mailto:')) mailLinks.add(href);
    else if (href.startsWith('/')) internalLinks.add(href.split('#', 1)[0]);
  }
}

for (const href of internalLinks) {
  const response = await fetch(`${baseUrl}${href}`, { redirect: 'manual' });
  if (response.status < 200 || response.status >= 400) failures.push(`${href} returned ${response.status}`);
}

for (const href of mailLinks) {
  if (!/^mailto:[^@\s]+@[^@\s]+\.[^@\s]+$/i.test(href)) failures.push(`Invalid mail link: ${href}`);
}

const notFound = await fetch(`${baseUrl}/zh-CN/not-a-real-page`, { redirect: 'manual' });
if (notFound.status !== 404) failures.push(`Brand 404 returned ${notFound.status}`);

if (failures.length) {
  console.error(failures.join('\n'));
  process.exitCode = 1;
} else {
  console.log(`Checked ${pages.length} pages, ${internalLinks.size} internal links, ${mailLinks.size} mail links, and the branded 404.`);
}
