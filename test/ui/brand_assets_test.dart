import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold-start and Flutter loading surfaces use the launch illustration',
    () {
      final root = Directory.current;
      final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
      final startup = File(
        '${root.path}/lib/src/features/launch/startup_page.dart',
      ).readAsStringSync();
      final android12Styles = File(
        '${root.path}/android/app/src/main/res/values-v31/styles.xml',
      ).readAsStringSync();

      expect(
        pubspec,
        contains('image: assets/brand/danggui-launch-artwork.png'),
      );
      expect(
        pubspec,
        contains('image: assets/brand/danggui-native-splash-emblem.png'),
      );
      expect(startup, contains('assets/brand/danggui-launch-artwork.png'));
      expect(
        android12Styles,
        contains(
          '<item name="android:windowSplashScreenAnimatedIcon">'
          '@drawable/android12splash</item>',
        ),
      );

      for (final path in <String>[
        'assets/brand/danggui-launch-artwork.png',
        'assets/brand/danggui-native-splash-emblem.png',
        'android/app/src/main/res/drawable-xhdpi/splash.png',
        'android/app/src/main/res/drawable-xhdpi/android12splash.png',
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png',
      ]) {
        final file = File('${root.path}/$path');
        expect(file.existsSync(), isTrue, reason: 'Missing brand asset: $path');
        expect(
          file.lengthSync(),
          greaterThan(1024),
          reason: 'Empty asset: $path',
        );
      }
    },
  );
}
