import 'dart:io';

/// Resolves an exact, visually reviewed Golden for the current rendering host.
///
/// Flutter's desktop test engine can rasterize the same bundled font slightly
/// differently on Windows and Linux. Keeping explicit host baselines preserves
/// pixel-for-pixel comparison without hiding those differences behind a fuzzy
/// percentage threshold.
String reviewedPlatformGolden(String fileName) {
  final platform = Platform.operatingSystem;
  if (platform == 'windows' || platform == 'linux') {
    return 'goldens/$platform/$fileName';
  }
  throw UnsupportedError(
    'No reviewed exact Golden baseline is registered for $platform. '
    'Generate, inspect, and commit a platform-specific baseline first.',
  );
}
