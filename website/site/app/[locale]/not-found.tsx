'use client';

import Image from 'next/image';
import { useParams } from 'next/navigation';
import type { Locale } from '@/content/types';

const copy: Record<Locale, { eyebrow: string; title: string; body: string; home: string }> = {
  'zh-CN': {
    eyebrow: '404 · 这一页还没有发芽',
    title: '纸页走到了空白处',
    body: '你要找的页面不在小当归的纸上花园里。',
    home: '返回当归首页',
  },
  en: {
    eyebrow: '404 · This page has not sprouted',
    title: 'The paper ends in a quiet blank',
    body: 'The page you are looking for is not in Little Danggui’s garden.',
    home: 'Back to Danggui',
  },
  ja: {
    eyebrow: '404 · このページはまだ芽吹いていません',
    title: '紙の先は、静かな余白でした',
    body: 'お探しのページは、小さな当帰の紙の庭にはありません。',
    home: '当帰のホームへ戻る',
  },
  ru: {
    eyebrow: '404 · Эта страница ещё не проросла',
    title: 'Лист закончился тихой пустотой',
    body: 'Такой страницы нет в бумажном саду Маленького Danggui.',
    home: 'Вернуться на главную',
  },
};

export default function NotFound() {
  const params = useParams<{ locale?: string }>();
  const locale = params.locale && params.locale in copy ? params.locale as Locale : 'zh-CN';
  const text = copy[locale];

  return (
    <main className="not-found">
      <Image src="/assets/pose-holding-note.png" width={220} height={220} alt="" priority />
      <p className="eyebrow">{text.eyebrow}</p>
      <h1>{text.title}</h1>
      <p>{text.body}</p>
      <a className="button button-primary" href={`/${locale}`}>{text.home}</a>
    </main>
  );
}
