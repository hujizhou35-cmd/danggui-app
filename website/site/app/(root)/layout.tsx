import type { Metadata, Viewport } from 'next';
import { SOCIAL_IMAGE_PATH, siteUrl } from '@/lib/site-config';
import '../globals.css';

export const metadata: Metadata = {
  metadataBase: siteUrl,
  title: {
    default: '当归｜本地记录，不上传，不调用 AI',
    template: '%s｜当归',
  },
  description: '一款把事项、完成后的过往记录和独立笔记放在一起的本地优先应用。',
  icons: { icon: '/favicon.png' },
  openGraph: {
    siteName: '当归',
    type: 'website',
    images: [{ url: SOCIAL_IMAGE_PATH, width: 1280, height: 640, alt: '当归 · 本地记录' }],
  },
};

export const viewport: Viewport = { themeColor: '#F4EFE7' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
