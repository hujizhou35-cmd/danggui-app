import { NextResponse } from 'next/server';
import {
  fetchReleaseChannel,
  getRecommendedRelease,
  releaseDocumentUrl,
  releasesUrl,
  repositoryUrl,
} from '@/lib/release-channel';

type RouteProps = { params: Promise<{ target: string }> };

export async function GET(_request: Request, { params }: RouteProps) {
  const { target } = await params;
  const allowedTargets = {
    release: true,
    android: true,
    'ios-source': true,
    checksums: true,
    'ios-guide': true,
    'privacy-audit': true,
    license: true,
    trademark: true,
  };
  if (!(target in allowedTargets)) {
    return new Response('Not found', { status: 404 });
  }

  const manifest = await fetchReleaseChannel();
  const release = manifest ? getRecommendedRelease(manifest) : null;

  const dynamicTargets: Record<string, string | undefined> = release
    ? {
        release: release.releaseUrl,
        android: release.assets.android.downloadUrl,
        'ios-source': release.assets.iosSource.downloadUrl,
        checksums: release.assets.checksums.downloadUrl,
        'ios-guide': releaseDocumentUrl(release.tag, 'docs/architecture/ios-source-build.md'),
        'privacy-audit': releaseDocumentUrl(release.tag, 'docs/qa/privacy-platform-audit.md'),
        license: releaseDocumentUrl(release.tag, 'LICENSE'),
        trademark: releaseDocumentUrl(release.tag, 'TRADEMARKS.md'),
      }
    : {};

  const fallback = target === 'license'
    ? `${repositoryUrl}/blob/main/LICENSE`
    : target === 'trademark'
      ? `${repositoryUrl}/blob/main/TRADEMARKS.md`
      : releasesUrl;
  return NextResponse.redirect(dynamicTargets[target] ?? fallback, 307);
}
