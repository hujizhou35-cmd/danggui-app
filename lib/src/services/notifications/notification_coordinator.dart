import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../domain/models.dart';

const _snoozeActionPrefix = 'danggui.snooze.';
const _supportedSnoozeMinutes = <int>[10, 30, 60];

final notificationStateRevisionProvider =
    NotifierProvider<NotificationStateRevision, int>(
      NotificationStateRevision.new,
    );

final class NotificationStateRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((
  ref,
) {
  final coordinator = NotificationCoordinator(
    () => ref.read(databaseProvider.future),
    onStateChanged: () {
      final notifier = ref.read(notificationStateRevisionProvider.notifier);
      notifier.bump();
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Narrow platform seam that keeps reminder behaviour testable without a
/// device or method-channel mocks.
abstract interface class NotificationGateway {
  bool get isSupported;
  String get platformName;
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  });
  Future<bool> requestPermissions();
  Future<bool?> permissionsGranted();
  Future<Set<int>> pendingNotificationIds();
  Future<void> schedule(LocalNotificationRequest request);
  Future<void> cancel(int notificationId);
}

/// Every string rendered by the operating system for a reminder.
///
/// Keeping this value in the platform seam makes locale selection and category
/// refreshes testable without invoking notification method channels.
final class NotificationPresentation {
  const NotificationPresentation({
    required this.localeTag,
    required this.emptyPlanBody,
    required this.channelName,
    required this.channelDescription,
    required this.snoozeActionLabels,
  });

  final String localeTag;
  final String emptyPlanBody;
  final String channelName;
  final String channelDescription;
  final Map<int, String> snoozeActionLabels;

  String snoozeLabel(int minutes) =>
      snoozeActionLabels[minutes] ?? '$minutes min';
}

final class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.scheduledAtUtc,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.defaultSnoozeMinutes,
    required this.payload,
  });

  final int notificationId;
  final String title;
  final String body;
  final DateTime scheduledAtUtc;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int defaultSnoozeMinutes;
  final String payload;
}

final class NotificationCoordinator {
  NotificationCoordinator(
    this._readDatabase, {
    NotificationGateway? gateway,
    DateTime Function()? nowUtc,
    String Function()? systemLocaleName,
    this._onStateChanged,
    this._retryBaseDelay = const Duration(minutes: 1),
  }) : _gateway = gateway ?? _FlutterNotificationGateway(),
       _nowUtc = nowUtc ?? _systemNowUtc,
       _systemLocaleName = systemLocaleName ?? _platformLocaleName;

  final Future<DangguiDatabase> Function() _readDatabase;
  final NotificationGateway _gateway;
  final DateTime Function() _nowUtc;
  final String Function() _systemLocaleName;
  final FutureOr<void> Function()? _onStateChanged;
  final Duration _retryBaseDelay;
  String? _initializedLocaleTag;
  NotificationPresentation? _presentation;
  bool _reconciling = false;
  bool _reconcileRequested = false;
  Completer<void>? _reconcileIdle;
  bool _interruptedJobsRecovered = false;
  bool _startupRescheduleComplete = false;
  Timer? _retryTimer;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> initialize() async {
    if (!_gateway.isSupported) return;
    final database = await _readDatabase();
    await _initializeForDatabase(database);
  }

  Future<void> _initializeForDatabase(DangguiDatabase database) async {
    final settings = await database
        .customSelect('SELECT locale_mode FROM app_settings WHERE id = 1')
        .getSingle();
    final presentation = _notificationPresentation(
      _localeModeByName(settings.read<String>('locale_mode')),
      systemLocaleName: _systemLocaleName(),
    );
    if (_initializedLocaleTag == presentation.localeTag) {
      _presentation = presentation;
      return;
    }
    await _gateway.initialize(
      onAction: (actionId, payload) {
        unawaited(_handleNotificationActionSafely(actionId, payload));
      },
      presentation: presentation,
    );
    _presentation = presentation;
    _initializedLocaleTag = presentation.localeTag;
  }

  Future<void> _handleNotificationActionSafely(
    String? actionId,
    String? payload,
  ) async {
    try {
      await handleNotificationAction(actionId, payload);
    } on Object {
      // The durable reminder/outbox transaction is retry-safe. A callback must
      // not surface an unhandled asynchronous error into the Flutter runtime.
    }
  }

  /// Requests ordinary notification permission only. It never requests exact
  /// alarm, full-screen, network, or critical-alert access.
  Future<bool> requestPermissions() async {
    if (!_gateway.isSupported) return true;
    await initialize();
    final granted = await _gateway.requestPermissions();
    if (granted) {
      await _restorePermissionDeniedReminders();
      await reconcile();
    }
    return granted;
  }

  Future<bool?> permissionsGranted() async {
    if (!_gateway.isSupported) return null;
    await initialize();
    return _gateway.permissionsGranted();
  }

  /// Checks first so the system prompt is only requested when necessary.
  Future<bool> ensurePermissionsForFutureReminder() async {
    if (await permissionsGranted() == true) return true;
    return requestPermissions();
  }

  /// Persists a permission result after a future reminder's first save. A
  /// denial pauses delivery but preserves the selected time.
  Future<void> applyPermissionResultForTask(
    String taskId, {
    required bool granted,
  }) async {
    if (!_gateway.isSupported) return;
    final database = await _readDatabase();
    final now = _nowMicros();
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT r.id, r.status, r.schedule_revision, r.scheduled_at_utc '
            'FROM reminders r JOIN tasks t ON t.id = r.task_id '
            'WHERE r.task_id = ? AND t.status = ?',
            variables: <Variable<Object>>[
              Variable.withString(taskId),
              Variable.withString(TaskStatus.active.name),
            ],
          )
          .getSingleOrNull();
      if (row == null || row.read<int>('scheduled_at_utc') <= now) return;
      final status = row.read<String>('status');
      if (granted && status == ReminderStatus.permissionDenied.name) {
        await _changePermissionState(
          database,
          row,
          taskId: taskId,
          granted: true,
          nowMicros: now,
        );
      } else if (!granted && status != ReminderStatus.permissionDenied.name) {
        await _changePermissionState(
          database,
          row,
          taskId: taskId,
          granted: false,
          nowMicros: now,
        );
      }
    });
    await reconcile();
  }

  Future<bool> handleNotificationAction(
    String? actionId,
    String? payload,
  ) async {
    final minutes = _minutesFromAction(actionId);
    final taskId = _taskIdFromPayload(payload);
    if (minutes == null || taskId == null) return false;
    return snoozeReminderForTask(taskId, minutes: minutes);
  }

  /// Passing null uses the persisted default (10, 30, or 60 minutes).
  Future<bool> snoozeReminderForTask(String taskId, {int? minutes}) async {
    final database = await _readDatabase();
    final nowUtc = _nowUtc().toUtc();
    final now = nowUtc.microsecondsSinceEpoch;
    var changed = false;
    await database.transaction(() async {
      final settings = await database
          .customSelect(
            'SELECT default_snooze_minutes FROM app_settings WHERE id = 1',
          )
          .getSingle();
      final resolvedMinutes =
          minutes ?? settings.read<int>('default_snooze_minutes');
      if (!_supportedSnoozeMinutes.contains(resolvedMinutes)) {
        throw ArgumentError.value(
          resolvedMinutes,
          'minutes',
          'Only 10, 30, or 60 minute snoozes are supported.',
        );
      }
      final reminder = await database
          .customSelect(
            'SELECT r.id, r.schedule_revision, r.status AS reminder_status, '
            't.status AS task_status '
            'FROM reminders r JOIN tasks t ON t.id = r.task_id '
            'WHERE r.task_id = ?',
            variables: <Variable<Object>>[Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (reminder == null ||
          reminder.read<String>('task_status') != TaskStatus.active.name) {
        return;
      }
      final reminderStatus = reminder.read<String>('reminder_status');
      if (reminderStatus != ReminderStatus.scheduled.name &&
          reminderStatus != ReminderStatus.expired.name) {
        return;
      }
      final reminderId = reminder.read<String>('id');
      final oldRevision = reminder.read<int>('schedule_revision');
      final revision = oldRevision + 1;
      final scheduledUtc = nowUtc.add(Duration(minutes: resolvedMinutes));
      final scheduledLocal = scheduledUtc.toLocal();
      final affected = await database.customUpdate(
        'UPDATE reminders SET scheduled_local_date_time = ?, '
        'scheduled_zone_id = ?, scheduled_at_utc = ?, snoozed_until_utc = ?, '
        'status = ?, pause_reason = NULL, snooze_count = snooze_count + 1, '
        'schedule_revision = ?, last_fired_at_utc = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 '
        'WHERE id = ? AND schedule_revision = ?',
        variables: <Variable<Object>>[
          Variable.withString(scheduledLocal.toIso8601String()),
          Variable.withString(scheduledLocal.timeZoneName),
          Variable.withInt(scheduledUtc.microsecondsSinceEpoch),
          Variable.withInt(scheduledUtc.microsecondsSinceEpoch),
          Variable.withString(ReminderStatus.scheduled.name),
          Variable.withInt(revision),
          Variable.withInt(now),
          Variable.withInt(now),
          Variable.withString(reminderId),
          Variable.withInt(oldRevision),
        ],
        updates: <TableInfo<Table, Object?>>{database.reminders},
      );
      if (affected != 1) return;
      await _insertOutboxJob(
        database,
        reminderId: reminderId,
        taskId: taskId,
        revision: revision,
        kind: PlatformJobKind.scheduleReminder,
        nowMicros: now,
      );
      changed = true;
    });
    if (changed) {
      await reconcile();
      await _onStateChanged?.call();
    }
    return changed;
  }

  /// Drains the durable platform-job outbox with stale-revision protection.
  Future<void> reconcile() async {
    if (!_gateway.isSupported) return;
    if (_reconciling) {
      _reconcileRequested = true;
      await _reconcileIdle?.future;
      return;
    }
    _reconciling = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    final idle = Completer<void>();
    _reconcileIdle = idle;
    try {
      do {
        _reconcileRequested = false;
        await _reconcileOnce();
      } while (_reconcileRequested);
      await _armRetryTimer();
    } finally {
      _reconciling = false;
      _reconcileIdle = null;
      idle.complete();
    }
  }

  Future<void> _reconcileOnce() async {
    final database = await _readDatabase();
    await _initializeForDatabase(database);
    final expirationCutoff = _nowMicros();
    await _expirePastReminders(database, expirationCutoff);
    final permission = await _gateway.permissionsGranted();
    if (permission == false) {
      await _markScheduledRemindersPermissionDenied(database);
    } else if (permission == true) {
      // Also recover when the user enabled notifications in system settings
      // instead of returning through the in-app permission button.
      await _restorePermissionDeniedReminders();
    }
    // Permission recovery can enqueue a job using a timestamp later than the
    // expiration cutoff above. Take a fresh value so that newly-created jobs
    // are drained during this same reconciliation pass.
    final now = _nowMicros();
    if (!_interruptedJobsRecovered) {
      await _recoverInterruptedJobs(database, now);
      _interruptedJobsRecovered = true;
    }
    if (!_startupRescheduleComplete) {
      _startupRescheduleComplete = await _rescheduleFutureRemindersAfterStart(
        database,
        now,
      );
    }
    final rows = await database
        .customSelect(
          'SELECT pj.id AS job_id, pj.kind, pj.attempts, '
          'pj.aggregate_revision, r.id AS reminder_id, r.task_id, '
          'r.scheduled_at_utc, r.sound_enabled, r.vibration_enabled, '
          'r.schedule_revision, r.status AS reminder_status, '
          't.status AS task_status, t.title, t.plan_text, '
          's.default_snooze_minutes '
          'FROM platform_jobs pj '
          'JOIN reminders r ON r.id = pj.aggregate_id '
          'JOIN tasks t ON t.id = r.task_id '
          'JOIN app_settings s ON s.id = 1 '
          'WHERE pj.status IN (?, ?) AND pj.next_attempt_at_utc <= ? '
          'ORDER BY pj.created_at_utc, pj.id LIMIT 64',
          variables: <Variable<Object>>[
            Variable.withString(PlatformJobStatus.pending.name),
            Variable.withString(PlatformJobStatus.failed.name),
            Variable.withInt(now),
          ],
        )
        .get();
    for (final row in rows) {
      await _runJob(database, row, now);
    }
    if (rows.length == 64) _reconcileRequested = true;
  }

  /// Makes an elapsed reminder a durable historical state instead of leaving
  /// it looking scheduled forever after the operating system has fired it.
  /// Permission-denied reminders also expire without catch-up delivery.
  Future<void> _expirePastReminders(DangguiDatabase database, int now) async {
    final rows = await database
        .customSelect(
          'SELECT r.id, r.schedule_revision '
          'FROM reminders r JOIN tasks t ON t.id = r.task_id '
          'WHERE r.scheduled_at_utc <= ? AND r.status IN (?, ?) '
          'AND t.status = ?',
          variables: <Variable<Object>>[
            Variable.withInt(now),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withString(ReminderStatus.permissionDenied.name),
            Variable.withString(TaskStatus.active.name),
          ],
        )
        .get();
    if (rows.isEmpty) return;

    // A one-shot request disappears from the plugin's pending list when the
    // platform receiver has displayed it. Cancelling only IDs that are still
    // pending prevents an inexact alarm delayed by Doze from appearing after
    // the reminder is marked expired, while preserving an already-visible
    // notification and its 10/30/60-minute snooze actions.
    final pendingIds = await _gateway.pendingNotificationIds();
    for (final row in rows) {
      final notificationId = _notificationId(row.read<String>('id'));
      if (pendingIds.contains(notificationId)) {
        await _gateway.cancel(notificationId);
      }
    }

    await database.transaction(() async {
      for (final row in rows) {
        final reminderId = row.read<String>('id');
        final previousRevision = row.read<int>('schedule_revision');
        final revision = previousRevision + 1;
        final changed = await database.customUpdate(
          'UPDATE reminders SET status = ?, pause_reason = NULL, '
          'schedule_revision = ?, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE id = ? '
          'AND schedule_revision = ? AND scheduled_at_utc <= ? '
          'AND status IN (?, ?)',
          variables: <Variable<Object>>[
            Variable.withString(ReminderStatus.expired.name),
            Variable.withInt(revision),
            Variable.withInt(now),
            Variable.withString(reminderId),
            Variable.withInt(previousRevision),
            Variable.withInt(now),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withString(ReminderStatus.permissionDenied.name),
          ],
          updates: <TableInfo<Table, Object?>>{database.reminders},
        );
        if (changed == 1) {
          await database.customStatement(
            'DELETE FROM notification_registrations WHERE reminder_id = ? '
            'AND schedule_revision <= ?',
            <Object?>[reminderId, previousRevision],
          );
        }
      }
    });
  }

  /// A persisted `running` row can only belong to an interrupted coordinator
  /// when a new process starts. Return it to the ordinary durable retry path
  /// before startup device-state repair decides which revisions it owns.
  Future<void> _recoverInterruptedJobs(
    DangguiDatabase database,
    int now,
  ) async {
    await database.customUpdate(
      'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
      'last_error_code = ?, updated_at_utc = ? WHERE status = ?',
      variables: <Variable<Object>>[
        Variable.withString(PlatformJobStatus.failed.name),
        Variable.withInt(now),
        const Variable<String>('interrupted_recovered'),
        Variable.withInt(now),
        Variable.withString(PlatformJobStatus.running.name),
      ],
      updates: <TableInfo<Table, Object?>>{database.platformJobs},
    );
  }

  /// Rebuilds device-owned notification state once per process start.
  ///
  /// Android may remove alarms when an application is force-stopped while the
  /// durable outbox correctly remains [PlatformJobStatus.succeeded]. Reusing
  /// the same platform notification id makes this operation idempotent. Jobs
  /// still owned by the outbox are excluded so the two recovery paths cannot
  /// schedule the same revision in one reconciliation pass.
  Future<bool> _rescheduleFutureRemindersAfterStart(
    DangguiDatabase database,
    int now,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT r.id AS reminder_id, r.task_id, r.scheduled_at_utc, '
          'r.sound_enabled, r.vibration_enabled, '
          'r.schedule_revision AS aggregate_revision, t.title, t.plan_text, '
          's.default_snooze_minutes, nr.platform_notification_id '
          'FROM reminders r '
          'JOIN tasks t ON t.id = r.task_id '
          'JOIN app_settings s ON s.id = 1 '
          'LEFT JOIN notification_registrations nr '
          'ON nr.reminder_id = r.id AND nr.platform = ? '
          'AND nr.schedule_revision = r.schedule_revision '
          'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ? '
          'AND NOT EXISTS ('
          'SELECT 1 FROM platform_jobs active_job '
          'WHERE active_job.aggregate_id = r.id '
          'AND active_job.aggregate_revision = r.schedule_revision '
          'AND active_job.status IN (?, ?, ?)) '
          'ORDER BY r.scheduled_at_utc, r.id',
          variables: <Variable<Object>>[
            Variable.withString(_gateway.platformName),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withInt(now),
            Variable.withString(TaskStatus.active.name),
            Variable.withString(PlatformJobStatus.pending.name),
            Variable.withString(PlatformJobStatus.failed.name),
            Variable.withString(PlatformJobStatus.running.name),
          ],
        )
        .get();
    var complete = true;
    for (final row in rows) {
      try {
        final scheduled = await _schedule(
          database,
          row,
          now,
          notificationId: row.readNullable<int>('platform_notification_id'),
        );
        complete = scheduled && complete;
      } on Object {
        // A startup repair is derived device state, not a new business event.
        // Leave it incomplete so a later reconcile retries without creating a
        // duplicate or misleading outbox job.
        complete = false;
      }
    }
    return complete;
  }

  Future<void> _runJob(DangguiDatabase database, QueryRow row, int now) async {
    final jobId = row.read<String>('job_id');
    final attempts = row.read<int>('attempts') + 1;
    if (row.read<int>('aggregate_revision') !=
        row.read<int>('schedule_revision')) {
      await _finishJob(database, jobId, now, code: 'stale_revision_discarded');
      return;
    }
    await database.customStatement(
      'UPDATE platform_jobs SET status = ?, attempts = ?, updated_at_utc = ? '
      'WHERE id = ?',
      <Object?>[PlatformJobStatus.running.name, attempts, now, jobId],
    );
    try {
      final kind = row.read<String>('kind');
      String? completionCode;
      if (kind == PlatformJobKind.cancelReminder.name) {
        await _cancel(database, row);
      } else if (kind == PlatformJobKind.scheduleReminder.name ||
          kind == PlatformJobKind.refreshReminderLocale.name) {
        final eligible =
            row.read<String>('reminder_status') ==
                ReminderStatus.scheduled.name &&
            row.read<String>('task_status') == TaskStatus.active.name;
        if (!eligible) {
          await _gateway.cancel(
            _notificationId(row.read<String>('reminder_id')),
          );
          completionCode = 'ineligible_state_discarded';
        } else if (!await _schedule(database, row, now)) {
          completionCode = 'stale_after_platform_call';
        }
      }
      await _finishJob(database, jobId, now, code: completionCode);
    } on Object catch (error) {
      final cappedAttempts = attempts.clamp(1, 8);
      final retryDelay = _retryBaseDelay * (1 << (cappedAttempts - 1));
      final retryAt = now + retryDelay.inMicroseconds;
      await database.customStatement(
        'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
        'last_error_code = ?, updated_at_utc = ? WHERE id = ?',
        <Object?>[
          PlatformJobStatus.failed.name,
          retryAt,
          _errorCode(error),
          now,
          jobId,
        ],
      );
    }
  }

  Future<void> _armRetryTimer() async {
    if (_disposed) return;
    final database = await _readDatabase();
    final row = await database
        .customSelect(
          'SELECT MIN(next_attempt_at_utc) AS retry_at FROM platform_jobs '
          'WHERE status IN (?, ?)',
          variables: <Variable<Object>>[
            Variable.withString(PlatformJobStatus.pending.name),
            Variable.withString(PlatformJobStatus.failed.name),
          ],
        )
        .getSingle();
    final retryAt = row.readNullable<int>('retry_at');
    if (retryAt == null || _disposed) return;
    final delayMicros = retryAt - _nowMicros();
    final delay = Duration(microseconds: delayMicros > 0 ? delayMicros : 0);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_disposed) unawaited(_retryAfterTimer());
    });
  }

  Future<void> _retryAfterTimer() async {
    try {
      await reconcile();
    } on Object {
      // Failures before an individual outbox job is claimed (database open,
      // plugin initialization, permission query) are not recorded by _runJob.
      // Keep a bounded process-local wake-up instead of leaking an unhandled
      // Future or abandoning the durable queue until the next lifecycle event.
      if (_disposed) return;
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryBaseDelay, () {
        _retryTimer = null;
        if (!_disposed) unawaited(_retryAfterTimer());
      });
    }
  }

  Future<bool> _schedule(
    DangguiDatabase database,
    QueryRow row,
    int now, {
    int? notificationId,
  }) async {
    final scheduledAt = row.read<int>('scheduled_at_utc');
    final reminderId = row.read<String>('reminder_id');
    final id = notificationId ?? _notificationId(reminderId);
    if (scheduledAt <= now) {
      await _gateway.cancel(id);
      return true;
    }
    final plan = row.read<String>('plan_text').trim();
    final presentation =
        _presentation ??
        _notificationPresentation(
          LocaleMode.system,
          systemLocaleName: _systemLocaleName(),
        );
    await _gateway.schedule(
      LocalNotificationRequest(
        notificationId: id,
        title: row.read<String>('title'),
        body: plan.isEmpty ? presentation.emptyPlanBody : plan,
        scheduledAtUtc: DateTime.fromMicrosecondsSinceEpoch(
          scheduledAt,
          isUtc: true,
        ),
        soundEnabled: row.read<bool>('sound_enabled'),
        vibrationEnabled: row.read<bool>('vibration_enabled'),
        defaultSnoozeMinutes: row.read<int>('default_snooze_minutes'),
        payload: 'task:${row.read<String>('task_id')}',
      ),
    );

    // The platform call yields. Re-read before committing registration so an
    // edit made during that call cannot make this stale schedule authoritative.
    final current = await database
        .customSelect(
          'SELECT schedule_revision, status FROM reminders WHERE id = ?',
          variables: <Variable<Object>>[Variable.withString(reminderId)],
        )
        .getSingleOrNull();
    final revision = row.read<int>('aggregate_revision');
    if (current == null ||
        current.read<int>('schedule_revision') != revision ||
        current.read<String>('status') != ReminderStatus.scheduled.name) {
      await _gateway.cancel(id);
      return false;
    }
    await database.customStatement(
      'INSERT INTO notification_registrations '
      '(reminder_id, platform, platform_notification_id, schedule_revision, '
      'scheduled_locale, registered_at_utc, last_error_code) '
      'VALUES (?, ?, ?, ?, ?, ?, NULL) '
      'ON CONFLICT(reminder_id) DO UPDATE SET '
      'platform = excluded.platform, '
      'platform_notification_id = excluded.platform_notification_id, '
      'schedule_revision = excluded.schedule_revision, '
      'scheduled_locale = excluded.scheduled_locale, '
      'registered_at_utc = excluded.registered_at_utc, '
      'last_error_code = NULL',
      <Object?>[
        reminderId,
        _gateway.platformName,
        id,
        revision,
        presentation.localeTag,
        now,
      ],
    );
    return true;
  }

  Future<void> _cancel(DangguiDatabase database, QueryRow row) async {
    final reminderId = row.read<String>('reminder_id');
    final revision = row.read<int>('aggregate_revision');
    await _gateway.cancel(_notificationId(reminderId));
    await database.customStatement(
      'DELETE FROM notification_registrations '
      'WHERE reminder_id = ? AND schedule_revision <= ?',
      <Object?>[reminderId, revision],
    );
  }

  Future<void> _restorePermissionDeniedReminders() async {
    final database = await _readDatabase();
    final now = _nowMicros();
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            'SELECT r.id, r.task_id, r.status, r.schedule_revision, '
            'r.scheduled_at_utc FROM reminders r '
            'JOIN tasks t ON t.id = r.task_id '
            'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ?',
            variables: <Variable<Object>>[
              Variable.withString(ReminderStatus.permissionDenied.name),
              Variable.withInt(now),
              Variable.withString(TaskStatus.active.name),
            ],
          )
          .get();
      for (final row in rows) {
        await _changePermissionState(
          database,
          row,
          taskId: row.read<String>('task_id'),
          granted: true,
          nowMicros: now,
        );
      }
    });
  }

  Future<void> _markScheduledRemindersPermissionDenied(
    DangguiDatabase database,
  ) async {
    final now = _nowMicros();
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            'SELECT r.id, r.task_id, r.status, r.schedule_revision, '
            'r.scheduled_at_utc FROM reminders r '
            'JOIN tasks t ON t.id = r.task_id '
            'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ?',
            variables: <Variable<Object>>[
              Variable.withString(ReminderStatus.scheduled.name),
              Variable.withInt(now),
              Variable.withString(TaskStatus.active.name),
            ],
          )
          .get();
      for (final row in rows) {
        await _changePermissionState(
          database,
          row,
          taskId: row.read<String>('task_id'),
          granted: false,
          nowMicros: now,
        );
      }
    });
  }

  static Future<void> _changePermissionState(
    DangguiDatabase database,
    QueryRow row, {
    required String taskId,
    required bool granted,
    required int nowMicros,
  }) async {
    final reminderId = row.read<String>('id');
    final revision = row.read<int>('schedule_revision') + 1;
    await database.customStatement(
      'UPDATE reminders SET status = ?, pause_reason = ?, '
      'schedule_revision = ?, updated_at_utc = ?, '
      'row_version = row_version + 1 WHERE id = ?',
      <Object?>[
        granted
            ? ReminderStatus.scheduled.name
            : ReminderStatus.permissionDenied.name,
        granted ? null : ReminderPauseReason.permissionDenied.name,
        revision,
        nowMicros,
        reminderId,
      ],
    );
    await _insertOutboxJob(
      database,
      reminderId: reminderId,
      taskId: taskId,
      revision: revision,
      kind: granted
          ? PlatformJobKind.scheduleReminder
          : PlatformJobKind.cancelReminder,
      nowMicros: nowMicros,
    );
  }

  static Future<void> _insertOutboxJob(
    DangguiDatabase database, {
    required String reminderId,
    required String taskId,
    required int revision,
    required PlatformJobKind kind,
    required int nowMicros,
  }) async {
    final dedupe = '${kind.name}:$reminderId:$revision';
    await database.customStatement(
      'INSERT OR IGNORE INTO platform_jobs '
      '(id, kind, aggregate_id, aggregate_revision, dedupe_key, payload_json, '
      'status, attempts, next_attempt_at_utc, created_at_utc, updated_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
      <Object?>[
        'notification:$dedupe',
        kind.name,
        reminderId,
        revision,
        dedupe,
        jsonEncode(<String, Object?>{'taskId': taskId}),
        PlatformJobStatus.pending.name,
        nowMicros,
        nowMicros,
        nowMicros,
      ],
    );
  }

  static Future<void> _finishJob(
    DangguiDatabase database,
    String jobId,
    int now, {
    String? code,
  }) {
    return database.customStatement(
      'UPDATE platform_jobs SET status = ?, last_error_code = ?, '
      'updated_at_utc = ? WHERE id = ?',
      <Object?>[PlatformJobStatus.succeeded.name, code, now, jobId],
    );
  }

  int _nowMicros() => _nowUtc().toUtc().microsecondsSinceEpoch;
}

final class _FlutterNotificationGateway implements NotificationGateway {
  _FlutterNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  NotificationPresentation? _presentation;
  bool _launchResponseHandled = false;

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  String get platformName => Platform.isAndroid ? 'android' : 'ios';

  @override
  Future<void> initialize({
    required void Function(String? actionId, String? payload) onAction,
    required NotificationPresentation presentation,
  }) async {
    _presentation = presentation;
    tz_data.initializeTimeZones();
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('ic_stat_danggui'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          for (final preferred in _supportedSnoozeMinutes)
            DarwinNotificationCategory(
              _categoryId(preferred),
              actions: <DarwinNotificationAction>[
                for (final minutes in _orderedSnoozeMinutes(preferred))
                  DarwinNotificationAction.plain(
                    '$_snoozeActionPrefix$minutes',
                    presentation.snoozeLabel(minutes),
                    options: const <DarwinNotificationActionOption>{
                      DarwinNotificationActionOption.foreground,
                    },
                  ),
              ],
            ),
        ],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        onAction(response.actionId, response.payload);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (!_launchResponseHandled &&
        launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _launchResponseHandled = true;
      onAction(launchResponse.actionId, launchResponse.payload);
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<bool?> permissionsGranted() async {
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    }
    final options = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    return options?.isEnabled;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    final requests = await _plugin.pendingNotificationRequests();
    return <int>{for (final request in requests) request.id};
  }

  @override
  Future<void> schedule(LocalNotificationRequest request) {
    final presentation = _presentation;
    if (presentation == null) {
      throw StateError('Notification gateway has not been initialized.');
    }
    final channelSuffix =
        '${request.soundEnabled ? 'sound' : 'silent'}-'
        '${request.vibrationEnabled ? 'vibrate' : 'steady'}';
    return _plugin.zonedSchedule(
      id: request.notificationId,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAtUtc, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'danggui-reminders-$channelSuffix',
          presentation.channelName,
          channelDescription: presentation.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_stat_danggui',
          playSound: request.soundEnabled,
          enableVibration: request.vibrationEnabled,
          actions: <AndroidNotificationAction>[
            for (final minutes in _orderedSnoozeMinutes(
              request.defaultSnoozeMinutes,
            ))
              AndroidNotificationAction(
                '$_snoozeActionPrefix$minutes',
                presentation.snoozeLabel(minutes),
                showsUserInterface: true,
              ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: request.soundEnabled,
          threadIdentifier: 'danggui-reminders',
          categoryIdentifier: _categoryId(request.defaultSnoozeMinutes),
        ),
      ),
      // Deliberately inexact: no exact-alarm permission is requested.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payload,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);
}

DateTime _systemNowUtc() => DateTime.now().toUtc();

String _platformLocaleName() => Platform.localeName;

LocaleMode _localeModeByName(String value) => LocaleMode.values.firstWhere(
  (mode) => mode.name == value,
  orElse: () => LocaleMode.system,
);

NotificationPresentation _notificationPresentation(
  LocaleMode localeMode, {
  required String systemLocaleName,
}) {
  final languageCode = switch (localeMode) {
    LocaleMode.zhHans => 'zh',
    LocaleMode.en => 'en',
    LocaleMode.ja => 'ja',
    LocaleMode.ru => 'ru',
    LocaleMode.system => _supportedLanguageCode(systemLocaleName),
  };
  final l10n = lookupAppLocalizations(Locale(languageCode));
  return NotificationPresentation(
    localeTag: languageCode,
    emptyPlanBody: l10n.notificationEmptyBody,
    channelName: l10n.notificationChannelName,
    channelDescription: l10n.notificationChannelDescription,
    snoozeActionLabels: <int, String>{
      10: l10n.minutes10,
      30: l10n.minutes30,
      60: l10n.minutes60,
    },
  );
}

String _supportedLanguageCode(String localeName) {
  final normalized = localeName.trim().toLowerCase().replaceAll('-', '_');
  final languageCode = normalized.split('_').first;
  return const <String>{'zh', 'en', 'ja', 'ru'}.contains(languageCode)
      ? languageCode
      : 'zh';
}

List<int> _orderedSnoozeMinutes(int preferred) => <int>[
  if (_supportedSnoozeMinutes.contains(preferred)) preferred,
  for (final minutes in _supportedSnoozeMinutes)
    if (minutes != preferred) minutes,
];

String _categoryId(int preferred) =>
    'danggui-reminders-snooze-'
    '${_supportedSnoozeMinutes.contains(preferred) ? preferred : 10}';

int? _minutesFromAction(String? actionId) {
  if (actionId == null || !actionId.startsWith(_snoozeActionPrefix)) {
    return null;
  }
  final value = int.tryParse(actionId.substring(_snoozeActionPrefix.length));
  return _supportedSnoozeMinutes.contains(value) ? value : null;
}

String? _taskIdFromPayload(String? payload) {
  const prefix = 'task:';
  if (payload == null || !payload.startsWith(prefix)) return null;
  final value = payload.substring(prefix.length).trim();
  return value.isEmpty ? null : value;
}

int _notificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

String _errorCode(Object error) {
  final type = error.runtimeType.toString();
  final normalized = type.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
