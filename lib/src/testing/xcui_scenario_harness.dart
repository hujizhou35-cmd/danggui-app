import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../application/app_store.dart';
import '../data/database.dart';
import '../domain/models.dart';
import '../services/backup/backup_service.dart';
import '../services/notifications/local_time_zone.dart';
import '../services/notifications/notification_coordinator.dart';

/// Runs cross-module contracts from a real iOS application process.
///
/// The dedicated `xcui_main.dart` entrypoint only enables this surface in debug
/// builds launched by RunnerUITests.
/// It deliberately uses the production SQLite and backup implementations while
/// replacing their storage roots and notification delivery with deterministic
/// test boundaries. Each scenario starts from its own empty directory, so the
/// contracts do not depend on XCTest execution order or a shared app container.
void runDangguiXcuiScenario(String scenario) {
  final notificationGateway = _HarnessNotificationGateway();
  final workspace = XcuiScenarioWorkspace.forScenario(scenario);
  runApp(
    ProviderScope(
      overrides: [
        ...dangguiXcuiScenarioStorageOverrides(workspace),
        appLocalTimeZoneResolverProvider.overrideWithValue(
          const _HarnessTimeZoneResolver(),
        ),
        _harnessNotificationGatewayProvider.overrideWithValue(
          notificationGateway,
        ),
        notificationCoordinatorProvider.overrideWith((ref) {
          final coordinator = NotificationCoordinator(
            () => ref.read(databaseProvider.future),
            gateway: ref.read(_harnessNotificationGatewayProvider),
            systemLocaleName: () => 'en_US',
          );
          ref.onDispose(coordinator.dispose);
          return coordinator;
        }),
      ],
      child: _XcuiScenarioApp(scenario: scenario),
    ),
  );
}

/// A bounded, test-only storage root for one XCUITest scenario.
///
/// The scenario name is mapped through an allow-list instead of being appended
/// directly to a path. [reset] removes the complete scenario directory before
/// the production database provider opens SQLite, which also removes stale WAL,
/// shared-memory, rollback-journal, recovery and backup artifacts.
final class XcuiScenarioWorkspace {
  XcuiScenarioWorkspace._({
    required this.suiteDirectory,
    required this.rootDirectory,
  });

  factory XcuiScenarioWorkspace.forScenario(
    String scenario, {
    Directory? temporaryRoot,
  }) {
    final slug = switch (scenario) {
      'task-reminder-trash-restore' => 'task-reminder-trash-restore',
      'backup-restore-reminder-rebuild' => 'backup-restore-reminder-rebuild',
      _ => throw ArgumentError.value(
        scenario,
        'scenario',
        'Unknown XCUITest scenario.',
      ),
    };
    final base = (temporaryRoot ?? Directory.systemTemp).absolute;
    final suite = Directory(
      p.normalize(p.join(base.path, 'danggui-xcui-scenarios-v1')),
    );
    final root = Directory(p.normalize(p.join(suite.path, slug)));
    if (!p.isWithin(suite.path, root.path)) {
      throw StateError('XCUITest scenario path escaped its storage suite.');
    }
    return XcuiScenarioWorkspace._(suiteDirectory: suite, rootDirectory: root);
  }

  final Directory suiteDirectory;
  final Directory rootDirectory;
  Future<void>? _launchPreparation;

  File get databaseFile =>
      File(p.join(rootDirectory.path, 'database', 'danggui.sqlite'));

  Directory get temporaryDirectory =>
      Directory(p.join(rootDirectory.path, 'temporary'));

  List<File> get databaseAndSidecars => <File>[
    databaseFile,
    File('${databaseFile.path}-wal'),
    File('${databaseFile.path}-shm'),
    File('${databaseFile.path}-journal'),
  ];

  Future<void> prepareForLaunch() => _launchPreparation ??= reset();

  Future<void> reset() async {
    final suiteType = await FileSystemEntity.type(
      suiteDirectory.path,
      followLinks: false,
    );
    if (suiteType == FileSystemEntityType.link ||
        (suiteType != FileSystemEntityType.notFound &&
            suiteType != FileSystemEntityType.directory)) {
      throw StateError('XCUITest storage suite is not a real directory.');
    }
    await suiteDirectory.create(recursive: true);

    final rootType = await FileSystemEntity.type(
      rootDirectory.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.directory) {
      await rootDirectory.delete(recursive: true);
    } else if (rootType == FileSystemEntityType.link) {
      await Link(rootDirectory.path).delete();
    } else if (rootType != FileSystemEntityType.notFound) {
      await File(rootDirectory.path).delete();
    }

    await databaseFile.parent.create(recursive: true);
    await temporaryDirectory.create(recursive: true);
  }
}

/// Storage overrides shared by the real XCUITest harness and its Windows tests.
///
/// Only the file locations are substituted. Database recovery, migrations,
/// integrity checks and backup/restore still run through their production
/// implementations.
List<Override> dangguiXcuiScenarioStorageOverrides(
  XcuiScenarioWorkspace workspace,
) => <Override>[
  databaseFileProvider.overrideWith((ref) async {
    // A provider invalidation must reopen the current database, not erase it.
    // The workspace owns exactly one startup cleanup future per app launch.
    await workspace.prepareForLaunch();
    return workspace.databaseFile;
  }),
  backupServiceProvider.overrideWith((ref) {
    return BackupService(
      readDatabase: () => ref.read(databaseProvider.future),
      readDatabaseFile: () => ref.read(databaseFileProvider.future),
      invalidateDatabase: () {
        ref.invalidate(databaseProvider);
        ref.invalidate(appStoreProvider);
      },
      readTemporaryDirectory: () async => workspace.temporaryDirectory,
    );
  }),
];

final _harnessNotificationGatewayProvider =
    Provider<_HarnessNotificationGateway>(
      (ref) =>
          throw StateError('XCUITest notification gateway is not installed.'),
    );

final class _XcuiScenarioApp extends ConsumerStatefulWidget {
  const _XcuiScenarioApp({required this.scenario});

  final String scenario;

  @override
  ConsumerState<_XcuiScenarioApp> createState() => _XcuiScenarioAppState();
}

final class _XcuiScenarioAppState extends ConsumerState<_XcuiScenarioApp> {
  var _result = 'XCUITEST RUNNING';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      switch (widget.scenario) {
        case 'task-reminder-trash-restore':
          await _taskReminderTrashRestore();
          break;
        case 'backup-restore-reminder-rebuild':
          await _backupRestoreReminderRebuild();
          break;
        default:
          throw StateError('unknown-scenario');
      }
      if (mounted) {
        setState(() => _result = 'XCUITEST PASS ${widget.scenario}');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () =>
              _result = 'XCUITEST FAIL ${widget.scenario} ${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _taskReminderTrashRestore() async {
    await ref.read(appStoreProvider.future);
    final controller = ref.read(appStoreProvider.notifier);
    var database = await ref.read(databaseProvider.future);
    await _requireEmptyScenarioDatabase(database);
    final taskId = await controller.createTask(
      title: 'XCUITest reminder trash restore',
      reminderAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
    );
    database = await ref.read(databaseProvider.future);
    var reminder = await _reminder(database, taskId);
    _require(reminder.read<String>('status') == ReminderStatus.scheduled.name);

    await controller.deleteTask(taskId);
    database = await ref.read(databaseProvider.future);
    reminder = await _reminder(database, taskId);
    final trashedTask = await _taskStatus(database, taskId);
    _require(trashedTask == TaskStatus.trashed.name);
    _require(reminder.read<String>('status') == ReminderStatus.paused.name);

    await controller.restoreTask(taskId);
    database = await ref.read(databaseProvider.future);
    reminder = await _reminder(database, taskId);
    _require(await _taskStatus(database, taskId) == TaskStatus.active.name);
    _require(reminder.read<String>('status') == ReminderStatus.scheduled.name);
    _require(reminder.read<int>('schedule_revision') >= 3);
    _require(
      await _registrationCount(database, reminder.read<String>('id')) == 1,
    );
  }

  Future<void> _backupRestoreReminderRebuild() async {
    await ref.read(appStoreProvider.future);
    final controller = ref.read(appStoreProvider.notifier);
    var database = await ref.read(databaseProvider.future);
    await _requireEmptyScenarioDatabase(database);
    final restoredTaskId = await controller.createTask(
      title: 'XCUITest restored reminder',
      reminderAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
    );
    database = await ref.read(databaseProvider.future);
    final before = await _reminder(database, restoredTaskId);
    final reminderId = before.read<String>('id');
    final revision = before.read<int>('schedule_revision');

    final backup = await ref.read(backupServiceProvider).create();
    await controller.deleteTask(restoredTaskId);
    final replacedTaskId = await controller.createTask(
      title: 'XCUITest reminder absent from backup',
      reminderAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
    );
    database = await ref.read(databaseProvider.future);
    final replacedReminder = await _reminder(database, replacedTaskId);
    final replacedReminderId = replacedReminder.read<String>('id');
    final gateway = ref.read(_harnessNotificationGatewayProvider);
    _require(gateway.pendingReminderIds().contains(replacedReminderId));
    _require(!gateway.pendingReminderIds().contains(reminderId));

    await ref.read(backupServiceProvider).restore(backup.file);
    await ref.read(appStoreProvider.future);
    database = await ref.read(databaseProvider.future);
    final restored = await _reminder(database, restoredTaskId);
    _require(
      await _taskStatus(database, restoredTaskId) == TaskStatus.active.name,
    );
    _require(restored.read<String>('id') == reminderId);
    _require(restored.read<int>('schedule_revision') == revision);
    _require(await _registrationCount(database, reminderId) == 0);
    _require(await _pendingJobCount(database, reminderId, revision) == 1);
    _require(gateway.pendingReminderIds().contains(replacedReminderId));

    await ref.read(notificationCoordinatorProvider).reconcile();
    database = await ref.read(databaseProvider.future);
    _require(await _registrationCount(database, reminderId) == 1);
    _require(await _succeededJobCount(database, reminderId, revision) == 1);
    final pendingReminderIds = gateway.pendingReminderIds();
    _require(!pendingReminderIds.contains(replacedReminderId));
    _require(pendingReminderIds.length == 1);
    _require(pendingReminderIds.single == reminderId);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Semantics(
            label: _result,
            identifier: 'xcui-scenario-result',
            excludeSemantics: true,
            child: Text(
              _result,
              textAlign: TextAlign.center,
              key: const ValueKey<String>('xcui-scenario-result'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<QueryRow> _reminder(DangguiDatabase database, String taskId) => database
    .customSelect(
      'SELECT id, status, schedule_revision FROM reminders WHERE task_id = ?',
      variables: [Variable.withString(taskId)],
    )
    .getSingle();

Future<void> _requireEmptyScenarioDatabase(DangguiDatabase database) async {
  for (final table in const <String>[
    'tasks',
    'reminders',
    'notification_registrations',
    'platform_jobs',
  ]) {
    final row = await database
        .customSelect('SELECT COUNT(*) AS total FROM $table')
        .getSingle();
    _require(row.read<int>('total') == 0);
  }
}

Future<String> _taskStatus(DangguiDatabase database, String taskId) async =>
    (await database
            .customSelect(
              'SELECT status FROM tasks WHERE id = ?',
              variables: [Variable.withString(taskId)],
            )
            .getSingle())
        .read<String>('status');

Future<int> _registrationCount(
  DangguiDatabase database,
  String reminderId,
) async =>
    (await database
            .customSelect(
              'SELECT COUNT(*) AS total FROM notification_registrations '
              'WHERE reminder_id = ?',
              variables: [Variable.withString(reminderId)],
            )
            .getSingle())
        .read<int>('total');

Future<int> _pendingJobCount(
  DangguiDatabase database,
  String reminderId,
  int revision,
) => _jobCount(database, reminderId, revision, PlatformJobStatus.pending);

Future<int> _succeededJobCount(
  DangguiDatabase database,
  String reminderId,
  int revision,
) => _jobCount(database, reminderId, revision, PlatformJobStatus.succeeded);

Future<int> _jobCount(
  DangguiDatabase database,
  String reminderId,
  int revision,
  PlatformJobStatus status,
) async =>
    (await database
            .customSelect(
              'SELECT COUNT(*) AS total FROM platform_jobs '
              'WHERE aggregate_id = ? AND aggregate_revision = ? AND status = ?',
              variables: [
                Variable.withString(reminderId),
                Variable.withInt(revision),
                Variable.withString(status.name),
              ],
            )
            .getSingle())
        .read<int>('total');

void _require(bool condition) {
  if (!condition) throw StateError('contract-mismatch');
}

final class _HarnessTimeZoneResolver implements LocalTimeZoneResolver {
  const _HarnessTimeZoneResolver();

  @override
  Future<String> currentIdentifier(DateTime localInstant) async =>
      'America/Los_Angeles';
}

final class _HarnessNotificationGateway
    implements NotificationGateway, PendingNotificationPayloadGateway {
  final _pending = <int, String?>{};

  Set<String> pendingReminderIds() => _pending.values
      .map(ReminderNotificationActionIdentity.tryDecode)
      .whereType<ReminderNotificationActionIdentity>()
      .map((identity) => identity.reminderId)
      .toSet();

  @override
  bool get isSupported => true;

  @override
  String get platformName => 'xcui-simulator-contract';

  @override
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  }) async {}

  @override
  Future<bool?> permissionsGranted() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<Set<int>> pendingNotificationIds() async => _pending.keys.toSet();

  @override
  Future<List<PendingLocalNotificationSnapshot>>
  pendingNotificationSnapshots() async => <PendingLocalNotificationSnapshot>[
    for (final entry in _pending.entries)
      PendingLocalNotificationSnapshot(
        notificationId: entry.key,
        payload: entry.value,
      ),
  ];

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    _pending[request.notificationId] = request.payload;
  }

  @override
  Future<void> cancel(int notificationId) async {
    _pending.remove(notificationId);
  }
}
