# 固定参考来源、评分与许可证台账

## 采用门槛

来源按 100 分评分：相关性 20、官方性/可核验性 20、针对性测试 15、维护状态 15、架构与离线适配 10、隐私 10、许可证 10。`>=80` 可进入设计候选，`65–79` 仅作补充，`<65` 淘汰。高分不覆盖许可证限制：GPL/AGPL/SSPL/无许可证项目只研究行为、边界和测试，不复制代码；MPL/LGPL 单独评估；MIT/BSD/Apache 仍需保留通知并做本项目审查。

Apple 页面没有提交哈希，因此记录本次访问日 `2026-08-28` 和精确 API 页面。Apple Sample 在下载包的具体许可证未核对前只用于确定 SDK 行为，不复制示例代码。

## Apple、标准与平台规则

| ID | 固定来源 | 可核验规则/符号 | 用于 | 评分 |
|---|---|---|---|---:|
| A01 | [AlarmKit：Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)、[`AlarmManager.alarms`](https://developer.apple.com/documentation/alarmkit/alarmmanager/alarms) | authorization、唯一 ID、schedule 结果、`alarmUpdates`；one-shot fire/stop 后会从 daemon 集合移除。缺失可推断“不再由 daemon 调度”，但不能证明用户实际看见/听见 | F03/F04/F17/F19/F21 | 100 |
| A02 | [`AlarmManager.schedule(id:configuration:)`](https://developer.apple.com/documentation/alarmkit/alarmmanager/schedule%28id%3Aconfiguration%3A%29)、[`requestAuthorization()`](https://developer.apple.com/documentation/alarmkit/alarmmanager/requestauthorization%28%29)、[`NSAlarmKitUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsalarmkitusagedescription) | iOS 26+ 调度、授权与 Info.plist 前置条件 | F03/F04/F19 | 100 |
| A03 | [本地通知排期](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)、[pending requests](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/getpendingnotificationrequests%28completionhandler%3A%29)、[UserNotifications](https://developer.apple.com/documentation/usernotifications) | 系统尝试及时投递但不保证；持久 request ID、查询与取消 | F01/F03/F04/F17 | 100 |
| A04 | [Time Sensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive)、[`timeSensitiveSetting`](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/timesensitivesetting) | 用户可关闭 Time Sensitive；能力必须读取设置而非只看总授权 | F04 | 100 |
| A05 | [管理应用生命周期](https://developer.apple.com/documentation/uikit/managing-your-app-s-life-cycle)、[迁移到 scene 生命周期](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)、[进入后台准备](https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-background) | 采用 scene 后以 scene 回调为主；后台前释放资源并保存关键状态 | F01/F07/F22 | 98 |
| A06 | [处理通知及通知动作](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) | 系统可后台启动 App 并调用 delegate；完成回调必须被调用 | F01/F03/F19/F22 | 100 |
| A07 | [`DateComponents`](https://developer.apple.com/documentation/foundation/datecomponents)、[`Calendar`](https://developer.apple.com/documentation/foundation/calendar)、[`TimeZone.identifier`](https://developer.apple.com/documentation/foundation/timezone/identifier) | 本地日历组件、IANA 时区标识和绝对 `Date` 是不同语义 | F15 | 98 |
| A08 | [`FileProtectionType.completeUntilFirstUserAuthentication`](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication)、[`NSData.WritingOptions.completeFileProtectionUntilFirstUserAuthentication`](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotectionuntilfirstuserauthentication) | 首次解锁后后台可读的文件保护选项 | F10/F11/F12/F20 | 98 |
| A09 | [`FileManager.replaceItemAt`](https://developer.apple.com/documentation/foundation/filemanager/replaceitemat%28_%3Awithitemat%3Abackupitemname%3Aoptions%3A%29)、[APFS](https://developer.apple.com/documentation/foundation/about-apple-file-system) | 原子替换、备份项及文件系统语义 | F09/F10/F12/F16/F18/F20 | 96 |
| A10 | [`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)、[限制 Keychain 可访问性](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) | 首次解锁后可用、不可迁移到新设备，需选择最小可访问性 | F11/F20 | 100 |
| A11 | [排除备份资源属性](https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup)、[QA1719](https://developer.apple.com/library/archive/qa/qa1719/_index.html) | 可重建/下载内容不应进入 iCloud 备份 | F10/F20 | 95 |
| A12 | [XCTest attachment](https://developer.apple.com/documentation/xctest/adding-attachments-to-tests-activities-and-issues)、[Simulator 与真机](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) | `.xcresult`/附件用于失败证据；Simulator 不替代真机硬件与完整系统行为 | F24/F28 | 100 |
| A13 | [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)、[Privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) | 收集/访问原因需与实际行为一致 | F21/F26/F28 | 94 |
| A14 | [`OSLogPrivacy`](https://developer.apple.com/documentation/os/oslogprivacy) | 日志字段应显式控制隐私，不把用户内容当公开字段 | F21 | 96 |
| S01 | [SQLite Atomic Commit](https://www.sqlite.org/atomiccommit.html) | 事务、fsync、hot journal 与 crash 原子性假设 | F09/F10/F12/F16/F18 | 100 |
| S02 | [SQLite WAL](https://www.sqlite.org/wal.html) | WAL、checkpoint、`-wal/-shm` 和并发语义 | F10/F16/F17 | 100 |
| S03 | [SQLite Online Backup API](https://www.sqlite.org/backup.html) | 在活动数据库上获得一致快照的官方机制 | F10/F12 | 100 |
| S04 | [SQLite PRAGMA integrity_check/quick_check](https://www.sqlite.org/pragma.html#pragma_integrity_check) | `quick_check` 不验证 UNIQUE/索引一致性的全部约束，完整审计需 `integrity_check` | F12/F16/F18 | 100 |
| S05 | [RFC 9106 Argon2](https://www.rfc-editor.org/rfc/rfc9106.html)、[NIST SP 800-38D GCM](https://csrc.nist.gov/pubs/sp/800/38/d/final) | KDF 参数、随机 salt 和认证加密的标准边界 | F11 | 100 |
| S06 | [Android ADB 命令参考 `1cf2f017d312f73b3dc53bda85ef2610e35a80e9`](https://android.googlesource.com/platform/packages/modules/adb/+/1cf2f017d312f73b3dc53bda85ef2610e35a80e9/docs/user/adb.1.md) | `--no-streaming` 明确定义为先推送 APK、再调用 Package Manager；`--streaming`/`--incremental` 属于不同传输模式 | F28 | 100 |
| C01 | [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)、[公开仓库 Actions 计费](https://docs.github.com/en/billing/concepts/product-billing/github-actions) | 标准 runner 标签、公开仓库标准 runner 的计费边界；不能据此假设某一 Xcode image 永久存在 | F26/F28 | 96 |
| C02 | [actions/runner-images `fe6859a246ddeeb78fc8698ec1ff37b628394fe0`](https://github.com/actions/runner-images/tree/fe6859a246ddeeb78fc8698ec1ff37b628394fe0) | 2026-08-28 runner image 清单和软件清单的固定快照 | F26/F28 | 94 |
| C03 | [Flutter iOS build/release](https://docs.flutter.dev/deployment/ios)、[Flutter integration testing](https://docs.flutter.dev/testing/integration-tests) | unsigned/Simulator 构建与集成测试的官方工具边界 | F19/F28 | 94 |

## 固定到提交的成熟实现

### R01 flutter_local_notifications — `b475bc883dab07da3c1b19e86b0746eb20f14f2f`

- 实现：[iOS `FlutterLocalNotificationsPlugin.m`](https://github.com/MaikuB/flutter_local_notifications/blob/b475bc883dab07da3c1b19e86b0746eb20f14f2f/flutter_local_notifications/ios/flutter_local_notifications/Sources/flutter_local_notifications/FlutterLocalNotificationsPlugin.m)，核对 `requestPermissions`、`addNotificationRequest`、pending/cancel、`willPresentNotification`、`didReceiveNotificationResponse`。
- 测试：[iOS Dart tests](https://github.com/MaikuB/flutter_local_notifications/blob/b475bc883dab07da3c1b19e86b0746eb20f14f2f/flutter_local_notifications/test/ios_flutter_local_notifications_test.dart)；[README 的 iOS pending 数量限制说明](https://github.com/MaikuB/flutter_local_notifications/blob/b475bc883dab07da3c1b19e86b0746eb20f14f2f/flutter_local_notifications/README.md)。
- 适用：普通通知桥、权限、pending 对账和动作回调；不能证明 AlarmKit 或真机准时性。
- 许可证：[BSD-3-Clause](https://github.com/MaikuB/flutter_local_notifications/blob/b475bc883dab07da3c1b19e86b0746eb20f14f2f/flutter_local_notifications/LICENSE)。评分 `92`，可作设计候选。

### R02 Signal-iOS — `eec0a2f587b49082efdb5a4dc1e2a491fd52144f`

- 原生生命周期/通知：[AppDelegate.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/Signal/AppLaunch/AppDelegate.swift)、[NotificationActionHandler.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/Signal/Notifications/NotificationActionHandler.swift)、[UserNotificationsPresenter.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Notifications/UserNotificationsPresenter.swift)。核对类型/符号 `AppDelegate.application`、`NotificationActionHandler`、`UserNotificationsPresenter`。
- 数据/恢复/诊断：[DatabaseRecovery.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Storage/Database/DatabaseRecovery.swift)、[GRDBSchemaMigrator.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Storage/Database/GRDBSchemaMigrator.swift)、[SSKKeychainStorage.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Storage/SSKKeychainStorage.swift)、[OWSFileSystem.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Util/OWSFileSystem.swift)、[Logger.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Debugging/Logger.swift)、[DebugLogger.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/Debugging/DebugLogger.swift)。
- 测试：[DatabaseRecoveryTest.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/tests/Storage/Database/DatabaseRecoveryTest.swift)、[GRDBSchemaMigratorTest.swift](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/SignalServiceKit/tests/Storage/Database/GRDBSchemaMigratorTest.swift)、`BackupArchiveIntegrationTests`。
- 许可证：[AGPL-3.0](https://github.com/signalapp/Signal-iOS/blob/eec0a2f587b49082efdb5a4dc1e2a491fd52144f/LICENSE)。评分 `89`；仅研究行为、恢复策略和测试，不复制代码。

### R03 GRDB.swift — `0d8cf958b4b66a0473ec6e6986eb9da462171da9`

- 实现：[DatabaseMigrator.swift](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/GRDB/Migration/DatabaseMigrator.swift)、[DatabaseBackupProgress.swift](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/GRDB/Core/DatabaseBackupProgress.swift)；类型/符号 `DatabaseMigrator.registerMigration`、`migrate`、`DatabaseBackupProgress`。
- 测试：[BackupTestCase.swift](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/Tests/GRDBTests/Core/BackupTestCase.swift)、[DatabaseMigratorTests.swift](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/Tests/GRDBTests/Migrations/DatabaseMigratorTests.swift)、[MigrationCrashTests.swift](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/Tests/Crash/MigrationCrashTests.swift)。
- 许可证：[MIT](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/LICENSE)。评分 `95`；事务/迁移/备份测试模式可采用，默认不引入生产依赖。

### R04 KeychainAccess — `e0c7eebc5a4465a3c4680764f26b7a61f567cdaf`

- 实现：[Keychain.swift](https://github.com/kishikawakatsumi/KeychainAccess/blob/e0c7eebc5a4465a3c4680764f26b7a61f567cdaf/Lib/KeychainAccess/Keychain.swift)，核对类型/符号 `Keychain`、`Accessibility.afterFirstUnlockThisDeviceOnly`、`accessibility(_:)`、`synchronizable(_:)` 和 OSStatus 映射。
- 测试：[KeychainAccessTests](https://github.com/kishikawakatsumi/KeychainAccess/tree/e0c7eebc5a4465a3c4680764f26b7a61f567cdaf/Lib/KeychainAccessTests)。
- 许可证：[MIT](https://github.com/kishikawakatsumi/KeychainAccess/blob/e0c7eebc5a4465a3c4680764f26b7a61f567cdaf/LICENSE)。评分 `88`；采用测试边界，现阶段不新增依赖。

### R05 ZIPFoundation — `d17566fdcb293c2d2304c6b445dd729dd66d470e`

- 实现：[Archive+Reading.swift](https://github.com/weichsel/ZIPFoundation/blob/d17566fdcb293c2d2304c6b445dd729dd66d470e/Sources/ZIPFoundation/Archive%2BReading.swift)、[Archive+Writing.swift](https://github.com/weichsel/ZIPFoundation/blob/d17566fdcb293c2d2304c6b445dd729dd66d470e/Sources/ZIPFoundation/Archive%2BWriting.swift)；类型/符号 `Archive.extract`、`Archive.addEntry`、entry path validation。
- 测试：[ZIPFoundationTests](https://github.com/weichsel/ZIPFoundation/tree/d17566fdcb293c2d2304c6b445dd729dd66d470e/Tests/ZIPFoundationTests)，包括 CRC、损坏 ZIP、目录穿越和符号链接语料。
- 许可证：[MIT](https://github.com/weichsel/ZIPFoundation/blob/d17566fdcb293c2d2304c6b445dd729dd66d470e/LICENSE)。评分 `89`；采用恶意归档测试模式，不引入依赖。

### R06 flutter_secure_storage — `e144260cb3c05166d0db4322a46b4637e042351c`

- 实现：[`AppleOptions`](https://github.com/juliansteenbakker/flutter_secure_storage/blob/e144260cb3c05166d0db4322a46b4637e042351c/flutter_secure_storage/lib/options/apple_options.dart)、[`IOSOptions`](https://github.com/juliansteenbakker/flutter_secure_storage/blob/e144260cb3c05166d0db4322a46b4637e042351c/flutter_secure_storage/lib/options/ios_options.dart)、[Darwin plugin sources](https://github.com/juliansteenbakker/flutter_secure_storage/tree/e144260cb3c05166d0db4322a46b4637e042351c/flutter_secure_storage_darwin/darwin/flutter_secure_storage_darwin/Sources/flutter_secure_storage_darwin)；核对 `KeychainAccessibility.first_unlock_this_device`、`synchronizable` 和 `FlutterSecureStorage` query helper。
- 固定提交的 Dart tests 在 [`flutter_secure_storage_test.dart`](https://github.com/juliansteenbakker/flutter_secure_storage/blob/e144260cb3c05166d0db4322a46b4637e042351c/flutter_secure_storage/test/flutter_secure_storage_test.dart)，但仓库中没有 Darwin 原生单元测试；因此 accessibility/锁屏合同必须由本项目补齐。
- 许可证：[BSD-3-Clause](https://github.com/juliansteenbakker/flutter_secure_storage/blob/e144260cb3c05166d0db4322a46b4637e042351c/LICENSE)。评分 `82`；本项目已依赖，可作补充实现，需补缺密钥/锁定测试而非替换。

### R07 Joplin — `3156f23fa2cf2b1851df6408d9e1bab06db50ac9`

- 实现/测试：[mobile editor `autosave.ts`](https://github.com/laurent22/joplin/blob/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/packages/app-mobile/components/NoteEditor/ImageEditor/autosave.ts)、[`promptRestoreAutosave.ts`](https://github.com/laurent22/joplin/blob/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/packages/app-mobile/components/NoteEditor/ImageEditor/promptRestoreAutosave.ts)、[migrations](https://github.com/laurent22/joplin/tree/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/packages/lib/services/database/migrations)、[`SearchResults.test.tsx`](https://github.com/laurent22/joplin/blob/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/packages/app-mobile/components/screens/SearchScreen/SearchResults.test.tsx)、[`NoteExportButton.test.tsx`](https://github.com/laurent22/joplin/blob/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/packages/app-mobile/components/screens/ConfigScreen/NoteExportSection/NoteExportButton.test.tsx)。核对 autosave/restore prompt、migration number 和搜索/导出测试符号。
- 许可证：[AGPL-3.0-or-later](https://github.com/laurent22/joplin/blob/3156f23fa2cf2b1851df6408d9e1bab06db50ac9/LICENSE)。评分 `84`；只研究自动保存、迁移、搜索和导出测试。

### R08 AppFlowy — `5cf3a365dec0d59f64bad1ee4bb1050471a39b93`

- 实现/测试：[document lifecycle test](https://github.com/AppFlowy-IO/AppFlowy/blob/5cf3a365dec0d59f64bad1ee4bb1050471a39b93/frontend/appflowy_flutter/integration_test/desktop/document/document_app_lifecycle_test.dart)、[document editing tests](https://github.com/AppFlowy-IO/AppFlowy/blob/5cf3a365dec0d59f64bad1ee4bb1050471a39b93/frontend/appflowy_flutter/integration_test/desktop/document/edit_document_test.dart)、[Flutter integration tests](https://github.com/AppFlowy-IO/AppFlowy/tree/5cf3a365dec0d59f64bad1ee4bb1050471a39b93/frontend/appflowy_flutter/integration_test)。仓库还保留旧 DB 夹具用于升级测试。
- 许可证：[AGPL-3.0](https://github.com/AppFlowy-IO/AppFlowy/blob/5cf3a365dec0d59f64bad1ee4bb1050471a39b93/LICENSE)。评分 `82`；只研究模型化工作流和迁移夹具。

### R09 Standard Notes — `e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d`

- 实现/测试：[Import domain](https://github.com/standardnotes/app/tree/e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d/packages/services/src/Domain/Import)、[`FilesBackupService.spec.ts`](https://github.com/standardnotes/app/blob/e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d/packages/services/src/Domain/Backups/FilesBackupService.spec.ts)、[`migration.test.js`](https://github.com/standardnotes/app/blob/e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d/packages/snjs/mocha/migrations/migration.test.js)、[mobile `AppDelegate.mm`](https://github.com/standardnotes/app/blob/e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d/packages/mobile/ios/StandardNotes/AppDelegate.mm)。重点研究 import/backup、item mutator、migration 版本和测试。
- 许可证：[AGPL-3.0](https://github.com/standardnotes/app/blob/e1ebcba3c32c7cb68fdf00bb48bac49a5c10f07d/LICENSE)。评分 `82`；只研究行为与测试。

### R10 Simplenote-iOS — `9b1bb17d8ec224a709d306e0ec34cee38bc7d933`

- 原生实现/测试：[`Note.m`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/Simplenote/Classes/Note.m)、[`NotesListController.swift`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/Simplenote/Classes/NotesListController.swift)、[`FileStorage.swift`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/Simplenote/Classes/FileStorage.swift)、[`MigrationsHandler.swift`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/Simplenote/Classes/MigrationsHandler.swift)、[`KeychainManager.swift`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/Simplenote/Classes/KeychainManager.swift)、[`SimplenoteUITestsNoteEditor.swift`](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/SimplenoteUITests/SimplenoteUITestsNoteEditor.swift)。
- 许可证：[GPL-2.0](https://github.com/Automattic/simplenote-ios/blob/9b1bb17d8ec224a709d306e0ec34cee38bc7d933/LICENSE.md)。评分 `82`；只研究原生列表/编辑/存储工作流。

### R11 Firefox-iOS — `b0799c34c313be9e832b749794f91277a9ce57eb`

- 原生实现：[AppDelegate.swift](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/firefox-ios/Client/Application/AppDelegate.swift)、[SceneDelegate.swift](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/firefox-ios/Client/Application/SceneDelegate.swift)；核对类型/符号 `AppDelegate`、`SceneDelegate.scene`、`windowScene(_:performActionFor:completionHandler:)`。
- 测试/日志：[`SceneDelegateTests.swift`](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/firefox-ios/firefox-ios-tests/Tests/ClientTests/Application/SceneDelegateTests.swift)、[XCUITest](https://github.com/mozilla-mobile/firefox-ios/tree/b0799c34c313be9e832b749794f91277a9ce57eb/firefox-ios/firefox-ios-tests/Tests/XCUITests)、[`DefaultLogger.swift`](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/BrowserKit/Sources/Common/Logger/DefaultLogger.swift)、[`LoggerTests.swift`](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/BrowserKit/Tests/CommonTests/LoggerTests/LoggerTests.swift)。
- 许可证：[MPL-2.0](https://github.com/mozilla-mobile/firefox-ios/blob/b0799c34c313be9e832b749794f91277a9ce57eb/LICENSE)。评分 `89`；本版只研究 scene/route/a11y 测试，复制需单独文件级评估。

### R12 Drift / sqlite3.dart / cryptography

- Drift `aa70d93ceba68493fdfda4365501d19c038d3398`：[migrations/tests](https://github.com/simolus3/drift/tree/aa70d93ceba68493fdfda4365501d19c038d3398/drift/test)、[MIT](https://github.com/simolus3/drift/blob/aa70d93ceba68493fdfda4365501d19c038d3398/LICENSE)，评分 `93`。
- sqlite3.dart `762682371af56ff3a32cb7fb8015f2e5f25b3eb4`：[hook/build sources](https://github.com/simolus3/sqlite3.dart/tree/762682371af56ff3a32cb7fb8015f2e5f25b3eb4/sqlite3)、[MIT](https://github.com/simolus3/sqlite3.dart/blob/762682371af56ff3a32cb7fb8015f2e5f25b3eb4/LICENSE)，评分 `90`。
- cryptography `87f42fad6f7f120feb8e47854164016ceac3dfd0`：[algorithms/tests](https://github.com/dint-dev/cryptography/tree/87f42fad6f7f120feb8e47854164016ceac3dfd0/cryptography/test)、[Apache-2.0](https://github.com/dint-dev/cryptography/blob/87f42fad6f7f120feb8e47854164016ceac3dfd0/LICENSE)，评分 `91`。
- 三者为当前技术栈或直接相关实现；继续固定 lock 与原生制品 SHA，不因审计新增替代依赖。

## 失败案例与修复证据

| ID | 原项目 issue/修复 | 暴露的失败模式 | 覆盖 |
|---|---|---|---|
| X01 | [flutter_local_notifications #2312](https://github.com/MaikuB/flutter_local_notifications/issues/2312) | iOS pending 通知 64 条容量与排期淘汰 | F03/F17 |
| X02 | [flutter_local_notifications #2441](https://github.com/MaikuB/flutter_local_notifications/issues/2441) | iOS 18 重复日历通知出现不一致 | F03/F15 |
| X03 | [Signal-iOS #5815](https://github.com/signalapp/Signal-iOS/issues/5815) | 磁盘不足后数据库损坏/无法恢复 | F10/F12/F16 |
| X04 | [Signal-iOS #6015](https://github.com/signalapp/Signal-iOS/issues/6015) | 更新后数据库无法加载导致应用/通知同时失效 | F01/F16/F18 |
| X05 | [Signal-iOS #6036](https://github.com/signalapp/Signal-iOS/issues/6036) | 唯一约束和磁盘不足相关失败 | F16/F17 |
| X06 | [GRDB #678](https://github.com/groue/GRDB.swift/issues/678) | 迁移重复执行/重复列 | F18 |
| X07 | [GRDB #1516](https://github.com/groue/GRDB.swift/discussions/1516) | App 与 extension 共享 WAL 的锁定/崩溃风险 | F16/F17 |
| X08 | [GRDB #294](https://github.com/groue/GRDB.swift/issues/294) | 只读/备份路径失败 | F10/F12/F16 |
| X09 | [ZIPFoundation #282](https://github.com/weichsel/ZIPFoundation/issues/282)、[修复 #306](https://github.com/weichsel/ZIPFoundation/pull/306) | 符号链接路径穿越 | F12/F13/F20 |
| X10 | [flutter_secure_storage #709](https://github.com/juliansteenbakker/flutter_secure_storage/issues/709) | Keychain 缺项/Unexpected null | F11 |
| X11 | [flutter_secure_storage #743](https://github.com/juliansteenbakker/flutter_secure_storage/issues/743) | 设备锁定/后台 Keychain 读取失败 | F11/F20 |
| X12 | [flutter_secure_storage #960](https://github.com/juliansteenbakker/flutter_secure_storage/issues/960) | accessibility 迁移出现 null/兼容失败 | F11/F18 |
| X13 | [Joplin #14954](https://github.com/laurent22/joplin/issues/14954) | 长笔记编辑后内容丢失 | F01/F07/F25 |
| X14 | [Joplin #5153](https://github.com/laurent22/joplin/issues/5153) | SQLite database disk image malformed | F10/F12/F16 |
| X15 | [Joplin #15548](https://github.com/laurent22/joplin/issues/15548) | 修订/初始同步可能破坏数据且日志含敏感上下文 | F12/F18/F21 |
| X16 | [AppFlowy #8241](https://github.com/AppFlowy-IO/AppFlowy/issues/8241)、[#8112](https://github.com/AppFlowy-IO/AppFlowy/issues/8112) | iPhone 升级/迁移后本地数据不可访问 | F01/F12/F18 |
| X17 | [AppFlowy #4848](https://github.com/AppFlowy-IO/AppFlowy/issues/4848) | 跨端状态不同步导致数据丢失或损坏 | F02/F06/F07/F12 |
| X18 | [Firefox-iOS #34571](https://github.com/mozilla-mobile/firefox-ios/issues/34571) | 后台恢复的系统 quick action 路由未生效，Simulator 与真机还可能不同 | F01/F22/F28 |
| X19 | [Simplenote-iOS #1705](https://github.com/Automattic/simplenote-ios/issues/1705) | 同步恢复旧状态覆盖较新内容 | F02/F07/F17 |
| X20 | [flutter_local_notifications #2097](https://github.com/MaikuB/flutter_local_notifications/issues/2097)、[修复 #2112](https://github.com/MaikuB/flutter_local_notifications/pull/2112) | `presentSound` 的配置曾意外改变后台声音行为，说明 alert/presentation 与 sound 必须分开验证 | F03/F04/F21 |
| X21 | [Flutter #66779](https://github.com/flutter/flutter/issues/66779)、[#47563](https://github.com/flutter/flutter/issues/47563) | Flutter 调用默认 ADB streamed install 时可能在设备/模拟器连接或 Package Manager 状态异常下失败 | F28 |

issue 证明“失败确实会发生”，不证明 issue 中猜测的根因。只有能由代码、复现或修复提交交叉证明的原因才进入“已证实缺陷”。

## P0 证据包完整性

每行均包含 Apple/官方规则、两个独立成熟实现（至少一个原生 iOS）和一个失败案例；括号内说明主要证据。重复使用来源是因为这些功能属于同一条事务链，而不是减少独立性。

| 功能 | 官方规则 | 成熟实现 1 | 成熟实现 2 | 失败案例 | 完整性 |
|---|---|---|---|---|---|
| F01 | A05/A06 | R02 原生 iOS | R11 原生 iOS | X04/X18 | 满足 |
| F03 | A01/A02/A03/A06 | R01 iOS plugin | R02 原生 iOS | X01/X02 | 满足 |
| F04 | A02/A03/A04 | R01 iOS plugin | R02 原生 iOS | X20 | 满足 |
| F09 | A09 | R02 原生 iOS 数据事务 | R07 删除/修订 | X15/X19 | 满足 |
| F10 | A08/A09/A11 + S02/S03 | R02 原生 iOS | R03 原生 Swift | X03/X08 | 满足 |
| F11 | A10 + S05 | R04 原生 Swift | R06 iOS plugin | X10/X11/X12 | 满足 |
| F12 | A08/A09 + S03/S04 | R02 原生 iOS | R05 原生 Swift ZIP | X03/X09/X16 | 满足 |
| F15 | A07 | R01 iOS plugin | R02 原生 iOS | X02 | 满足 |
| F16 | A09 + S01/S02/S04 | R02 原生 iOS | R03 原生 Swift | X03/X05/X07 | 满足 |
| F17 | A01/A03/A06 | R01 iOS plugin | R02 原生 iOS | X01/X05 | 满足 |
| F18 | A09 + S01/S04 | R02 原生 iOS | R03 原生 Swift | X04/X06/X16 | 满足 |
| F19 | A01/A02/A03/A06 | R01 iOS plugin | R02 原生 iOS | X01/X18 | 满足 |
| F20 | A08/A09/A10/A11 | R02 原生 iOS | R04 原生 Swift | X09/X11 | 满足 |
| F21 | A13/A14 | R02 原生 iOS | R11 原生 iOS | X15 | 满足 |

## 采用结论

- 直接用于合同：A01–A14、S01–S06。
- 可借鉴实现/测试模式：R01、R03–R06、R12；实际复制前仍要核对 notice 和移除成本。
- 仅研究行为和测试：R02、R07–R10；许可证不允许本计划默认复制。
- MPL 特别评估：R11；本版只参考场景路由与 XCUITest 设计。
- 未选任何来源作为“整套替换方案”。当归的离线数据库、Dart outbox 和 iOS AlarmKit 组合没有一项候选能够无损替代。
