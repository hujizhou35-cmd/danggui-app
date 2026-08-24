import 'dart:io';

import 'package:danggui/src/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/audit_offline_boundary.dart';

void main() {
  final repositoryRoot = Directory.current.absolute;

  test('checked-in mobile source satisfies the release privacy contract', () {
    final report = auditPrivacyAndPlatform(
      repositoryRoot,
      scanResolvedPlugins: false,
    );

    expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    expect(report.checks.length, greaterThanOrEqualTo(50));
    expect(expectedApplicationId, 'com.danggui.memo');
    final version = readReleaseVersion(repositoryRoot);
    expect(version.name, '1.1.2');
    expect(version.buildNumber, 3);
    expect(version.technical, '1.1.2+3');
    expect(appVersionName, version.name);
    expect(appBuildNumber, version.buildNumber);
    expect(appTechnicalVersion, version.technical);
    expect(expectedAndroidPermissions, <String>{
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.VIBRATE',
    });
  });

  test(
    'production local notifications retain sound and vibration delivery',
    () {
      final source = File(
        _join(
          repositoryRoot.path,
          'lib/src/services/notifications/notification_coordinator.dart',
        ),
      ).readAsStringSync();

      for (final requiredSource in <String>[
        'vibrationPattern: request.vibrationEnabled',
        '_defaultVibrationPattern',
        'playSound: request.soundEnabled',
        'enableVibration: request.vibrationEnabled',
        'presentSound: request.soundEnabled',
        '_reminderChannelId(',
        'AndroidScheduleMode.exactAllowWhileIdle',
        'AndroidScheduleMode.inexactAllowWhileIdle',
      ]) {
        expect(source, contains(requiredSource), reason: requiredSource);
      }
      expect(
        source,
        contains('Int64List.fromList(<int>[0, 400, 200, 400])'),
        reason: 'API 24/25 requires an explicit vibration cadence.',
      );
    },
  );

  test('iOS source delivery declares a complete tracked content manifest', () {
    final script = File(
      _join(repositoryRoot.path, 'tool/build_ios_source_zip.sh'),
    ).readAsStringSync();

    expect(script, contains('git archive'));
    expect(script, contains('git ls-tree -r --name-only HEAD'));
    expect(script, contains('archive_manifest'));
    expect(script, contains('SOURCE_ARCHIVE_CONTENTS.txt'));
    for (final requiredPath in <String>[
      '.github/workflows/mobile-ci.yml',
      'android/app/build.gradle.kts',
      'integration_test/app_cold_start_test.dart',
      'ios/Runner.xcodeproj/project.pbxproj',
      'lib/main.dart',
      'pubspec.lock',
      'test/platform/privacy_platform_config_test.dart',
    ]) {
      expect(script, contains(requiredPath), reason: requiredPath);
    }
    for (final rejectedContent in <String>[
      r'\.env',
      'build(/|\$)',
      'dist(/|\$)',
      r'\.dart_tool',
      'keystore\\.properties',
      'mobileprovision',
      'PRIVATE KEY',
      'google-services\\.json',
    ]) {
      expect(script, contains(rejectedContent), reason: rejectedContent);
    }
  });

  test('audit fails closed when release capabilities drift', () {
    final fixture = _createAuditFixture(repositoryRoot);
    addTearDown(() => fixture.deleteSync(recursive: true));

    final manifest = File(
      _join(fixture.path, 'android/app/src/main/AndroidManifest.xml'),
    );
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceFirst(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
            '<uses-permission android:name="android.permission.INTERNET"/>'
            '<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>'
            '<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>',
      ),
    );

    final pubspec = File(_join(fixture.path, 'pubspec.yaml'));
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst(
        RegExp(r'^dependencies:\s*$', multiLine: true),
        'dependencies:\n  firebase_core: ^4.0.0',
      ),
    );

    final notificationSource = File(
      _join(
        fixture.path,
        'lib/src/services/notifications/notification_coordinator.dart',
      ),
    );

    final appDelegate = File(
      _join(fixture.path, 'ios/Runner/AppDelegate.swift'),
    );
    appDelegate.writeAsStringSync(
      appDelegate.readAsStringSync().replaceFirst(
        'values.isExcludedFromBackup = true',
        'values.isExcludedFromBackup = false',
      ),
    );

    final secureStorageSource = File(
      _join(
        fixture.path,
        'lib/src/services/backup/automatic_backup_coordinator.dart',
      ),
    );
    secureStorageSource.writeAsStringSync(
      secureStorageSource
          .readAsStringSync()
          .replaceFirst(
            'KeychainAccessibility.first_unlock_this_device',
            'KeychainAccessibility.first_unlock',
          )
          .replaceFirst('synchronizable: false', 'synchronizable: true'),
    );
    notificationSource.writeAsStringSync(
      notificationSource.readAsStringSync().replaceFirst(
        'AndroidScheduleMode.exactAllowWhileIdle',
        'AndroidScheduleMode.alarmClock',
      ),
    );

    final shellArtifactVerifier = File(
      _join(fixture.path, 'tool/verify_android_artifacts.sh'),
    );
    shellArtifactVerifier.writeAsStringSync(
      shellArtifactVerifier.readAsStringSync().replaceFirst(
        'V[[:digit:].]+ Signer:',
        'V2 Signer:',
      ),
    );

    File(_join(fixture.path, 'lib/network_probe.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "final endpoint = Uri.parse('https://invalid.example');\n",
      );

    File(_join(fixture.path, 'ios/Runner/Probe.entitlements'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '<plist><dict><key>aps-environment</key>'
        '<string>production</string></dict></plist>',
      );

    final report = auditPrivacyAndPlatform(fixture, scanResolvedPlugins: false);
    final failures = report.failures.join('\n');

    expect(report.passed, isFalse);
    expect(failures, contains('android.permission.INTERNET'));
    expect(failures, contains('android.permission.USE_EXACT_ALARM'));
    expect(failures, contains('android.permission.USE_FULL_SCREEN_INTENT'));
    expect(failures, contains('firebase_core'));
    expect(failures, contains('alarm-clock or full-screen notification API'));
    expect(failures, contains('hard-coded remote URL'));
    expect(failures, contains('entitlement files require review'));
    expect(failures, contains('exclude Application Support/danggui'));
    expect(failures, contains('this-device-only Keychain class'));
    expect(failures, contains('iCloud-synchronizable secure-storage option'));
    expect(failures, contains('old and Build Tools 36 certificate output'));
  });
}

Directory _createAuditFixture(Directory sourceRoot) {
  final fixture = Directory.systemTemp.createTempSync(
    'danggui-platform-audit-',
  );
  const files = <String>[
    'pubspec.yaml',
    'pubspec.lock',
    '.github/workflows/mobile-ci.yml',
    'tool/verify_android_artifacts.sh',
    'tool/verify_android_artifacts.ps1',
    'android/app/build.gradle.kts',
    'android/settings.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'android/app/src/debug/AndroidManifest.xml',
    'android/app/src/profile/AndroidManifest.xml',
    'android/app/src/main/res/values/strings.xml',
    'android/app/src/main/res/xml/backup_rules.xml',
    'android/app/src/main/res/xml/data_extraction_rules.xml',
    'android/app/src/main/kotlin/com/danggui/memo/MainActivity.kt',
    'ios/Runner/Info.plist',
    'ios/Runner/AppDelegate.swift',
    'ios/Runner/SceneDelegate.swift',
    'ios/Runner/Runner-Bridging-Header.h',
    'ios/Flutter/AppFrameworkInfo.plist',
    'ios/Runner.xcodeproj/project.pbxproj',
  ];

  for (final path in files) {
    final source = File(_join(sourceRoot.path, path));
    final destination = File(_join(fixture.path, path));
    destination.parent.createSync(recursive: true);
    source.copySync(destination.path);
  }
  _copyDartSources(
    Directory(_join(sourceRoot.path, 'lib')),
    Directory(_join(fixture.path, 'lib')),
  );
  return fixture;
}

void _copyDartSources(Directory source, Directory destination) {
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.dart')) {
      continue;
    }
    final relative = entity.path.substring(source.path.length + 1);
    final target = File(_join(destination.path, relative));
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}

String _join(String root, String relative) {
  return '$root${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}';
}
