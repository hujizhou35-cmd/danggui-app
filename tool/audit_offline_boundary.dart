import 'dart:convert';
import 'dart:io';

const String expectedApplicationId = 'com.danggui.memo';
const int expectedAndroidMinSdk = 24;
const int expectedAndroidTargetSdk = 36;
const int expectedAndroidCompileSdk = 36;
const String expectedIosDeploymentTarget = '15.0';

const Set<String> expectedAndroidPermissions = <String>{
  'android.permission.FOREGROUND_SERVICE',
  'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
  'android.permission.POST_NOTIFICATIONS',
  'android.permission.RECEIVE_BOOT_COMPLETED',
  'android.permission.SCHEDULE_EXACT_ALARM',
  'android.permission.USE_FULL_SCREEN_INTENT',
  'android.permission.VIBRATE',
  'android.permission.WAKE_LOCK',
};

const Set<String> approvedRuntimeDependencies = <String>{
  'archive',
  'collection',
  'cryptography',
  'cupertino_icons',
  'drift',
  'drift_flutter',
  'file_picker',
  'flutter',
  'flutter_local_notifications',
  'flutter_localizations',
  'flutter_riverpod',
  'flutter_secure_storage',
  'go_router',
  'intl',
  'path',
  'path_provider',
  'share_plus',
  'timezone',
  'uuid',
};

final class ReleaseVersion {
  const ReleaseVersion({required this.name, required this.buildNumber});

  final String name;
  final int buildNumber;

  String get technical => '$name+$buildNumber';

  static ReleaseVersion? tryParsePubspec(String pubspec) {
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+([1-9]\d*)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null) return null;
    return ReleaseVersion(
      name: match.group(1)!,
      buildNumber: int.parse(match.group(2)!),
    );
  }
}

ReleaseVersion readReleaseVersion(Directory root) {
  final pubspec = File(
    '${root.absolute.path}${Platform.pathSeparator}pubspec.yaml',
  ).readAsStringSync();
  final version = ReleaseVersion.tryParsePubspec(pubspec);
  if (version == null) {
    throw const FormatException(
      'pubspec.yaml version must use semantic-name+positive-build-number.',
    );
  }
  return version;
}

/// Result of the repository-level privacy and platform source audit.
final class PrivacyPlatformAuditReport {
  PrivacyPlatformAuditReport({
    required this.checks,
    required this.failures,
    required this.warnings,
  });

  final List<String> checks;
  final List<String> failures;
  final List<String> warnings;

  bool get passed => failures.isEmpty;
}

/// Audits the checked-in release configuration and, when available, the
/// resolved Android/iOS plugin metadata produced by `flutter pub get`.
PrivacyPlatformAuditReport auditPrivacyAndPlatform(
  Directory root, {
  bool scanResolvedPlugins = true,
}) {
  final audit = _Audit(root);

  audit
    ..auditIdentityAndVersion()
    ..auditDependencyPolicy()
    ..auditDartRuntimeBoundary()
    ..auditAndroidConfiguration()
    ..auditIosConfiguration()
    ..auditCiIntegration();
  if (scanResolvedPlugins) {
    audit.auditResolvedMobilePlugins();
  }

  return PrivacyPlatformAuditReport(
    checks: List<String>.unmodifiable(audit.checks),
    failures: List<String>.unmodifiable(audit.failures),
    warnings: List<String>.unmodifiable(audit.warnings),
  );
}

void main(List<String> arguments) {
  var rootPath = Directory.current.path;
  var scanResolvedPlugins = true;

  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    if (argument == '--no-resolved-plugins') {
      scanResolvedPlugins = false;
      continue;
    }
    if (argument == '--root' && index + 1 < arguments.length) {
      rootPath = arguments[index + 1];
      index += 1;
      continue;
    }
    if (argument.startsWith('--root=')) {
      rootPath = argument.substring('--root='.length);
      continue;
    }
    stderr.writeln(
      'Usage: dart run tool/audit_offline_boundary.dart '
      '[--root <repository>] [--no-resolved-plugins]',
    );
    exitCode = 64;
    return;
  }

  final root = Directory(rootPath).absolute;
  final report = auditPrivacyAndPlatform(
    root,
    scanResolvedPlugins: scanResolvedPlugins,
  );

  if (report.warnings.isNotEmpty) {
    stdout.writeln('Audit notes:');
    for (final warning in report.warnings) {
      stdout.writeln('  - $warning');
    }
  }

  if (!report.passed) {
    stderr.writeln('Privacy/platform source audit FAILED:');
    for (final failure in report.failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Privacy/platform source audit PASSED (${report.checks.length} checks): '
    'offline boundary, mobile capabilities, identity, targets, backup policy, '
    'and dependency policy match the release contract.',
  );
}

final class _Audit {
  _Audit(this.root);

  final Directory root;
  final List<String> checks = <String>[];
  final List<String> failures = <String>[];
  final List<String> warnings = <String>[];

  void auditIdentityAndVersion() {
    final pubspec = _requiredText('pubspec.yaml');
    if (pubspec == null) return;

    final version = ReleaseVersion.tryParsePubspec(pubspec);
    _expect(
      version != null,
      'pubspec release version is semantic and has a positive build number',
      'pubspec.yaml version must use semantic-name+positive-build-number',
    );
    if (version != null) {
      final runtimeVersion = _requiredText('lib/src/core/app_version.dart');
      if (runtimeVersion != null) {
        _expectContains(
          'lib/src/core/app_version.dart',
          runtimeVersion,
          "const String appVersionName = '${version.name}';",
          'runtime product version must match pubspec.yaml',
        );
        _expectContains(
          'lib/src/core/app_version.dart',
          runtimeVersion,
          'const int appBuildNumber = ${version.buildNumber};',
          'runtime build number must match pubspec.yaml',
        );
      }
    }
    _expectMatch(
      'pubspec.yaml',
      pubspec,
      RegExp(r'^publish_to:\s*["\x27]none["\x27]\s*$', multiLine: true),
      'package must not be accidentally publishable to pub.dev',
    );

    final androidStrings = _requiredText(
      'android/app/src/main/res/values/strings.xml',
    );
    if (androidStrings != null) {
      _expectMatch(
        'android/app/src/main/res/values/strings.xml',
        androidStrings,
        RegExp(r'<string\s+name="app_name"[^>]*>当归</string>'),
        'Android display name must be 当归',
      );
    }

    final iosInfo = _requiredText('ios/Runner/Info.plist');
    if (iosInfo != null) {
      _expectPlistString(
        'ios/Runner/Info.plist',
        iosInfo,
        'CFBundleDisplayName',
        '当归',
      );
      _expectPlistString(
        'ios/Runner/Info.plist',
        iosInfo,
        'CFBundleName',
        '当归',
      );
      _expectPlistString(
        'ios/Runner/Info.plist',
        iosInfo,
        'CFBundleIdentifier',
        r'$(PRODUCT_BUNDLE_IDENTIFIER)',
      );
      _expectPlistString(
        'ios/Runner/Info.plist',
        iosInfo,
        'CFBundleShortVersionString',
        r'$(FLUTTER_BUILD_NAME)',
      );
      _expectPlistString(
        'ios/Runner/Info.plist',
        iosInfo,
        'CFBundleVersion',
        r'$(FLUTTER_BUILD_NUMBER)',
      );
    }
  }

  void auditDependencyPolicy() {
    final pubspec = _requiredText('pubspec.yaml');
    final lock = _requiredText('pubspec.lock');
    if (pubspec == null || lock == null) return;

    final runtimeDependencies = _topLevelKeysInSection(
      pubspec,
      'dependencies',
      'dev_dependencies',
    );
    final unapproved = runtimeDependencies.difference(
      approvedRuntimeDependencies,
    );
    final missing = approvedRuntimeDependencies.difference(runtimeDependencies);
    _expect(
      unapproved.isEmpty && missing.isEmpty,
      'pubspec.yaml runtime dependencies are the reviewed allowlist',
      'pubspec.yaml: runtime dependency allowlist drift; '
          'unapproved=${_formatSet(unapproved)}, missing=${_formatSet(missing)}',
    );

    const forbiddenPackageFragments = <String>[
      'adjust',
      'admob',
      'amplitude',
      'appcenter',
      'appsflyer',
      'braze',
      'crashlytics',
      'facebook_app_events',
      'firebase',
      'google_mobile_ads',
      'mixpanel',
      'onesignal',
      'sentry',
      'segment_analytics',
      'supabase',
    ];
    final lockPackages = _parseLockPackages(lock);
    final forbiddenPackages = lockPackages.keys.where((name) {
      final lower = name.toLowerCase();
      return forbiddenPackageFragments.any(lower.contains);
    }).toList()..sort();
    _expect(
      forbiddenPackages.isEmpty,
      'pubspec.lock contains no cloud, ads, analytics, telemetry or push SDK',
      'pubspec.lock: forbidden package(s): ${forbiddenPackages.join(', ')}',
    );

    final malformedPackages = <String>[];
    for (final entry in lockPackages.entries) {
      final source = RegExp(
        r'^    source:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(entry.value)?.group(1);
      if (source != 'hosted' && source != 'sdk') {
        malformedPackages.add('${entry.key}: unsupported source $source');
        continue;
      }
      if (source == 'hosted') {
        final checksum = RegExp(
          r'^      sha256:\s*["\x27]?([0-9a-f]{64})["\x27]?\s*$',
          multiLine: true,
          caseSensitive: false,
        ).firstMatch(entry.value);
        if (checksum == null) {
          malformedPackages.add('${entry.key}: missing 64-character sha256');
        }
      }
    }
    _expect(
      lockPackages.isNotEmpty && malformedPackages.isEmpty,
      'every locked hosted dependency has a SHA-256 and no git/path source',
      'pubspec.lock: dependency integrity issue(s): '
          '${malformedPackages.join('; ')}',
    );

    _expectMatch(
      'pubspec.lock',
      lock,
      RegExp(
        r'^  dart:\s*["\x27]>=3\.13\.1 <4\.0\.0["\x27]\s*$',
        multiLine: true,
      ),
      'locked Dart SDK floor must remain 3.13.1',
    );
  }

  void auditDartRuntimeBoundary() {
    final lib = Directory(_path('lib'));
    if (!lib.existsSync()) {
      failures.add('required directory is missing: lib');
      return;
    }

    final patterns = <_ForbiddenPattern>[
      _ForbiddenPattern(
        RegExp(r'''import\s+['"]dart:(html|js|js_interop)['"]'''),
        'browser/network runtime import',
      ),
      _ForbiddenPattern(
        RegExp(
          r'''import\s+['"]package:(http|dio|chopper|graphql|grpc|'''
          r'''web_socket_channel|url_launcher|firebase_[^/]*)/''',
          caseSensitive: false,
        ),
        'network-capable Dart package import',
      ),
      _ForbiddenPattern(
        RegExp(
          r'\b(HttpClient|WebSocket|RawSocket|SecureSocket)\s*\(|'
          r'\b(Socket|WebSocket|RawSocket|SecureSocket)\.connect\s*\(|'
          r'\bInternetAddress\.lookup\s*\(',
        ),
        'direct Dart network API',
      ),
      _ForbiddenPattern(
        RegExp(r'''['"]https?://''', caseSensitive: false),
        'hard-coded remote URL in production Dart',
      ),
    ];

    final sourceFailures = _scanDirectory(lib, const <String>{
      '.dart',
    }, patterns);
    _expect(
      sourceFailures.isEmpty,
      'production Dart contains no network import, socket API or endpoint',
      sourceFailures.join('; '),
    );
  }

  void auditAndroidConfiguration() {
    final manifestPath = 'android/app/src/main/AndroidManifest.xml';
    final manifest = _requiredText(manifestPath);
    final debugManifest = _requiredText(
      'android/app/src/debug/AndroidManifest.xml',
    );
    final profileManifest = _requiredText(
      'android/app/src/profile/AndroidManifest.xml',
    );
    final gradle = _requiredText('android/app/build.gradle.kts');
    final settingsGradle = _requiredText('android/settings.gradle.kts');
    final notificationSource = _requiredText(
      'lib/src/services/notifications/notification_coordinator.dart',
    );

    if (manifest != null) {
      final permissions = _androidPermissions(manifest);
      _expect(
        _sameSet(permissions, expectedAndroidPermissions),
        'Android source manifest has only the reviewed local-alarm permissions',
        '$manifestPath: permissions are ${_formatSet(permissions)}; expected '
            '${_formatSet(expectedAndroidPermissions)}',
      );
      _expectContains(
        manifestPath,
        manifest,
        'android:allowBackup="false"',
        'Android OS cloud backup must be disabled',
      );
      _expectContains(
        manifestPath,
        manifest,
        'android:usesCleartextTraffic="false"',
        'Android cleartext traffic must be disabled defensively',
      );
      _expectContains(
        manifestPath,
        manifest,
        'android:dataExtractionRules="@xml/data_extraction_rules"',
        'Android 12+ extraction exclusions must be wired',
      );
      _expectContains(
        manifestPath,
        manifest,
        'android:fullBackupContent="@xml/backup_rules"',
        'legacy Android backup exclusions must be wired',
      );
      _expectContains(
        manifestPath,
        manifest,
        'android:screenOrientation="portrait"',
        'Android activity must be portrait-only',
      );
      for (final receiver in <String>[
        'ScheduledNotificationReceiver',
        'ScheduledNotificationBootReceiver',
        'ActionBroadcastReceiver',
      ]) {
        _expectMatch(
          manifestPath,
          manifest,
          RegExp(
            '<receiver(?=[^>]*$receiver)(?=[^>]*android:exported="false")[^>]*>',
            dotAll: true,
          ),
          '$receiver must not be exported',
        );
      }
      _expectNoMatch(
        manifestPath,
        manifest,
        RegExp(
          r'android\.permission\.(INTERNET|USE_EXACT_ALARM|'
          r'ACCESS_NETWORK_STATE|'
          r'AD_ID|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|'
          r'READ_MEDIA_|ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|'
          r'CAMERA|RECORD_AUDIO)',
        ),
        'forbidden Android permission',
      );
    }

    for (final entry in <String, String?>{
      'android/app/src/debug/AndroidManifest.xml': debugManifest,
      'android/app/src/profile/AndroidManifest.xml': profileManifest,
    }.entries) {
      if (entry.value == null) continue;
      _expect(
        _androidPermissions(entry.value!).isEmpty &&
            !entry.value!.contains('<application'),
        '${entry.key} adds no debug/profile capability',
        '${entry.key}: debug/profile variants must not add permissions or an '
            'application override',
      );
    }

    if (gradle != null) {
      _expectGradleValue(
        'android/app/build.gradle.kts',
        gradle,
        'namespace',
        '"$expectedApplicationId"',
      );
      _expectGradleValue(
        'android/app/build.gradle.kts',
        gradle,
        'applicationId',
        '"$expectedApplicationId"',
      );
      _expectGradleValue(
        'android/app/build.gradle.kts',
        gradle,
        'minSdk',
        '$expectedAndroidMinSdk',
      );
      _expectGradleValue(
        'android/app/build.gradle.kts',
        gradle,
        'targetSdk',
        '$expectedAndroidTargetSdk',
      );
      _expectGradleValue(
        'android/app/build.gradle.kts',
        gradle,
        'compileSdk',
        '$expectedAndroidCompileSdk',
      );
      _expectMatch(
        'android/app/build.gradle.kts',
        gradle,
        RegExp(
          r'(sourceCompatibility|targetCompatibility)\s*=\s*JavaVersion\.VERSION_17',
        ),
        'Android Java bytecode target must remain 17',
      );
      _expectNoMatch(
        'android/app/build.gradle.kts',
        gradle,
        RegExp(
          r'(firebase|google-services|crashlytics|analytics|sentry|amplitude|'
          r'mixpanel|appcenter|google_mobile_ads)',
          caseSensitive: false,
        ),
        'cloud/analytics/ads Gradle SDK or plugin',
      );
    }

    if (settingsGradle != null) {
      _expectMatch(
        'android/settings.gradle.kts',
        settingsGradle,
        RegExp(
          r'id\("com\.android\.application"\)\s+version\s+"\d+\.\d+\.\d+"',
        ),
        'Android Gradle plugin must be version-pinned',
      );
      _expectMatch(
        'android/settings.gradle.kts',
        settingsGradle,
        RegExp(
          r'id\("org\.jetbrains\.kotlin\.android"\)\s+version\s+"\d+\.\d+\.\d+"',
        ),
        'Kotlin Gradle plugin must be version-pinned',
      );
    }

    if (notificationSource != null) {
      _expectContains(
        'lib/src/services/notifications/notification_coordinator.dart',
        notificationSource,
        'AndroidScheduleMode.exactAllowWhileIdle',
        'Android reminders must use exact allow-while-idle when access exists',
      );
      _expectContains(
        'lib/src/services/notifications/notification_coordinator.dart',
        notificationSource,
        'AndroidScheduleMode.inexactAllowWhileIdle',
        'Android reminders must retain an inexact permission-denied fallback',
      );
      _expectContains(
        'lib/src/services/notifications/notification_coordinator.dart',
        notificationSource,
        'requestExactAlarmsPermission',
        'Android exact-alarm special access must be requested explicitly',
      );
      _expectNoMatch(
        'lib/src/services/notifications/notification_coordinator.dart',
        notificationSource,
        RegExp(
          r'AndroidScheduleMode\.(exact|alarmClock)\b|'
          r'fullScreenIntent\s*:\s*true',
        ),
        'alarm-clock or full-screen notification API',
      );
    }

    _auditAndroidBackupRules();

    final androidTree = Directory(_path('android/app/src/main'));
    if (androidTree.existsSync()) {
      final nativeFailures = _scanDirectory(
        androidTree,
        const <String>{'.kt', '.java'},
        <_ForbiddenPattern>[
          _ForbiddenPattern(
            RegExp(
              r'\b(java\.net\.|HttpURLConnection|OkHttpClient|Retrofit|'
              r'WebSocket|Socket\s*\()',
              caseSensitive: false,
            ),
            'Android native network API',
          ),
        ],
      );
      _expect(
        nativeFailures.isEmpty,
        'app Android native source contains no network API',
        nativeFailures.join('; '),
      );
    }
  }

  void _auditAndroidBackupRules() {
    final legacy = _requiredText(
      'android/app/src/main/res/xml/backup_rules.xml',
    );
    final extraction = _requiredText(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );
    const domains = <String>{
      'root',
      'file',
      'database',
      'sharedpref',
      'external',
    };

    if (legacy != null) {
      final excluded = _excludedBackupDomains(legacy);
      _expect(
        domains.difference(excluded).isEmpty,
        'legacy Android backup excludes every app data domain',
        'android/app/src/main/res/xml/backup_rules.xml: missing exclusions '
            '${_formatSet(domains.difference(excluded))}',
      );
    }
    if (extraction != null) {
      _expectContains(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
        extraction,
        '<cloud-backup>',
        'Android cloud-backup rules must be explicit',
      );
      _expectContains(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
        extraction,
        '<device-transfer>',
        'Android device-transfer rules must be explicit',
      );
      final excluded = _excludedBackupDomains(extraction);
      for (final domain in domains) {
        final count = RegExp(
          '<exclude\\s+domain="${RegExp.escape(domain)}"\\s+path="\\."\\s*/>',
        ).allMatches(extraction).length;
        _expect(
          count == 2,
          'Android 12+ excludes $domain from cloud backup and device transfer',
          'android/app/src/main/res/xml/data_extraction_rules.xml: expected two '
              '$domain exclusions, found $count',
        );
      }
      _expect(
        domains.difference(excluded).isEmpty,
        'Android 12+ extraction rules cover all app data domains',
        'android/app/src/main/res/xml/data_extraction_rules.xml: missing '
            '${_formatSet(domains.difference(excluded))}',
      );
    }
  }

  void auditIosConfiguration() {
    final infoPath = 'ios/Runner/Info.plist';
    final info = _requiredText(infoPath);
    final projectPath = 'ios/Runner.xcodeproj/project.pbxproj';
    final project = _requiredText(projectPath);
    final frameworkInfo = _requiredText('ios/Flutter/AppFrameworkInfo.plist');
    final appDelegate = _requiredText('ios/Runner/AppDelegate.swift');
    final dataProtection = _requiredText(
      'ios/Runner/DangguiDataProtection.swift',
    );
    final dartDataProtection = _requiredText(
      'lib/src/data/data_protection.dart',
    );
    final databaseProvider = _requiredText(
      'lib/src/data/database_provider.dart',
    );
    final appSource = _requiredText('lib/src/app.dart');
    final secureStorageSource = _requiredText(
      'lib/src/services/backup/automatic_backup_coordinator.dart',
    );

    if (info != null) {
      for (final locale in <String>['zh-Hans', 'en', 'ja', 'ru']) {
        _expectMatch(
          infoPath,
          info,
          RegExp('<string>${RegExp.escape(locale)}</string>'),
          'iOS Info.plist must declare $locale localization',
        );
      }
      final portraitCount = RegExp(
        r'<string>UIInterfaceOrientationPortrait</string>',
      ).allMatches(info).length;
      _expect(
        portraitCount == 2,
        'iPhone and iPad are both portrait-only',
        '$infoPath: expected two portrait orientation declarations, found '
            '$portraitCount',
      );
      _expectNoMatch(
        infoPath,
        info,
        RegExp(
          r'<key>(UIBackgroundModes|NSAppTransportSecurity|'
          r'NSUserTrackingUsageDescription|NSLocalNetworkUsageDescription|'
          r'NSBonjourServices)</key>|<string>remote-notification</string>',
        ),
        'iOS background networking, tracking or local-network capability',
      );
      _expectContains(
        infoPath,
        info,
        '<key>NSAlarmKitUsageDescription</key>',
        'iOS 26 AlarmKit authorization must explain its purpose',
      );
    }

    for (final locale in <String>['zh-Hans', 'en', 'ja', 'ru']) {
      final localizedInfoPath = 'ios/Runner/$locale.lproj/InfoPlist.strings';
      final localizedInfo = _requiredText(localizedInfoPath);
      if (localizedInfo != null) {
        _expectMatch(
          localizedInfoPath,
          localizedInfo,
          RegExp(
            r'^"NSAlarmKitUsageDescription"\s*=\s*"[^"]+";\s*$',
            multiLine: true,
          ),
          'AlarmKit permission purpose must be localized for $locale',
        );
      }
    }

    if (project != null) {
      final deploymentTargets = RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);',
      ).allMatches(project).map((match) => match.group(1)!.trim()).toList();
      _expect(
        deploymentTargets.length >= 3 &&
            deploymentTargets.every(
              (target) => target == expectedIosDeploymentTarget,
            ),
        'all iOS project build configurations target iOS 15.0',
        '$projectPath: deployment targets are ${deploymentTargets.join(', ')}',
      );

      final appBundleIds = RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER\\s*=\\s*${RegExp.escape(expectedApplicationId)};',
      ).allMatches(project).length;
      _expect(
        appBundleIds == 3,
        'all iOS app build configurations use $expectedApplicationId',
        '$projectPath: expected three app bundle-ID assignments, found '
            '$appBundleIds',
      );

      final entitlementAssignments = RegExp(
        r'CODE_SIGN_ENTITLEMENTS\s*=\s*Runner/Runner\.entitlements;',
      ).allMatches(project).length;
      _expect(
        entitlementAssignments == 3,
        'all iOS app build configurations use the reviewed entitlement file',
        '$projectPath: expected three Runner entitlement assignments, found '
            '$entitlementAssignments',
      );
      _expectContains(
        projectPath,
        project,
        'InfoPlist.strings in Resources',
        'localized AlarmKit permission text must be copied into the iOS app',
      );
      _expectNoMatch(
        projectPath,
        project,
        RegExp(
          r'SystemCapabilities|aps-environment|BackgroundModes|Push',
          caseSensitive: false,
        ),
        'iOS Xcode push/background/network capability',
      );
    }

    if (frameworkInfo != null) {
      _expectPlistString(
        'ios/Flutter/AppFrameworkInfo.plist',
        frameworkInfo,
        'MinimumOSVersion',
        expectedIosDeploymentTarget,
      );
    }

    if (appDelegate != null) {
      _expectContains(
        'ios/Runner/AppDelegate.swift',
        appDelegate,
        'UNUserNotificationCenter.current().delegate',
        'iOS local-notification delegate must be configured',
      );
      _expectNoMatch(
        'ios/Runner/AppDelegate.swift',
        appDelegate,
        RegExp(
          r'registerForRemoteNotifications|didRegisterForRemoteNotifications|'
          r'didFailToRegisterForRemoteNotifications',
        ),
        'iOS remote-notification registration',
      );
      for (final marker in <String>[
        'excludeDangguiDataFromSystemBackups()',
        'for: .applicationSupportDirectory',
        'appendingPathComponent("danggui", isDirectory: true)',
        'DangguiDataProtection.apply(to: dangguiURL',
        'com.danggui.memo/data_protection',
        'getDataProtectionStatus',
        'retryDataProtection',
      ]) {
        _expectContains(
          'ios/Runner/AppDelegate.swift',
          appDelegate,
          marker,
          'iOS must attempt to exclude Application Support/danggui from '
              'system backups',
        );
      }
    }

    if (dataProtection != null) {
      for (final marker in <String>[
        'FileProtectionType.completeUntilFirstUserAuthentication',
        'rootValues.isExcludedFromBackup = true',
        'readBackupExclusion(rootURL) == true',
        'fileManager.setAttributes(',
        '.protectionKey: protectionType',
        '.isSymbolicLinkKey',
        'recordUnavailable(errorCode: "policy-pending")',
      ]) {
        _expectContains(
          'ios/Runner/DangguiDataProtection.swift',
          dataProtection,
          marker,
          'iOS private data must use explicit file protection and remain '
              'excluded from system backups',
        );
      }
    }

    if (dartDataProtection != null) {
      for (final marker in <String>[
        'DataProtectionUnavailableException',
        'getDataProtectionStatus',
        'retryDataProtection',
        "DataProtectionStatus.unavailable('channel-error')",
        "DataProtectionStatus.unavailable('invalid-response')",
      ]) {
        _expectContains(
          'lib/src/data/data_protection.dart',
          dartDataProtection,
          marker,
          'Dart must fail closed and expose only stable iOS data-protection '
              'status codes',
        );
      }
    }

    if (databaseProvider != null) {
      for (final marker in <String>[
        'dataProtectionPlatformProvider',
        '.ensureAvailable()',
        'throw DataProtectionUnavailableException(',
      ]) {
        _expectContains(
          'lib/src/data/database_provider.dart',
          databaseProvider,
          marker,
          'the SQLite path must remain unavailable until the iOS private-data '
              'policy is confirmed',
        );
      }
    }

    if (appSource != null) {
      for (final marker in <String>[
        '_retryDataProtectionIfNeeded()',
        'final retried = await platform.retry()',
        'ref.invalidate(databaseFileProvider)',
      ]) {
        _expectContains(
          'lib/src/app.dart',
          appSource,
          marker,
          'foreground resume must retry and rebuild a previously unavailable '
              'iOS data path',
        );
      }
    }

    if (secureStorageSource != null) {
      _expectContains(
        'lib/src/services/backup/automatic_backup_coordinator.dart',
        secureStorageSource,
        'accessibility: KeychainAccessibility.first_unlock_this_device',
        'iOS backup passphrase must use a this-device-only Keychain class',
      );
      _expectContains(
        'lib/src/services/backup/automatic_backup_coordinator.dart',
        secureStorageSource,
        'synchronizable: false',
        'iOS backup passphrase must not synchronize through iCloud Keychain',
      );
      _expectNoMatch(
        'lib/src/services/backup/automatic_backup_coordinator.dart',
        secureStorageSource,
        RegExp(r'synchronizable\s*:\s*true'),
        'iCloud-synchronizable secure-storage option',
      );
    }

    final entitlements = _filesBelow(Directory(_path('ios')), const <String>{
      '.entitlements',
    });
    final entitlementPaths = entitlements.map(_relative).toList()..sort();
    _expect(
      entitlementPaths.length == 1 &&
          entitlementPaths.single == 'ios/Runner/Runner.entitlements',
      'iOS project declares only the reviewed Time Sensitive entitlement file',
      'ios: entitlement files require review: ${entitlementPaths.join(', ')}',
    );
    final runnerEntitlements = _requiredText('ios/Runner/Runner.entitlements');
    if (runnerEntitlements != null) {
      _expectContains(
        'ios/Runner/Runner.entitlements',
        runnerEntitlements,
        '<key>com.apple.developer.usernotifications.time-sensitive</key>',
        'iOS fallback reminders declare Time Sensitive authorization',
      );
      _expectNoMatch(
        'ios/Runner/Runner.entitlements',
        runnerEntitlements,
        RegExp(
          r'aps-environment|remote-notification|network|icloud|healthkit',
          caseSensitive: false,
        ),
        'iOS unreviewed remote, network, cloud, or health entitlement',
      );
    }

    final iosNativeFailures = _scanDirectory(
      Directory(_path('ios/Runner')),
      const <String>{'.swift', '.m', '.mm', '.h'},
      <_ForbiddenPattern>[
        _ForbiddenPattern(
          RegExp(
            r'\b(URLSession|NWConnection|CFHTTP|WKWebView|'
            r'registerForRemoteNotifications)\b',
          ),
          'iOS native network or remote-notification API',
        ),
      ],
    );
    _expect(
      iosNativeFailures.isEmpty,
      'app iOS native source contains no network or remote-push API',
      iosNativeFailures.join('; '),
    );

    final podfile = File(_path('ios/Podfile'));
    final podLock = File(_path('ios/Podfile.lock'));
    if (!podfile.existsSync() && !podLock.existsSync()) {
      checks.add('iOS has no checked-in CocoaPods dependency graph');
    } else {
      final podText = <String>[
        if (podfile.existsSync()) podfile.readAsStringSync(),
        if (podLock.existsSync()) podLock.readAsStringSync(),
      ].join('\n');
      _expectNoMatch(
        'ios/Podfile / ios/Podfile.lock',
        podText,
        RegExp(
          r'(Firebase|GoogleAnalytics|Sentry|Amplitude|Mixpanel|AppCenter|'
          r'Google-Mobile-Ads|OneSignal)',
          caseSensitive: false,
        ),
        'forbidden CocoaPods SDK',
      );
    }
  }

  void auditResolvedMobilePlugins() {
    final metadata = File(_path('.flutter-plugins-dependencies'));
    if (!metadata.existsSync()) {
      warnings.add(
        'resolved-plugin audit skipped because .flutter-plugins-dependencies '
        'is absent; run flutter pub get before the release gate',
      );
      return;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(metadata.readAsStringSync());
    } on FormatException catch (error) {
      failures.add('.flutter-plugins-dependencies: invalid JSON: $error');
      return;
    }
    if (decoded is! Map<String, Object?>) {
      failures.add('.flutter-plugins-dependencies: root must be a JSON object');
      return;
    }
    final plugins = decoded['plugins'];
    if (plugins is! Map<String, Object?>) {
      failures.add('.flutter-plugins-dependencies: plugins map is missing');
      return;
    }

    final androidPlugins = _pluginEntries(plugins['android']);
    final iosPlugins = _pluginEntries(plugins['ios']);
    _auditResolvedAndroidPlugins(androidPlugins);
    _auditResolvedIosPlugins(iosPlugins);
  }

  void auditCiIntegration() {
    const workflowPath = '.github/workflows/mobile-ci.yml';
    final workflow = _requiredText(workflowPath);
    if (workflow == null) return;

    for (final command in <String>[
      'dart run tool/audit_offline_boundary.dart',
      'flutter analyze --fatal-infos',
      'flutter test --reporter expanded',
      'bash tool/verify_android_artifacts.sh --self-test',
      'bash tool/assemble_release_assets.sh --self-test',
      'bash tool/render_release_notes.sh --self-test',
      'bash integration_test/run_android_emulator_smoke_self_test.sh',
      'bash integration_test/android_emulator_infrastructure_self_test.sh',
      'bash tool/verify_android_artifacts.sh',
      'bash tool/build_ios_unsigned.sh',
      'bash tool/build_ios_source_zip.sh',
      'bash tool/run_ios_simulator_tests.sh',
      'bash tool/assemble_release_assets.sh',
      'bash tool/render_release_notes.sh',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        command,
        "CI must run ${command.split(' ').first} release gate: $command",
      );
    }

    for (final scriptPath in <String>[
      'tool/build_android_release.ps1',
      'tool/verify_android_artifacts.ps1',
      'tool/verify_android_artifacts.sh',
      'tool/build_ios_unsigned.sh',
      'tool/build_ios_source_zip.sh',
    ]) {
      _expectContains(
        scriptPath,
        _requiredText(scriptPath) ?? '',
        'pubspec.yaml',
        'release scripts must derive platform versions from pubspec.yaml',
      );
    }

    final iosSourceArchive =
        _requiredText('tool/build_ios_source_zip.sh') ?? '';
    for (final archiveContract in <String>[
      'git archive',
      'danggui-ios-source-v',
      'pubspec.lock',
      'required_archive_entries',
      'git ls-tree -r --name-only HEAD',
      'archive_manifest',
      '.github/workflows/mobile-ci.yml',
      'android/app/build.gradle.kts',
      'docs/architecture/ios-source-build.md',
      'integration_test/app_cold_start_test.dart',
      'test/platform/privacy_platform_config_test.dart',
      r'\.dart_tool',
      'keystore\\.properties',
      'p12',
      'mobileprovision',
      'PRIVATE KEY',
      'google-services\\.json',
    ]) {
      _expectContains(
        'tool/build_ios_source_zip.sh',
        iosSourceArchive,
        archiveContract,
        'deterministic iOS source delivery must be complete and secret-free',
      );
    }

    for (final releaseAssetContract in <String>[
      'gh release delete-asset',
      'gh release upload "\${GITHUB_REF_NAME}" "\${assets[@]}" --clobber',
      'expected_assets',
      'published_assets',
      'existing_is_prerelease',
      'already-promoted stable release',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        releaseAssetContract,
        'pre-release reruns must replace and verify the exact asset set',
      );
    }

    const releaseAssemblerPath = 'tool/assemble_release_assets.sh';
    final releaseAssembler = _requiredText(releaseAssemblerPath) ?? '';
    const releaseVerifierPath = 'tool/verify_release_assets.sh';
    final releaseVerifier = _requiredText(releaseVerifierPath) ?? '';
    const releaseNotesRendererPath = 'tool/render_release_notes.sh';
    final releaseNotesRenderer = _requiredText(releaseNotesRendererPath) ?? '';
    for (final publicAsset in <String>[
      'danggui-android-universal-release.apk',
      'danggui-ios-source-\${tag}.zip',
      'danggui-developer-assets-\${tag}.zip',
      'SHA256SUMS',
    ]) {
      _expectContains(
        releaseVerifierPath,
        releaseVerifier,
        publicAsset,
        'public releases must enforce the exact four-file allowlist',
      );
    }
    for (final privateDeveloperAsset in <String>[
      'danggui-android-armeabi-v7a-release.apk',
      'danggui-android-arm64-v8a-release.apk',
      'danggui-android-x86_64-release.apk',
      'danggui-android-release.aab',
      'danggui-ios-unsigned.app.zip',
      'SIGNING_CERTIFICATE.txt',
      'SIGNING_CERTIFICATE_SHA256.txt',
      'PLATFORM_AUDIT.txt',
      'SOURCE_ARCHIVE_CONTENTS.txt',
    ]) {
      _expectContains(
        releaseAssemblerPath,
        releaseAssembler,
        privateDeveloperAsset,
        'advanced packages and evidence must live in the developer archive',
      );
    }
    for (final exactContract in <String>[
      'public assets differ from the exact allowlist',
      'developer archive differs from the exact internal allowlist',
      'public SHA256SUMS does not cover exactly the public payloads',
      'developer SHA256SUMS does not cover every internal payload exactly once',
    ]) {
      _expectContains(
        releaseVerifierPath,
        releaseVerifier,
        exactContract,
        'release verification must fail closed on allowlist or checksum drift',
      );
    }
    for (final releaseEvidenceContract in <String>[
      'EXPECTED_SOURCE_COMMIT',
      'SOURCE_COMMIT.txt does not match the protected tag commit',
      'ui_test_count=2',
      'testTaskReminderDeleteAndRestoreContract',
      'testBackupRestoreRebuildsReminderContract',
      'system_delivery=device-unverified',
      'notification_gateway=in-process-contract-double',
    ]) {
      _expectContains(
        releaseEvidenceContract == 'EXPECTED_SOURCE_COMMIT'
            ? workflowPath
            : releaseVerifierPath,
        releaseEvidenceContract == 'EXPECTED_SOURCE_COMMIT'
            ? workflow
            : releaseVerifier,
        releaseEvidenceContract,
        'release evidence must match the tag and exact two UI contracts',
      );
    }

    const simulatorScriptPath = 'tool/run_ios_simulator_tests.sh';
    final simulatorScript = _requiredText(simulatorScriptPath) ?? '';
    for (final simulatorContract in <String>[
      'xcrun simctl create',
      'xcrun simctl delete',
      '-only-testing:RunnerTests',
      '-only-testing:RunnerUITests',
      'xcresulttool get test-results summary',
      'total_test_count',
      'ui_test_count=2',
      'runner_image_version=',
      'runner_arch=',
      'runtime_build=',
      'system_delivery=device-unverified',
    ]) {
      _expectContains(
        simulatorScriptPath,
        simulatorScript,
        simulatorContract,
        'iOS Simulator CI must be disposable, explicit, and fail closed',
      );
    }
    _expect(
      !simulatorScript.contains('simctl erase') &&
          !simulatorScript.contains('mapfile'),
      'iOS simulator runner neither erases existing devices nor requires Bash 4',
      '$simulatorScriptPath must create/delete only its disposable device and '
          'remain compatible with macOS Bash 3',
    );

    const deepAuditPath = '.github/workflows/ios-deep-audit.yml';
    final deepAudit = _requiredText(deepAuditPath) ?? '';
    for (final fixedMacContract in <String>[
      'runs-on: macos-15',
      'runs-on: macos-26',
      '/Applications/Xcode_16.4.app/Contents/Developer',
      '/Applications/Xcode_26.6.app/Contents/Developer',
      'runtime: "18.5"',
      'runtime: "26.5"',
    ]) {
      final source = fixedMacContract.startsWith('runs-on:')
          ? '$workflow\n$deepAudit'
          : deepAudit;
      _expectContains(
        fixedMacContract.startsWith('runs-on:')
            ? 'iOS workflow contracts'
            : deepAuditPath,
        source,
        fixedMacContract,
        'free iOS CI must pin standard runner, Xcode, and runtime versions',
      );
    }
    final combinedWorkflows = '$workflow\n$deepAudit';
    for (final protectedIosContext in <String>[
      'name: Unsigned iOS source build',
      'needs: [ios-fallback, ios-unsigned]',
      'needs: [android-linux, android-emulator-smoke, ios-unsigned-contract]',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        protectedIosContext,
        'protected-main iOS context must aggregate both fixed iOS contracts',
      );
    }
    _expect(
      !combinedWorkflows.contains('macos-latest') &&
          !RegExp(r'runs-on:\s*[^\n]*(large|xlarge)')
              .hasMatch(combinedWorkflows),
      'iOS CI uses no floating or paid large macOS runner',
      'mobile and deep-audit workflows must use fixed standard runners',
    );
    for (final match in RegExp(
      r'^\s*uses:\s*[^@\s]+@([^\s#]+)',
      multiLine: true,
    ).allMatches(combinedWorkflows)) {
      final reference = match.group(1) ?? '';
      _expect(
        RegExp(r'^[0-9a-f]{40}$').hasMatch(reference),
        'GitHub Action dependency is pinned to an immutable commit',
        'workflow action reference is mutable: $reference',
      );
    }
    _expect(
      !workflow.contains('cp staging/android/*.apk release/') &&
          !workflow.contains('cp staging/android/*.aab release/') &&
          !workflow.contains(
            'cp staging/android/SIGNING_CERTIFICATE_SHA256.txt release/',
          ) &&
          !workflow.contains(
            'cp staging/ios/danggui-ios-unsigned.app.zip release/',
          ),
      'workflow does not expose developer-only evidence as top-level assets',
      '$workflowPath must publish through the exact release assembly script',
    );
    for (final notesContract in <String>[
      '## 亮点 / Highlights',
      '## 下载 / Downloads',
      '## 校验 / Verify',
      '## 已知限制 / Known limits',
      '## 完整变更 / Full comparison',
      '{{ANDROID_SIGNING_CERT_SHA256}}',
    ]) {
      _expectContains(
        releaseNotesRendererPath,
        releaseNotesRenderer,
        notesContract,
        'release notes must use the bilingual, version-specific contract',
      );
    }
    final releaseVersion = ReleaseVersion.tryParsePubspec(
      _requiredText('pubspec.yaml') ?? '',
    );
    if (releaseVersion != null) {
      final releaseNotesPath = 'docs/release/notes/v${releaseVersion.name}.md';
      final releaseNotes = _requiredText(releaseNotesPath) ?? '';
      for (final notesContract in <String>[
        '# 当归 v${releaseVersion.name} 预发布 / '
            'Danggui v${releaseVersion.name} Pre-release',
        '## 亮点 / Highlights',
        '## 下载 / Downloads',
        '## 校验 / Verify',
        '## 已知限制 / Known limits',
        '## 完整变更 / Full comparison',
        '{{ANDROID_SIGNING_CERT_SHA256}}',
        'https://github.com/hujizhou35-cmd/danggui-app/compare/',
      ]) {
        _expectContains(
          releaseNotesPath,
          releaseNotes,
          notesContract,
          'the current version must have complete bilingual release notes',
        );
      }
    }

    const smokePath = 'integration_test/run_android_emulator_smoke.sh';
    final smoke = _requiredText(smokePath);
    if (smoke != null) {
      _expectContains(
        smokePath,
        smoke,
        'bash integration_test/run_android_release_acceptance.sh',
        'successful device smoke must continue into release acceptance',
      );
      _expectContains(
        smokePath,
        smoke,
        'bash integration_test/run_android_release_binary_smoke.sh',
        'instrumented acceptance must continue into exact release-binary smoke',
      );
      final interactionAcceptanceIndex = smoke.indexOf(
        'bash integration_test/run_android_release_acceptance.sh',
      );
      final releaseBinarySmokeIndex = smoke.indexOf(
        'bash integration_test/run_android_release_binary_smoke.sh',
      );
      _expect(
        interactionAcceptanceIndex >= 0 &&
            releaseBinarySmokeIndex > interactionAcceptanceIndex &&
            smoke.contains(r'${DANGGUI_RELEASE_APK:?'),
        'exact release binary runs only after instrumented interaction acceptance',
        '$smokePath must pass the downloaded universal APK to the host-only '
            'release-binary smoke after the debug interaction phase succeeds',
      );
      _expectContains(
        smokePath,
        smoke,
        'show_ime_with_hard_keyboard',
        'device editor acceptance must expose a real soft-keyboard inset',
      );
      _expectContains(
        smokePath,
        smoke,
        r'${ANDROID_SERIAL:-emulator-5554}',
        'emulator smoke must honor the action-selected device serial',
      );
      final healthGateIndex = smoke.indexOf(
        '\ndanggui_run_system_component_health_gate\n',
      );
      final firstFlutterTestIndex = smoke.indexOf(
        '\nrun_flutter_test first-attempt\n',
      );
      _expect(
        healthGateIndex >= 0 && firstFlutterTestIndex > healthGateIndex,
        'system-component health is established before any Flutter device run',
        '$smokePath must run the health gate before its first Flutter build, '
            'install, or launch',
      );
      _expectContains(
        smokePath,
        smoke,
        'bounded_diagnostic_adb()',
        'smoke failure diagnostics use a bounded ADB helper',
      );
      final diagnosticStart = smoke.indexOf('capture_smoke_failure_evidence()');
      final diagnosticEnd = smoke.indexOf(
        '\nrun_flutter_test()',
        diagnosticStart < 0 ? 0 : diagnosticStart,
      );
      final diagnosticBlock =
          diagnosticStart >= 0 && diagnosticEnd > diagnosticStart
          ? smoke.substring(diagnosticStart, diagnosticEnd)
          : '';
      _expect(
        diagnosticBlock.isNotEmpty &&
            !RegExp(
              r'^\s*adb(\s|$)',
              multiLine: true,
            ).hasMatch(diagnosticBlock),
        'every post-preflight ADB diagnostic is independently bounded',
        '$smokePath must not let an unbounded diagnostic mask exit status 75',
      );
    }

    const releaseBinarySmokePath =
        'integration_test/run_android_release_binary_smoke.sh';
    final releaseBinarySmoke = _requiredText(releaseBinarySmokePath);
    if (releaseBinarySmoke != null) {
      for (final contract in <String>[
        'tool/verify_android_artifacts.sh',
        'DANGGUI_RELEASE_ARTIFACT_SHA',
        'DANGGUI_RELEASE_APK_SHA256',
        'changed after the upstream artifact checksum gate',
        'DANGGUI_RELEASE_SIGNING_MODE',
        r'adb -s "${device_serial}"',
        'install --no-streaming',
        'manifest application-id',
        'manifest version-name',
        'manifest version-code',
        'manifest min-sdk',
        'manifest target-sdk',
        'manifest debuggable',
        'ro.build.version.sdk',
        'shell am start -W -S',
        'shell uiautomator dump',
        'screen-specific marker',
        'release-binary-crash-scan.json',
        'host-adb-and-uiautomator-no-flutter-instrumentation',
        'release-binary-smoke-complete',
      ]) {
        _expectContains(
          releaseBinarySmokePath,
          releaseBinarySmoke,
          contract,
          'release artifact smoke must remain exact, host-driven, and auditable',
        );
      }
      _expect(
        !releaseBinarySmoke.contains('flutter test') &&
            !releaseBinarySmoke.contains('adb install -r'),
        'release-binary smoke has no instrumentation or debug overlay upgrade',
        '$releaseBinarySmokePath must uninstall the interaction package and '
            'install the downloaded universal release-mode APK as a clean app',
      );
    }

    final coldStartAcceptance =
        _requiredText('integration_test/app_cold_start_test.dart') ?? '';
    for (final keyboardContract in <String>[
      'SystemChannels.textInput',
      'view.viewInsets.bottom',
      'usableBottom',
      'task-creation-more-settings',
      'past editor durable save',
    ]) {
      _expectContains(
        'integration_test/app_cold_start_test.dart',
        coldStartAcceptance,
        keyboardContract,
        'device cold-start acceptance must exercise real editor IME geometry',
      );
    }

    final notificationCallbackAcceptance =
        _requiredText('integration_test/release_acceptance_verify_test.dart') ??
        '';
    for (final callbackContract in <String>[
      'handleNotificationAction',
      '<int>[10, 30, 60]',
      'nativeNotificationGateway',
      'snooze-callback.json',
    ]) {
      _expectContains(
        'integration_test/release_acceptance_verify_test.dart',
        notificationCallbackAcceptance,
        callbackContract,
        'device acceptance must exercise all production snooze callbacks',
      );
    }

    const acceptancePath = 'integration_test/run_android_release_acceptance.sh';
    final acceptance = _requiredText(acceptancePath);
    if (acceptance != null) {
      _expectContains(
        acceptancePath,
        acceptance,
        'notification-click.json',
        'device acceptance must prove a real notification content click',
      );
      _expectContains(
        acceptancePath,
        acceptance,
        'exactTitleNodeCount',
        'notification clicks must resolve exact SystemUI title-node bounds',
      );
      _expectContains(
        acceptancePath,
        acceptance,
        'snooze-callback.json',
        'device acceptance must retain production 10/30/60 callback evidence',
      );
      _expectContains(
        acceptancePath,
        acceptance,
        'alarm-after-snooze-callback.txt',
        'device acceptance must prove the final callback reached AlarmManager',
      );
      final noUninstallCount = '--no-uninstall'.allMatches(acceptance).length;
      _expect(
        noUninstallCount >= 3,
        'release acceptance keeps seed and verify packages installed',
        '$acceptancePath must pass --no-uninstall to every seed and verify '
            'integration-test path',
      );
      _expect(
        !acceptance.contains('install_apk_logged initial-install'),
        'release acceptance seed performs the only first app installation',
        '$acceptancePath must not preinstall immediately before Flutter seed',
      );
      _expectContains(
        acceptancePath,
        acceptance,
        r'\"packageAbsentBeforeSeed\":true',
        'release evidence records the fresh-package boundary before seed',
      );
      _expect(
        !RegExp(
              r'^danggui_run_system_component_health_gate\s*$',
              multiLine: true,
            ).hasMatch(acceptance) &&
            acceptance.contains('system-component-health.json') &&
            acceptance.contains('.stableSamples == 2'),
        'release acceptance validates the smoke preflight for this attempt',
        '$acceptancePath must validate, not rerun or repair, the health gate',
      );
      _expectContains(
        acceptancePath,
        acceptance,
        'danggui_classify_permission_flow_anr',
        'permission-flow ANR classification must use the strict context gate',
      );
      for (final processContract in <String>[
        'setsid bash -c',
        'timeout --foreground',
        'danggui_terminate_process_group',
        'danggui_wait_for_seed_product_failure',
        'seed-natural-completion.json',
        'seed-log-quiescence.json',
        r'${ANDROID_SERIAL:-emulator-5554}',
      ]) {
        _expectContains(
          acceptancePath,
          acceptance,
          processContract,
          'permission seed must be isolated and fully quiesced before retry',
        );
      }
      _expect(
        !acceptance.contains('aerr_close') && !acceptance.contains('aerr_wait'),
        'permission dialog tapper cannot target Android ANR actions',
        '$acceptancePath must delegate ANR recognition to the non-interactive '
            'classifier',
      );
      _expect(
        !RegExp(
          r'pm\s+grant\s+[^\r\n]*POST_NOTIFICATIONS',
          caseSensitive: false,
        ).hasMatch(acceptance),
        'release acceptance never pre-grants POST_NOTIFICATIONS',
        '$acceptancePath must observe and handle the real app-initiated dialog',
      );
    }

    const infrastructurePath =
        'integration_test/android_emulator_infrastructure.sh';
    final infrastructure = _requiredText(infrastructurePath);
    if (infrastructure != null) {
      for (final contract in <String>[
        '(( api_level >= 33 ))',
        'stableSamples: 2',
        'android.intent.action.MANAGE_PERMISSIONS',
        'permissionPolicyPending: true',
        'dialogTapAbsent: true',
        'seedProcessAlive: true',
        r'appAbsentBeforeHealth: $appAbsentBeforeHealth',
        "'bounded-ui-observation-exhausted'",
        r'observationPolls: $observationPolls',
        'allCommandsSucceeded: true',
        'shell cmd statusbar expand-settings',
        'ordinaryProductFailure: false',
      ]) {
        _expectContains(
          infrastructurePath,
          infrastructure,
          contract,
          'SystemUI retry evidence must retain its strict context contract',
        );
      }
      _expect(
        !infrastructure.contains('shell input tap'),
        'SystemUI health and ANR classifier never taps a dialog',
        '$infrastructurePath may identify aerr_close/aerr_wait but must never '
            'tap either action',
      );
      _expect(
        !RegExp(
          r'pm\s+grant\s+[^\r\n]*POST_NOTIFICATIONS',
          caseSensitive: false,
        ).hasMatch(infrastructure),
        'SystemUI health gate never pre-grants POST_NOTIFICATIONS',
        '$infrastructurePath must leave notification permission untouched',
      );
      final observationLoop = infrastructure.indexOf(
        'for (( poll = 1; poll <= max_polls; poll += 1 )); do',
      );
      final repeatedSystemUiExpansion = infrastructure.indexOf(
        'shell cmd statusbar expand-settings',
        observationLoop < 0 ? 0 : observationLoop,
      );
      final observationDump = infrastructure.indexOf(
        'shell uiautomator dump',
        observationLoop < 0 ? 0 : observationLoop,
      );
      _expect(
        infrastructure.contains('local max_polls=10') &&
            observationLoop >= 0 &&
            repeatedSystemUiExpansion > observationLoop &&
            observationDump > repeatedSystemUiExpansion,
        'each bounded SystemUI observation reissues expansion before its dump',
        '$infrastructurePath must retry exactly ten expand/dump observations',
      );
    }

    const retryGatePath = 'integration_test/android_emulator_retry_gate.sh';
    final retryGate = _requiredText(retryGatePath);
    if (retryGate != null) {
      for (final contract in <String>[
        '(( api_level < 33 ))',
        '.attempt == 1',
        '.ordinaryProductFailure == false',
        r'.status == "passed"',
        r'.phase == "release-binary-smoke-complete"',
        r'.exitStatus == 0',
        'seed-process-group-termination.json',
        'seed-log-quiescence.json',
        'expected_completion_partial',
        'leaderExitStatus == 143',
        'terminationSignalSent == "TERM"',
        'leaderExitStatus == 137',
        'terminationSignalSent == "KILL"',
        '.reason == "bounded-ui-observation-exhausted"',
        '.component == "system-ui"',
        '.appAbsentBeforeHealth == true',
        '.observationPolls == 10',
        '.allCommandsSucceeded == true',
        ".evidenceFile // empty",
        'Primary classification does not reference safe existing evidence.',
        'Primary ANR classification evidence is empty.',
      ]) {
        _expectContains(
          retryGatePath,
          retryGate,
          contract,
          'fresh-AVD orchestrator must fail closed on its evidence contract',
        );
      }
    }

    const pinnedEmulatorAction =
        'reactivecircus/android-emulator-runner@'
        'a421e43855164a8197daf9d8d40fe71c6996bb0d';
    _expect(
      pinnedEmulatorAction.allMatches(workflow).length == 2,
      'CI has exactly two identically pinned emulator action invocations',
      '$workflowPath must contain one primary and at most one fresh-AVD retry',
    );
    final emulatorJobStart = workflow.indexOf('\n  android-emulator-smoke:');
    final emulatorJobEnd = workflow.indexOf(
      '\n  ios-unsigned:',
      emulatorJobStart < 0 ? 0 : emulatorJobStart,
    );
    final emulatorJob =
        emulatorJobStart >= 0 && emulatorJobEnd > emulatorJobStart
        ? workflow.substring(emulatorJobStart, emulatorJobEnd)
        : '';
    for (final contract in <String>[
      'needs: [android-linux]',
      'actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c',
      r'name: danggui-android-${{ github.sha }}',
      'digest-mismatch: error',
      r'danggui-android-universal-${signing_mode}.apk',
      'sha256sum --check --strict SHA256SUMS',
      'DANGGUI_RELEASE_APK=',
      'DANGGUI_RELEASE_APK_SHA256=',
      r'DANGGUI_RELEASE_ARTIFACT_SHA=${GITHUB_SHA}',
    ]) {
      _expectContains(
        workflowPath,
        emulatorJob,
        contract,
        'emulator required checks consume the exact android-linux artifact',
      );
    }
    for (final contract in <String>[
      r'avd-name: danggui-api-${{ matrix.api-level }}-attempt-1',
      r'avd-name: danggui-api-${{ matrix.api-level }}-attempt-2',
      'emulator-port: 5554',
      'emulator-port: 5556',
      'id: emulator-primary',
      'id: emulator-retry',
      'bash integration_test/android_emulator_retry_gate.sh enforce',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        contract,
        'CI must preserve the bounded two-AVD orchestration contract',
      );
    }
    _expect(
      'force-avd-creation: true'.allMatches(workflow).length == 2,
      'both emulator attempts force unique fresh AVD creation',
      '$workflowPath must force exactly the primary and sole retry AVD',
    );
    _expect(
      'continue-on-error: true'.allMatches(workflow).length == 1,
      'only the primary emulator action suppresses its immediate step result',
      '$workflowPath must defer exactly the primary result to the final gate',
    );
    final primaryStepStart = workflow.indexOf('id: emulator-primary');
    final primaryStepEnd = workflow.indexOf(
      '- name: Classify primary emulator failure',
      primaryStepStart < 0 ? 0 : primaryStepStart,
    );
    final primaryStep =
        primaryStepStart >= 0 && primaryStepEnd > primaryStepStart
        ? workflow.substring(primaryStepStart, primaryStepEnd)
        : '';
    _expect(
      primaryStep.contains('continue-on-error: true'),
      'primary emulator action delegates its result to the final gate',
      'The emulator-primary step must use continue-on-error exactly once',
    );
    final retryStepStart = workflow.indexOf('id: emulator-retry');
    final retryStepEnd = workflow.indexOf(
      '- name: Enforce emulator acceptance result',
      retryStepStart < 0 ? 0 : retryStepStart,
    );
    final retryStep = retryStepStart >= 0 && retryStepEnd > retryStepStart
        ? workflow.substring(retryStepStart, retryStepEnd)
        : '';
    _expect(
      retryStep.isNotEmpty && !retryStep.contains('continue-on-error'),
      'sole fresh-AVD retry cannot suppress its own failure',
      'The emulator-retry step must fail normally and be checked by the final '
          'always gate',
    );
    _expectContains(
      workflowPath,
      workflow,
      "steps.fresh-avd-retry.outputs.retry-authorized == 'true'",
      'fresh AVD runs only after the strict classifier authorizes it',
    );
    final finalGateStart = workflow.indexOf(
      '- name: Enforce emulator acceptance result',
    );
    final uploadStart = workflow.indexOf(
      '- name: Upload emulator acceptance evidence',
      finalGateStart < 0 ? 0 : finalGateStart,
    );
    final finalGate = finalGateStart >= 0 && uploadStart > finalGateStart
        ? workflow.substring(finalGateStart, uploadStart)
        : '';
    _expect(
      finalGate.contains('if: always()') &&
          finalGate.contains(
            'bash integration_test/android_emulator_retry_gate.sh enforce',
          ),
      'final always gate restores the required-check conclusion',
      'The emulator job must enforce primary/retry outcomes even after failure',
    );
    final uploadBlock = uploadStart >= 0
        ? workflow.substring(
            uploadStart,
            workflow.indexOf('\n  ios-unsigned:', uploadStart) > uploadStart
                ? workflow.indexOf('\n  ios-unsigned:', uploadStart)
                : workflow.length,
          )
        : '';
    _expect(
      uploadBlock.contains('if: always()'),
      'emulator evidence uploads after every orchestrator outcome',
      'The acceptance artifact step must remain guarded by always()',
    );
    _expect(
      !RegExp(
        r'pm\s+grant\s+[^\r\n]*POST_NOTIFICATIONS',
        caseSensitive: false,
      ).hasMatch(workflow),
      'CI never bypasses the real POST_NOTIFICATIONS dialog',
      '$workflowPath must not pre-grant notification permission',
    );

    for (final splitContract in <String>[
      '[armeabi-v7a]=1000',
      '[arm64-v8a]=2000',
      '[x86_64]=4000',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        splitContract,
        'CI must enumerate every Flutter split APK version-code offset',
      );
    }
    _expectContains(
      workflowPath,
      workflow,
      'offset + version_code',
      'CI must derive split APK version codes from pubspec.yaml',
    );
    for (final protectedTagContract in <String>[
      'fetch-depth: 0',
      'git merge-base --is-ancestor',
      'refs/remotes/origin/main',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        protectedTagContract,
        'tag publishing must prove the tagged commit belongs to protected main',
      );
    }
    for (final bundletoolContract in <String>[
      'BUNDLETOOL_VERSION: 1.18.3',
      'a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29',
      'sha256sum --check --strict',
    ]) {
      _expectContains(
        workflowPath,
        workflow,
        bundletoolContract,
        'CI must install the pinned, checksum-verified AAB metadata verifier',
      );
    }

    for (final verifierPath in <String>[
      'tool/verify_android_artifacts.sh',
      'tool/verify_android_artifacts.ps1',
    ]) {
      final verifier = _requiredText(verifierPath);
      if (verifier == null) continue;
      _expectContains(
        verifierPath,
        verifier,
        'META-INF/',
        'AAB verification must require a complete JAR signature block',
      );
      _expectContains(
        verifierPath,
        verifier,
        '-printcert -jarfile',
        'AAB verification must inspect the signing certificate',
      );
      for (final metadataContract in <String>[
        'dump manifest',
        'uses-sdk',
        'Unexpected AAB',
        'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      ]) {
        _expectContains(
          verifierPath,
          verifier,
          metadataContract,
          'AAB verification must inspect identity, SDK levels, and permissions',
        );
      }
    }

    _expectContains(
      'tool/verify_android_artifacts.sh',
      _requiredText('tool/verify_android_artifacts.sh') ?? '',
      "sed -e 's/^[[:space:]]*//'",
      'shell APK verification must whitelist the complete permission output',
    );
    for (final certificateParserContract in <String>[
      'Signer #[[:digit:]]+',
      'V[[:digit:].]+ Signer:',
      'apksigner must report exactly one APK signer.',
      'apksigner did not report a certificate SHA-256 digest.',
    ]) {
      _expectContains(
        'tool/verify_android_artifacts.sh',
        _requiredText('tool/verify_android_artifacts.sh') ?? '',
        certificateParserContract,
        'shell APK verification must support old and Build Tools 36 certificate output and reject a missing digest',
      );
    }
    _expectContains(
      'tool/verify_android_artifacts.ps1',
      _requiredText('tool/verify_android_artifacts.ps1') ?? '',
      r'$_.ToString().Trim()',
      'PowerShell APK verification must whitelist the complete permission output',
    );

    final actionUses = RegExp(
      r'^\s*-?\s*uses:\s*([^\s#]+)',
      multiLine: true,
    ).allMatches(workflow).map((match) => match.group(1)!).toList();
    final unpinnedActions = actionUses
        .where((value) => !RegExp(r'@[0-9a-f]{40}$').hasMatch(value))
        .toList();
    _expect(
      actionUses.isNotEmpty && unpinnedActions.isEmpty,
      'every GitHub Action is pinned to a full commit SHA',
      '$workflowPath: unpinned action(s): ${unpinnedActions.join(', ')}',
    );
  }

  void _auditResolvedAndroidPlugins(List<Map<String, Object?>> plugins) {
    final unexpectedPermissions = <String>[];
    final inspected = <String>[];
    for (final plugin in plugins) {
      if (plugin['dev_dependency'] == true) continue;
      final name = plugin['name'];
      final path = plugin['path'];
      if (name is! String || path is! String) {
        failures.add(
          '.flutter-plugins-dependencies: malformed Android plugin entry',
        );
        continue;
      }
      inspected.add(name);
      final manifest = File(
        '${Directory(path).path}${Platform.pathSeparator}android'
        '${Platform.pathSeparator}src${Platform.pathSeparator}main'
        '${Platform.pathSeparator}AndroidManifest.xml',
      );
      if (!manifest.existsSync()) continue;
      for (final permission in _androidPermissions(
        manifest.readAsStringSync(),
      )) {
        if (!expectedAndroidPermissions.contains(permission)) {
          unexpectedPermissions.add('$name: $permission');
        }
      }
    }
    _expect(
      unexpectedPermissions.isEmpty,
      'resolved Android plugin manifests add no permission outside the '
          'local-reminder allowlist (${inspected.length} plugins inspected)',
      'resolved Android plugin manifest permission(s) require review: '
          '${unexpectedPermissions.join(', ')}',
    );
  }

  void _auditResolvedIosPlugins(List<Map<String, Object?>> plugins) {
    final failuresForPlugins = <String>[];
    final inspected = <String>[];
    for (final plugin in plugins) {
      if (plugin['dev_dependency'] == true) continue;
      final name = plugin['name'];
      final path = plugin['path'];
      if (name is! String || path is! String) {
        failures.add(
          '.flutter-plugins-dependencies: malformed iOS plugin entry',
        );
        continue;
      }
      inspected.add(name);
      final pluginRoot = Directory(path);
      for (final sourceDirectoryName in <String>['ios', 'darwin']) {
        final sourceDirectory = Directory(
          '${pluginRoot.path}${Platform.pathSeparator}$sourceDirectoryName',
        );
        if (!sourceDirectory.existsSync()) continue;
        failuresForPlugins.addAll(
          _scanDirectory(
            sourceDirectory,
            const <String>{
              '.swift',
              '.m',
              '.mm',
              '.h',
              '.plist',
              '.entitlements',
            },
            <_ForbiddenPattern>[
              _ForbiddenPattern(
                RegExp(
                  r'aps-environment|<string>remote-notification</string>|'
                  r'registerForRemoteNotifications|\b(URLSession|NWConnection)\b',
                  caseSensitive: false,
                ),
                'resolved iOS plugin push/network capability',
              ),
            ],
            excludePathFragments: const <String>['/example/', r'\example\'],
          ),
        );
      }
    }
    _expect(
      failuresForPlugins.isEmpty,
      'resolved iOS plugin production metadata contains no remote-push or '
      'network API (${inspected.length} plugins inspected)',
      failuresForPlugins.join('; '),
    );
  }

  String? _requiredText(String relativePath) {
    final file = File(_path(relativePath));
    if (!file.existsSync()) {
      failures.add('required file is missing: $relativePath');
      return null;
    }
    return file.readAsStringSync();
  }

  void _expectContains(
    String path,
    String content,
    String expected,
    String reason,
  ) {
    _expect(
      content.contains(expected),
      reason,
      '$path: $reason; missing ${jsonEncode(expected)}',
    );
  }

  void _expectGradleValue(
    String path,
    String content,
    String property,
    String value,
  ) {
    _expectMatch(
      path,
      content,
      RegExp(
        '${RegExp.escape(property)}\\s*=\\s*${RegExp.escape(value)}(?:\\s|\$)',
      ),
      '$property must be $value',
    );
  }

  void _expectPlistString(
    String path,
    String content,
    String key,
    String value,
  ) {
    _expectMatch(
      path,
      content,
      RegExp(
        '<key>${RegExp.escape(key)}</key>\\s*'
        '<string>${RegExp.escape(value)}</string>',
      ),
      '$key must be $value',
    );
  }

  void _expectMatch(
    String path,
    String content,
    RegExp expression,
    String reason,
  ) {
    _expect(expression.hasMatch(content), reason, '$path: $reason');
  }

  void _expectNoMatch(
    String path,
    String content,
    RegExp expression,
    String reason,
  ) {
    final match = expression.firstMatch(content);
    if (match == null) {
      checks.add('$path: no $reason');
      return;
    }
    final line = _lineOf(content, match.start);
    failures.add('$path:$line: $reason');
  }

  void _expect(bool condition, String success, String failure) {
    if (condition) {
      checks.add(success);
    } else {
      failures.add(failure);
    }
  }

  String _path(String relativePath) {
    return '${root.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}';
  }

  String _relative(File file) {
    final rootPrefix = '${root.path}${Platform.pathSeparator}';
    return file.absolute.path.startsWith(rootPrefix)
        ? file.absolute.path.substring(rootPrefix.length).replaceAll('\\', '/')
        : file.path.replaceAll('\\', '/');
  }

  List<String> _scanDirectory(
    Directory directory,
    Set<String> extensions,
    List<_ForbiddenPattern> patterns, {
    List<String> excludePathFragments = const <String>[],
  }) {
    if (!directory.existsSync()) {
      return <String>['required directory is missing: ${directory.path}'];
    }
    final files = _filesBelow(directory, extensions)
      ..removeWhere((file) => excludePathFragments.any(file.path.contains));
    final found = <String>[];
    for (final file in files) {
      final content = file.readAsStringSync();
      for (final pattern in patterns) {
        final match = pattern.expression.firstMatch(content);
        if (match == null) continue;
        found.add(
          '${_relative(file)}:${_lineOf(content, match.start)}: '
          '${pattern.reason}',
        );
      }
    }
    return found;
  }
}

final class _ForbiddenPattern {
  const _ForbiddenPattern(this.expression, this.reason);

  final RegExp expression;
  final String reason;
}

List<Map<String, Object?>> _pluginEntries(Object? value) {
  if (value is! List<Object?>) return <Map<String, Object?>>[];
  return value.whereType<Map<String, Object?>>().toList();
}

Set<String> _androidPermissions(String manifest) {
  return RegExp(
    r'<uses-permission(?:-sdk-\d+)?\b[^>]*\bandroid:name\s*=\s*'
    r'["\x27]([^"\x27]+)["\x27]',
    caseSensitive: false,
  ).allMatches(manifest).map((match) => match.group(1)!).toSet();
}

Set<String> _excludedBackupDomains(String xml) {
  return RegExp(r'<exclude\s+domain="([^"]+)"\s+path="\."\s*/>')
      .allMatches(xml)
      .map((match) => match.group(1)!)
      .toSet();
}

Set<String> _topLevelKeysInSection(
  String yaml,
  String section,
  String nextSection,
) {
  final start = RegExp(
    '^${RegExp.escape(section)}:\\s*\$',
    multiLine: true,
  ).firstMatch(yaml);
  final end = RegExp(
    '^${RegExp.escape(nextSection)}:\\s*\$',
    multiLine: true,
  ).firstMatch(yaml);
  if (start == null || end == null || end.start <= start.end) return <String>{};
  final body = yaml.substring(start.end, end.start);
  return RegExp(
    r'^  ([a-zA-Z0-9_]+):',
    multiLine: true,
  ).allMatches(body).map((match) => match.group(1)!).toSet();
}

Map<String, String> _parseLockPackages(String lock) {
  final packagesStart = RegExp(
    r'^packages:\s*$',
    multiLine: true,
  ).firstMatch(lock);
  final sdksStart = RegExp(r'^sdks:\s*$', multiLine: true).firstMatch(lock);
  if (packagesStart == null || sdksStart == null) return <String, String>{};
  final packagesText = lock.substring(packagesStart.end, sdksStart.start);
  final starts = RegExp(
    r'^  ([a-zA-Z0-9_]+):\s*$',
    multiLine: true,
  ).allMatches(packagesText).toList();
  final result = <String, String>{};
  for (var index = 0; index < starts.length; index += 1) {
    final match = starts[index];
    final end = index + 1 < starts.length
        ? starts[index + 1].start
        : packagesText.length;
    result[match.group(1)!] = packagesText.substring(match.end, end);
  }
  return result;
}

List<File> _filesBelow(Directory directory, Set<String> extensions) {
  if (!directory.existsSync()) return <File>[];
  final files =
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) {
            final lower = file.path.toLowerCase();
            return extensions.any(lower.endsWith);
          })
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  return files;
}

bool _sameSet(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

int _lineOf(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

String _formatSet(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return sorted.isEmpty ? '{}' : '{${sorted.join(', ')}}';
}
