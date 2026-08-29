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
    expect(version.name, '1.1.5');
    expect(version.buildNumber, 6);
    expect(version.technical, '1.1.5+6');
    expect(appVersionName, version.name);
    expect(appBuildNumber, version.buildNumber);
    expect(appTechnicalVersion, version.technical);
    expect(expectedAndroidPermissions, <String>{
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.USE_FULL_SCREEN_INTENT',
      'android.permission.VIBRATE',
      'android.permission.WAKE_LOCK',
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
      'lib/xcui_main.dart',
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

  test('iOS CI uses disposable simulators and immutable free runners', () {
    final mobileWorkflow = File(
      _join(repositoryRoot.path, '.github/workflows/mobile-ci.yml'),
    ).readAsStringSync();
    final deepWorkflow = File(
      _join(repositoryRoot.path, '.github/workflows/ios-deep-audit.yml'),
    ).readAsStringSync();
    final simulatorScript = File(
      _join(repositoryRoot.path, 'tool/run_ios_simulator_tests.sh'),
    ).readAsStringSync();
    final productionMain = File(_join(repositoryRoot.path, 'lib/main.dart'))
        .readAsStringSync();
    final xcuiMain = File(_join(repositoryRoot.path, 'lib/xcui_main.dart'))
        .readAsStringSync();
    final releaseVerifier = File(
      _join(repositoryRoot.path, 'tool/verify_release_assets.sh'),
    ).readAsStringSync();

    final workflows = '$mobileWorkflow\n$deepWorkflow';
    expect(workflows, contains('runs-on: macos-15'));
    expect(workflows, contains('runs-on: macos-26'));
    expect(mobileWorkflow, contains('name: Unsigned iOS source build'));
    expect(mobileWorkflow, contains('needs: [ios-fallback, ios-unsigned]'));
    expect(workflows, isNot(contains('macos-latest')));
    expect(
      RegExp(r'runs-on:\s*[^\n]*(large|xlarge)').hasMatch(workflows),
      isFalse,
    );
    for (final match in RegExp(
      r'^\s*uses:\s*[^@\s]+@([^\s#]+)',
      multiLine: true,
    ).allMatches(workflows)) {
      expect(match.group(1), matches(RegExp(r'^[0-9a-f]{40}$')));
    }

    for (final marker in <String>[
      'xcrun simctl create',
      'xcrun simctl delete',
      '-only-testing:RunnerTests',
      '-only-testing:RunnerUITests',
      'xcresulttool get test-results summary',
      'ui_test_count=2',
      'system_delivery=device-unverified',
      '--config-only',
      r'FLUTTER_TARGET="${validated_xcui_flutter_target}"',
      '-configuration Debug',
    ]) {
      expect(simulatorScript, contains(marker), reason: marker);
    }
    expect(simulatorScript, isNot(contains('simctl erase')));
    expect(simulatorScript, isNot(contains('mapfile')));
    expect(productionMain, isNot(contains('xcui_scenario_harness.dart')));
    expect(productionMain, isNot(contains('DANGGUI_XCUITEST_SCENARIO')));
    expect(xcuiMain, contains('if (!kDebugMode)'));
    expect(
      xcuiMain,
      contains("Platform.environment['DANGGUI_XCUITEST_SCENARIO']"),
    );
    expect(xcuiMain, contains('_supportedXcuiScenarios.contains(scenario)'));

    for (final marker in <String>[
      'SOURCE_COMMIT.txt does not match the protected tag commit',
      'ui_test_count=2',
      'testTaskReminderDeleteAndRestoreContract',
      'testBackupRestoreRebuildsReminderContract',
      'notification_gateway=in-process-contract-double',
    ]) {
      expect(releaseVerifier, contains(marker), reason: marker);
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

    final dataProtection = File(
      _join(fixture.path, 'ios/Runner/DangguiDataProtection.swift'),
    );
    dataProtection.writeAsStringSync(
      dataProtection
          .readAsStringSync()
          .replaceFirst(
            'rootValues.isExcludedFromBackup = true',
            'rootValues.isExcludedFromBackup = false',
          )
          .replaceFirst(
            'FileProtectionType.completeUntilFirstUserAuthentication',
            'FileProtectionType.none',
          )
          .replaceFirst(
            'readBackupExclusion(rootURL) == true',
            'readBackupExclusion(rootURL) == false',
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
    expect(failures, contains('firebase_core'));
    expect(failures, contains('alarm-clock or full-screen notification API'));
    expect(failures, contains('hard-coded remote URL'));
    expect(failures, contains('entitlement files require review'));
    expect(
      failures,
      contains('iOS private data must use explicit file protection'),
    );
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
    'ios/Runner/DangguiDataProtection.swift',
    'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
    'ios/Runner/en.lproj/InfoPlist.strings',
    'ios/Runner/ja.lproj/InfoPlist.strings',
    'ios/Runner/ru.lproj/InfoPlist.strings',
    'ios/Runner/AppDelegate.swift',
    'ios/Runner/SceneDelegate.swift',
    'ios/Runner/Runner-Bridging-Header.h',
    'ios/Runner/Runner.entitlements',
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
