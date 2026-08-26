import { fetchReleaseChannel, getRecommendedRelease, releasesUrl } from '@/lib/release-channel';

export async function GET() {
  const manifest = await fetchReleaseChannel();
  if (!manifest || !getRecommendedRelease(manifest)) {
    return Response.json(
      { available: false, releasesUrl },
      { status: 503, headers: { 'Cache-Control': 'public, max-age=30, s-maxage=60' } },
    );
  }

  return Response.json(
    { available: true, manifest },
    {
      headers: {
        'Cache-Control': 'public, max-age=60, s-maxage=300, stale-while-revalidate=300',
        'Content-Type': 'application/json; charset=utf-8',
      },
    },
  );
}
