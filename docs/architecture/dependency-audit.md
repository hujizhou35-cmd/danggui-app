# Dependency audit

Audit date: 2026-08-22. The exact resolved graph is committed in
`pubspec.lock`; CI uses Flutter 3.47.1 / Dart 3.13.1 and runs `flutter pub get --enforce-lockfile`
against that lockfile. Runtime dependencies are intentionally limited to local
storage, local notifications, platform file/share sheets, navigation and UI
state. No analytics, advertising, account, cloud-sync, Firebase, crash-reporting
or AI SDK is present.

## Runtime dependencies

| Package (resolved) | Purpose | Upstream / maintenance signal | License | Android / iOS | Runtime network behaviour | Known limit and exit strategy |
| --- | --- | --- | --- | --- | --- | --- |
| `archive 4.1.0` | ZIP backup/export containers | [brendan-duncan/archive](https://github.com/brendan-duncan/archive), current Dart package | MIT | Dart on both | None | ZIP is implemented behind `BackupCodec` / export services; replace with another streaming ZIP codec without changing repositories. |
| `collection 1.19.1` | Deterministic collection helpers | [dart-lang/core](https://github.com/dart-lang/core/tree/main/pkgs/collection), Dart team | BSD-3-Clause | Dart on both | None | Helpers only; removable with standard Dart collections. |
| `cryptography 2.9.0` | AES-GCM and password-derived backup encryption primitives | [dint-dev/cryptography](https://github.com/dint-dev/cryptography) | Apache-2.0 | Dart on both | None | Encryption is optional and format-versioned. A codec migration can add a new algorithm without rewriting stored app data. |
| `cupertino_icons 1.0.9` | Platform-familiar fallback icons | [flutter/packages](https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons), Flutter project | MIT | Both | None | Replaceable by bundled vector assets or Material icons. |
| `drift 2.34.3` + `drift_flutter 0.3.1` | Typed SQLite schema, migrations, transactions and testable repositories | [simolus3/drift](https://github.com/simolus3/drift), actively released | MIT | Both | None | SQL schema is documented independently and backup/export formats are not Drift-specific; a repository-by-repository migration remains possible. |
| `file_picker 11.0.3` | User-initiated backup import and filesystem selection | [miguelpruivo/flutter_file_picker](https://github.com/miguelpruivo/flutter_file_picker) | MIT | Both | None | Mobile providers can return temporary copies or scoped URIs. Files are validated and copied immediately; no persistent access is assumed. A native document-picker adapter can replace it. |
| `flutter_local_notifications 22.3.0` | Local, inexact notifications and snooze actions | [MaikuB/flutter_local_notifications](https://github.com/MaikuB/flutter_local_notifications) | BSD-3-Clause | Both | None; no push service | OEM power management may delay inexact alarms. All scheduling is behind `NotificationGateway`, with a revisioned outbox for replacement. |
| `flutter_riverpod 3.4.2` | Application state and dependency injection | [rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | MIT | Both | None | Providers are at presentation/application boundaries; repositories and services remain plain Dart and testable without Riverpod. |
| `flutter_secure_storage 10.3.1` | Optional automatic-backup passphrase in Android Keystore / Apple Keychain | [mogol/flutter_secure_storage](https://github.com/mogol/flutter_secure_storage) | BSD-3-Clause | Both | None | Used only for an optional local secret. Disabling encryption deletes the stored secret. The passphrase-store interface can be replaced by native code. |
| `go_router 17.5.0` | Four-tab shell and nested detail routes | [flutter/packages](https://github.com/flutter/packages/tree/main/packages/go_router), Flutter team | BSD-3-Clause | Both | None | Routes are centralized in `app.dart`; Navigator 2.0 can replace it without data changes. |
| `intl 0.20.3` | Offline date/time formatting for four locales | [dart-lang/i18n](https://github.com/dart-lang/i18n/tree/main/pkgs/intl), Dart team | BSD-3-Clause | Both | None | Locale formatting is presentation-only; stored dates remain ISO/UTC values. |
| `path 1.9.1` + `path_provider 2.1.6` | Safe local paths and application-support/temp directories | [dart-lang/core](https://github.com/dart-lang/core/tree/main/pkgs/path) / [flutter/packages](https://github.com/flutter/packages/tree/main/packages/path_provider) | BSD-3-Clause | Both | None | Access is wrapped by backup/database services; platform-native directory lookup is the fallback. |
| `share_plus 12.0.2` | User-initiated system share sheet for exported ZIP/backup files | [fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins) | BSD-3-Clause | Both | The app itself does not transmit; the user chooses a destination app | Shares only files explicitly created by the user action. A native share-sheet adapter can replace it. |
| `timezone 0.11.1` | Bundled IANA timezone rules for local notification reconciliation | [dart-lang/labs](https://github.com/dart-lang/labs/tree/main/pkgs/timezone), Dart team | BSD-3-Clause | Both | The app imports the bundled database; it never invokes an HTTP loader | Rules are refreshed by dependency updates. Native timezone APIs are the fallback. |
| `uuid 4.6.0` | Stable random entity IDs | [Daegalus/dart-uuid](https://github.com/Daegalus/dart-uuid) | MIT | Dart on both | None | ID generation is injected in repositories and can be replaced. |

Flutter itself and `flutter_localizations` are supplied by the locked Flutter
SDK and carry Flutter's BSD-style license. Generated transitive license notices
remain discoverable through Flutter's license registry; release documentation
must retain the repository `NOTICE` file.

## Development-only dependencies

| Package | Purpose | Shipped in release | License posture |
| --- | --- | --- | --- |
| `build_runner`, `drift_dev` | Drift code generation | No | Permissive; build-time only |
| `flutter_launcher_icons`, `flutter_native_splash` | Deterministic platform brand assets | No | Permissive; build-time only |
| `flutter_lints` | Static-analysis rules | No | Dart/Flutter BSD-style |
| `flutter_test`, `integration_test`, `mocktail` | Unit, widget, integration and golden tests | No | Permissive; test-only |

## Offline and permission gates

- Android's merged release manifest is inspected in CI and must not contain
  `android.permission.INTERNET`, exact-alarm or full-screen-intent permissions.
- iOS contains no remote notification entitlement, background networking mode,
  analytics endpoint or account capability.
- A repository-wide import/configuration scan rejects Firebase, analytics,
  advertising and crash-reporting SDK additions during release review.
- `timezone` has a transitive `http` library in the resolved graph, but 当归
  uses only its bundled `latest.dart` dataset. With no Android INTERNET
  permission and no application HTTP calls, it cannot become a hidden sync path.
- File export and sharing are always direct user gestures. Automatic backup
  writes only to the app's local support directory; it does not upload.

## Upgrade policy

Dependencies are updated deliberately, never by an unconstrained CI upgrade.
Each update requires: lockfile diff review, upstream changelog/license review,
`flutter analyze --fatal-infos`, the full test/golden suite, backup compatibility
tests, notification platform checks, and final-manifest permission inspection.
Major upgrades of Drift, local notifications, file picker or secure storage are
treated as release-blocking migrations.
