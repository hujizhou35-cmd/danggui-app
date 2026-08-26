'use client';

import { useEffect, useState } from 'react';
import type { Locale, UiCopy } from '@/content/types';
import type { PublishedRelease, ReleaseChannelManifest } from '@/lib/release-channel';

type ReleaseState =
  | { status: 'loading'; release: null; manifest: null }
  | { status: 'ready'; release: PublishedRelease; manifest: ReleaseChannelManifest }
  | { status: 'unavailable'; release: null; manifest: null };

let releaseRequest: Promise<ReleaseState> | null = null;

function requestPublishedRelease(): Promise<ReleaseState> {
  if (releaseRequest) return releaseRequest;
  releaseRequest = (async () => {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 5_000);
    try {
      const response = await fetch('/api/release', {
        signal: controller.signal,
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) throw new Error('release unavailable');
      const payload = (await response.json()) as {
        available?: boolean;
        manifest?: ReleaseChannelManifest;
      };
      const manifest = payload.manifest;
      const channel = manifest?.recommended;
      const release = channel ? manifest?.[channel] : null;
      if (!payload.available || !manifest || !release) throw new Error('release unavailable');
      return { status: 'ready', release, manifest };
    } catch {
      return { status: 'unavailable', release: null, manifest: null };
    } finally {
      window.clearTimeout(timer);
    }
  })();
  return releaseRequest;
}

function usePublishedRelease(): ReleaseState {
  const [state, setState] = useState<ReleaseState>({ status: 'loading', release: null, manifest: null });

  useEffect(() => {
    let mounted = true;
    requestPublishedRelease().then((nextState) => {
      if (mounted) setState(nextState);
    });

    return () => {
      mounted = false;
    };
  }, []);

  return state;
}

export function ReleaseBadge({ copy }: { copy: UiCopy['common'] }) {
  const state = usePublishedRelease();
  const label = state.release
    ? `v${state.release.version} · ${state.release.prerelease ? copy.preRelease : copy.stableRelease}`
    : state.status === 'unavailable'
      ? copy.releaseUnavailable
      : copy.currentPublicRelease;

  return <span aria-live="polite">{label}</span>;
}

export function ReleaseActionLink({
  readyLabel,
  unavailableLabel,
  className,
}: {
  readyLabel: string;
  unavailableLabel: string;
  className: string;
}) {
  const state = usePublishedRelease();
  return (
    <a className={className} href="/go/release" target="_blank" rel="noreferrer">
      {state.status === 'unavailable' ? unavailableLabel : readyLabel}
    </a>
  );
}

function formatDate(locale: Locale, value: string) {
  try {
    return new Intl.DateTimeFormat(locale, { year: 'numeric', month: 'short', day: 'numeric' })
      .format(new Date(value));
  } catch {
    return value.slice(0, 10);
  }
}

function formatSize(locale: Locale, size: number) {
  const value = new Intl.NumberFormat(locale, { maximumFractionDigits: 1, minimumFractionDigits: 1 })
    .format(size / 1_000_000);
  return `${value}\u00A0MB`;
}

export function ReleaseDownloadPanels({
  locale,
  common,
  copy,
}: {
  locale: Locale;
  common: UiCopy['common'];
  copy: UiCopy['download'];
}) {
  const state = usePublishedRelease();
  const release = state.release;
  const optionalPreview = state.status === 'ready' && state.manifest.stable
    ? state.manifest.preview
    : null;
  const unavailable = state.status === 'unavailable';
  const statusLabel = release
    ? `v${release.version} · ${release.prerelease ? common.preRelease : common.stableRelease}`
    : state.status === 'unavailable'
      ? common.releaseUnavailable
      : common.currentPublicRelease;

  return (
    <section className="platform-grid">
      <article className="platform-card platform-android">
        <div className="platform-label" aria-live="polite" aria-atomic="true"><span aria-hidden="true">●</span> {statusLabel}</div>
        {release ? <p className="release-date">{common.publishedOn} {formatDate(locale, release.publishedAt)}</p> : null}
        <h2>{copy.androidTitle}</h2>
        <p>{copy.androidBody}</p>
        <p className="file-recommendation">
          {release ? `${release.assets.android.name} · ${formatSize(locale, release.assets.android.size)}` : copy.androidRecommended}
        </p>
        <div className="platform-actions">
          <a className="button button-primary" href={unavailable ? '/go/release' : '/go/android'}>
            {unavailable ? copy.allReleasesCta : copy.androidCta}
          </a>
          {!unavailable ? <a className="button button-outline" href="/go/release" target="_blank" rel="noreferrer">
            {copy.releaseCta}
          </a> : null}
        </div>
        {!unavailable ? <div className="verification-panel">
          <h3>{copy.checksumTitle}</h3>
          <p>{copy.checksumBody}</p>
          <a className="text-link" href="/go/checksums">{copy.checksumCta}<span aria-hidden="true"> →</span></a>
        </div> : null}
      </article>
      <article className="platform-card platform-ios">
        <div className="platform-label">{copy.iosTitle} · {copy.sourceLabel}</div>
        <h2>{copy.iosTitle}</h2>
        <p>{copy.iosBody}</p>
        <p className="warning-note">{copy.iosWarning}</p>
        {release ? <p className="source-file">{release.assets.iosSource.name} · {formatSize(locale, release.assets.iosSource.size)}</p> : null}
        <div className="platform-actions">
          <a className="button button-outline" href={unavailable ? '/go/release' : '/go/ios-source'}>
            {unavailable ? copy.allReleasesCta : copy.iosCta}
          </a>
          {!unavailable ? <a className="text-link" href="/go/ios-guide" target="_blank" rel="noreferrer">{copy.iosGuideCta} <span aria-hidden="true">→</span></a> : null}
        </div>
        {optionalPreview ? (
          <aside className="channel-alternative">
            <span>{copy.previewAvailable} · v{optionalPreview.version}</span>
            <a href={optionalPreview.releaseUrl} target="_blank" rel="noreferrer">{copy.previewCta}<span aria-hidden="true"> →</span></a>
          </aside>
        ) : null}
        {!unavailable ? <a className="all-releases-link" href="https://github.com/hujizhou35-cmd/danggui-app/releases" target="_blank" rel="noreferrer">{copy.allReleasesCta}<span aria-hidden="true"> →</span></a> : null}
      </article>
    </section>
  );
}
