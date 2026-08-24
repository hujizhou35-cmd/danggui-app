import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native launch stays paper-only while Flutter owns the brand composition',
    () {
      final root = Directory.current;
      String source(String path) =>
          File('${root.path}/$path').readAsStringSync();

      final pubspec = source('pubspec.yaml');
      final nativeSplashConfigStart = pubspec.indexOf(
        '\nflutter_native_splash:\n',
      );
      expect(nativeSplashConfigStart, greaterThanOrEqualTo(0));
      final nativeSplashConfig = pubspec.substring(nativeSplashConfigStart + 1);
      final startup = source('lib/src/features/launch/startup_page.dart');
      final launchBackground = source(
        'android/app/src/main/res/drawable/launch_background.xml',
      );
      final launchBackgroundV21 = source(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      );
      final transparentIcon = source(
        'android/app/src/main/res/drawable/transparent_splash_icon.xml',
      );
      final android12Styles = source(
        'android/app/src/main/res/values-v31/styles.xml',
      );
      final android12NightStyles = source(
        'android/app/src/main/res/values-night-v31/styles.xml',
      );
      final iosLaunchScreen = source(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      );

      expect(nativeSplashConfig, isNot(contains('danggui-launch-artwork')));
      expect(
        nativeSplashConfig,
        isNot(contains('danggui-native-splash-emblem')),
      );
      expect(
        nativeSplashConfig,
        contains('image: android/app/src/main/res/drawable/background.png'),
      );
      expect(startup, contains('assets/brand/danggui-launch-artwork.png'));
      expect(startup, contains('Duration(milliseconds: 1200)'));

      for (final background in <String>[
        launchBackground,
        launchBackgroundV21,
      ]) {
        expect(background, contains('@drawable/background'));
        expect(background, isNot(contains('@drawable/splash')));
      }

      expect(transparentIcon, contains('@android:color/transparent'));
      for (final styles in <String>[android12Styles, android12NightStyles]) {
        expect(styles, contains('@drawable/transparent_splash_icon'));
        expect(styles, contains('#F4EFE7'));
        expect(styles, isNot(contains('@drawable/android12splash')));
        expect(
          styles,
          isNot(contains('windowSplashScreenIconBackgroundColor')),
        );
      }
      expect(android12NightStyles, isNot(contains('Theme.Black')));
      expect(android12NightStyles, isNot(contains('?android:colorBackground')));
      expect(android12NightStyles, contains('@color/danggui_paper'));

      expect(iosLaunchScreen, contains('image="LaunchBackground"'));
      expect(iosLaunchScreen, isNot(contains('image="LaunchImage"')));

      for (final path in <String>[
        'assets/brand/danggui-launch-artwork.png',
        'android/app/src/main/res/drawable/background.png',
        'android/app/src/main/res/drawable/transparent_splash_icon.xml',
        'ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png',
      ]) {
        final file = File('${root.path}/$path');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing launch asset: $path',
        );
      }
    },
  );
}
