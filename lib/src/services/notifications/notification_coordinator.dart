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
import '../../data/device_alarm_generation_store.dart';
import '../../domain/models.dart';
import '../platform_mutation_gate.dart';
import 'native_alarm_platform.dart';

const _snoozeActionPrefix = 'danggui.snooze.';
const _supportedSnoozeMinutes = <int>[10, 30, 60];
const _lateDeliveryWindow = Duration(minutes: 15);
const _iosOrdinaryNotificationCapacity = 60;
final _defaultVibrationPattern = Int64List.fromList(<int>[0, 400, 200, 400]);

final notificationStateRevisionProvider =
    NotifierProvider<NotificationStateRevision, int>(
      NotificationStateRevision.new,
    );

final notificationOpenIntentProvider =
    NotifierProvider<NotificationOpenIntentController, NotificationOpenIntent?>(
      NotificationOpenIntentController.new,
    );

/// A one-shot, monotonically identified navigation request produced by a
/// notification body tap. A null [taskId] deliberately means "open the task
/// list": the referenced task was deleted, restored into another identity, or
/// otherwise is no longer safe to address directly.
final class NotificationOpenIntent {
  const NotificationOpenIntent({required this.sequence, this.taskId});

  final int sequence;
  final String? taskId;
}

final class NotificationOpenIntentController
    extends Notifier<NotificationOpenIntent?> {
  var _nextSequence = 0;

  @override
  NotificationOpenIntent? build() => null;

  void dispatch(String? taskId) {
    _nextSequence += 1;
    state = NotificationOpenIntent(sequence: _nextSequence, taskId: taskId);
  }

  void consume(int sequence) {
    if (state?.sequence == sequence) state = null;
  }
}

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
    onOpenRequested: (taskId) {
      ref.read(notificationOpenIntentProvider.notifier).dispatch(taskId);
    },
    mutationGate: ref.read(platformMutationGateProvider),
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

/// Payload-bearing view of ordinary local notifications.
///
/// iOS removes one-shot requests after delivery, so startup reconciliation
/// must compare the immutable v2 identity while a request is still pending;
/// an integer notification ID alone cannot distinguish an edited revision.
final class PendingLocalNotificationSnapshot {
  const PendingLocalNotificationSnapshot({
    required this.notificationId,
    required this.payload,
  });

  final int notificationId;
  final String? payload;
}

/// Optional seam so lightweight/legacy gateways remain source-compatible.
abstract interface class PendingNotificationPayloadGateway {
  Future<List<PendingLocalNotificationSnapshot>> pendingNotificationSnapshots();
}

/// Optional platform capability seam used by the production gateway and by
/// focused tests. Keeping it separate preserves simple notification fakes.
abstract interface class ReminderCapabilityGateway {
  Future<ReminderDeliveryCapabilities> deliveryCapabilities({
    required bool soundEnabled,
    required bool vibrationEnabled,
  });

  Future<bool> requestExactAlarmPermission();
}

/// Optional native alarm seam. Sound-enabled reminders use the operating
/// system's alarm facilities, while silent reminders keep the ordinary local
/// notification path. Keeping this separate avoids widening lightweight test
/// fakes that only exercise local notifications.
abstract interface class NativeReminderGateway {
  Future<NativeAlarmCapabilities> nativeAlarmCapabilities();
  Future<bool> requestAlarmAuthorization();
  Future<bool> requestFullScreenPermission();
  Future<void> openNotificationSettings();
  Future<void> openAlarmSoundSettings();
  Future<bool> openOemAutostartSettings();
  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    required bool vibrationEnabled,
  });
  Future<void> cancelReminder({
    required String reminderId,
    required int notificationId,
    String? deviceGeneration,
  });
  Future<List<NativeAlarmSnapshot>> activeNativeAlarmSnapshots();
  Future<List<NativeAlarmEvent>> drainAlarmEvents();
  Future<void> acknowledgeAlarmEvents(Set<String> eventIds);
}

/// Additive native seam for the device-local generation fence.
///
/// Older or lightweight gateways remain source compatible. Production mobile
/// gateways implement this contract so restore can disable alarms projected
/// from the losing database before they can be recovered or fired.
abstract interface class DeviceAlarmGenerationGateway {
  Future<void> activateDeviceGeneration(String? deviceGeneration);
}

/// Removes one native delivery route without recording a business cancel.
abstract interface class NativeReminderRouteGateway {
  Future<void> retireNativeReminderRoute({
    required String reminderId,
    required int scheduleRevision,
    required String sessionId,
    required String? deviceGeneration,
  });
}

final class ReminderDeliveryCapabilities {
  const ReminderDeliveryCapabilities({
    required this.notificationsGranted,
    required this.exactSchedulingAvailable,
    required this.exactAlarmPermissionRequired,
    required this.soundAvailable,
    required this.vibrationAvailable,
    required this.vibrationControlledBySystem,
    this.deliveryLevel = ReminderDeliveryLevel.ordinary,
    this.strongAlarmAuthorized,
    this.timeSensitiveAvailable,
  });

  final bool? notificationsGranted;
  final bool exactSchedulingAvailable;
  final bool exactAlarmPermissionRequired;
  final bool? soundAvailable;
  final bool? vibrationAvailable;
  final bool vibrationControlledBySystem;
  final ReminderDeliveryLevel deliveryLevel;
  final bool? strongAlarmAuthorized;
  final bool? timeSensitiveAvailable;

  bool get precisionRestricted =>
      exactAlarmPermissionRequired && !exactSchedulingAvailable;
}

@visibleForTesting
bool shouldUseNativeAlarmRoute({
  required bool soundEnabled,
  required bool nativeSupported,
  required bool isAndroid,
  required bool? exactAlarmAllowed,
  required NativeAlarmAuthorization alarmAuthorization,
}) =>
    soundEnabled &&
    nativeSupported &&
    (isAndroid
        ? exactAlarmAllowed == true
        : alarmAuthorization == NativeAlarmAuthorization.authorized);

@visibleForTesting
bool selectedAndroidDeliveryChannelReady({
  required bool usesNativeAlarmRoute,
  required bool? nativeAlarmChannelEnabled,
  required bool ordinaryChannelEnabled,
}) => usesNativeAlarmRoute
    ? nativeAlarmChannelEnabled == true
    : ordinaryChannelEnabled;

@visibleForTesting
({ReminderDeliveryLevel deliveryLevel, bool strongAlarmAuthorized})
resolveAndroidAlarmDeliveryLevel({
  required bool soundEnabled,
  required bool nativeSupported,
  required bool exactSchedulingAvailable,
  required bool? notificationsGranted,
  required bool selectedDeliveryChannelReady,
  required ReminderDeliveryLevel nativeReportedLevel,
}) {
  final strongAlarmReady =
      soundEnabled &&
      nativeSupported &&
      exactSchedulingAvailable &&
      notificationsGranted == true &&
      selectedDeliveryChannelReady;
  final deliveryLevel =
      notificationsGranted == false || !selectedDeliveryChannelReady
      ? ReminderDeliveryLevel.unavailable
      : !soundEnabled
      ? ReminderDeliveryLevel.ordinary
      : strongAlarmReady
      ? (nativeReportedLevel == ReminderDeliveryLevel.alarmGrade
            ? ReminderDeliveryLevel.alarmGrade
            : nativeReportedLevel)
      : nativeReportedLevel == ReminderDeliveryLevel.alarmGrade
      ? ReminderDeliveryLevel.ordinary
      : nativeReportedLevel;
  return (
    deliveryLevel: deliveryLevel,
    strongAlarmAuthorized: strongAlarmReady,
  );
}

final class ReminderAuthorizationResult {
  const ReminderAuthorizationResult({
    required this.notificationsGranted,
    required this.exactSchedulingAvailable,
    this.strongAlarmAuthorized = false,
    this.fullScreenAllowed,
    this.deliveryLevel = ReminderDeliveryLevel.ordinary,
  });

  final bool notificationsGranted;
  final bool exactSchedulingAvailable;
  final bool strongAlarmAuthorized;
  final bool? fullScreenAllowed;
  final ReminderDeliveryLevel deliveryLevel;
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
    required this.reminderId,
    required this.taskId,
    required this.scheduleRevision,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.scheduledAtUtc,
    this.originalScheduledAtUtc,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.defaultSnoozeMinutes,
    required this.exactScheduling,
    required this.payload,
    required this.localeTag,
    this.deviceGeneration,
  });

  final String reminderId;
  final String taskId;
  final int scheduleRevision;
  final int notificationId;
  final String title;
  final String body;
  final DateTime scheduledAtUtc;

  /// The immutable user-selected trigger. [scheduledAtUtc] may be advanced to
  /// the next second solely because ordinary notification APIs reject a date in
  /// the past. Native alarm bridges retain this value so their 15-minute late
  /// delivery cutoff is never restarted by foreground reconciliation.
  final DateTime? originalScheduledAtUtc;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int defaultSnoozeMinutes;
  final bool exactScheduling;
  final String payload;
  final String localeTag;
  final String? deviceGeneration;
}

@visibleForTesting
DateTime nativeAlarmTriggerAtUtc(LocalNotificationRequest request) =>
    request.originalScheduledAtUtc ?? request.scheduledAtUtc;

/// Versioned identity carried by ordinary iOS notification actions.
///
/// The old `task:<id>` payload did not identify a reminder revision, so a
/// delayed Snooze tap could modify a reminder that had since been edited.
/// This contract contains no user-authored text and binds the action to the
/// same reminder/revision/session compare-and-swap used by native alarms.
final class ReminderNotificationActionIdentity {
  const ReminderNotificationActionIdentity({
    required this.taskId,
    required this.reminderId,
    required this.scheduleRevision,
    required this.sessionId,
    this.deviceGeneration,
  });

  static const int legacyPayloadVersion = 2;
  static const int payloadVersion = 3;

  final String taskId;
  final String reminderId;
  final int scheduleRevision;
  final String sessionId;
  final String? deviceGeneration;

  String encode() => jsonEncode(<String, Object>{
    'v': deviceGeneration == null ? legacyPayloadVersion : payloadVersion,
    'taskId': taskId,
    'reminderId': reminderId,
    'revision': scheduleRevision,
    'session': sessionId,
    'generation': ?deviceGeneration,
  });

  static ReminderNotificationActionIdentity? tryDecode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?> ||
        (decoded['v'] != legacyPayloadVersion &&
            decoded['v'] != payloadVersion) ||
        decoded['taskId'] is! String ||
        decoded['reminderId'] is! String ||
        decoded['revision'] is! int ||
        decoded['session'] is! String) {
      return null;
    }
    final version = decoded['v']! as int;
    if (version == payloadVersion && decoded['generation'] is! String) {
      return null;
    }
    final rawGeneration = version == payloadVersion
        ? decoded['generation'] as String?
        : null;
    if (version == payloadVersion &&
        (rawGeneration == null || !_isUuid(rawGeneration))) {
      return null;
    }
    final generation = rawGeneration?.toLowerCase();
    final identity = ReminderNotificationActionIdentity(
      taskId: decoded['taskId']! as String,
      reminderId: decoded['reminderId']! as String,
      scheduleRevision: decoded['revision']! as int,
      sessionId: decoded['session']! as String,
      deviceGeneration: generation,
    );
    if (identity.taskId.isEmpty ||
        identity.reminderId.isEmpty ||
        identity.scheduleRevision <= 0 ||
        identity.sessionId !=
            _ordinaryNotificationSession(
              identity.reminderId,
              identity.scheduleRevision,
              deviceGeneration: identity.deviceGeneration,
            )) {
      return null;
    }
    return identity;
  }
}

final class NotificationCoordinator {
  NotificationCoordinator(
    this._readDatabase, {
    NotificationGateway? gateway,
    DateTime Function()? nowUtc,
    String Function()? systemLocaleName,
    this._onStateChanged,
    this._onOpenRequested,
    this._retryBaseDelay = const Duration(minutes: 1),
    PlatformMutationGate? mutationGate,
  }) : _gateway = gateway ?? _FlutterNotificationGateway(),
       _nowUtc = nowUtc ?? _systemNowUtc,
       _systemLocaleName = systemLocaleName ?? _platformLocaleName,
       _mutationGate = mutationGate ?? PlatformMutationGate() {
    // Android does not expose a trustworthy query for this app's AlarmManager
    // entries. A force-stop, package replacement, or OEM cleanup can therefore
    // remove the system alarm while the durable native mirror still looks
    // healthy. Re-submit only future database reminders once per new process;
    // the startup SQL deliberately excludes already-due reminders so opening
    // the app can never manufacture a catch-up ring.
    _forceStartupReschedule = _gateway.platformName == 'android';
  }

  final Future<DangguiDatabase> Function() _readDatabase;
  final NotificationGateway _gateway;
  final DateTime Function() _nowUtc;
  final String Function() _systemLocaleName;
  final FutureOr<void> Function()? _onStateChanged;
  final FutureOr<void> Function(String? taskId)? _onOpenRequested;
  final Duration _retryBaseDelay;
  final PlatformMutationGate _mutationGate;
  String? _initializedLocaleTag;
  NotificationPresentation? _presentation;
  bool _reconciling = false;
  bool _reconcileRequested = false;
  Completer<void>? _reconcileIdle;
  bool _interruptedJobsRecovered = false;
  bool _startupRescheduleComplete = false;
  bool _forceStartupReschedule = false;
  bool _exactSchedulingAvailable = true;
  bool? _lastExactSchedulingAvailable;
  bool? _lastStrongAlarmAuthorized;
  Set<String>? _ordinaryCapacityReminderIds;
  bool _nativeEventAcknowledgementPending = false;
  Timer? _retryTimer;
  bool _disposed = false;
  DangguiDatabase? _activeDatabase;

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

  /// Requests ordinary notification permission only.
  Future<bool> requestPermissions() async {
    if (!_gateway.isSupported) return true;
    await initialize();
    final granted = await _gateway.requestPermissions();
    if (granted) {
      await _mutationGate.protect(_restorePermissionDeniedReminders);
      await reconcile();
    }
    return granted;
  }

  Future<bool?> permissionsGranted() async {
    if (!_gateway.isSupported) return null;
    await initialize();
    return _gateway.permissionsGranted();
  }

  Future<ReminderDeliveryCapabilities?> deliveryCapabilities({
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {
    if (!_gateway.isSupported) return null;
    await initialize();
    return _readCapabilities(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
  }

  Future<bool> requestExactAlarmPermission() async {
    if (!_gateway.isSupported) return true;
    await initialize();
    final capabilityGateway = _gateway;
    if (capabilityGateway is! ReminderCapabilityGateway) return true;
    final granted = await (capabilityGateway as ReminderCapabilityGateway)
        .requestExactAlarmPermission();
    _startupRescheduleComplete = false;
    _forceStartupReschedule = true;
    await reconcile();
    return granted;
  }

  /// Checks first so the system prompt is only requested when necessary.
  Future<ReminderAuthorizationResult> ensurePermissionsForFutureReminder({
    bool soundEnabled = true,
    bool vibrationEnabled = true,
  }) async {
    if (!_gateway.isSupported) {
      return const ReminderAuthorizationResult(
        notificationsGranted: true,
        exactSchedulingAvailable: true,
        strongAlarmAuthorized: true,
        deliveryLevel: ReminderDeliveryLevel.alarmGrade,
      );
    }
    await initialize();
    final nativeGateway = _gateway is NativeReminderGateway
        ? _gateway as NativeReminderGateway
        : null;
    NativeAlarmCapabilities? nativeCapabilities;
    if (soundEnabled && nativeGateway != null) {
      nativeCapabilities = await nativeGateway.nativeAlarmCapabilities();
      if (nativeCapabilities.supported &&
          nativeCapabilities.platform == 'ios' &&
          nativeCapabilities.alarmAuthorization !=
              NativeAlarmAuthorization.authorized) {
        await nativeGateway.requestAlarmAuthorization();
        _startupRescheduleComplete = false;
        _forceStartupReschedule = true;
        nativeCapabilities = await nativeGateway.nativeAlarmCapabilities();
      }
    }

    var notificationsGranted = await permissionsGranted() == true;
    final alarmKitAuthorized =
        soundEnabled &&
        nativeCapabilities?.platform == 'ios' &&
        nativeCapabilities?.alarmAuthorization ==
            NativeAlarmAuthorization.authorized;
    if (!notificationsGranted && !alarmKitAuthorized) {
      notificationsGranted = await requestPermissions();
    }
    if (!notificationsGranted && !alarmKitAuthorized) {
      return const ReminderAuthorizationResult(
        notificationsGranted: false,
        exactSchedulingAvailable: false,
        deliveryLevel: ReminderDeliveryLevel.unavailable,
      );
    }

    var capabilities = await deliveryCapabilities(
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
    );
    var exactSchedulingAvailable =
        capabilities?.exactSchedulingAvailable ?? true;
    if (capabilities?.precisionRestricted == true) {
      exactSchedulingAvailable = await requestExactAlarmPermission();
      capabilities = await deliveryCapabilities(
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      );
      exactSchedulingAvailable =
          capabilities?.exactSchedulingAvailable ?? exactSchedulingAvailable;
    }
    bool? fullScreenAllowed = nativeCapabilities?.fullScreenAllowed;
    if (soundEnabled &&
        nativeGateway != null &&
        nativeCapabilities?.platform == 'android' &&
        exactSchedulingAvailable &&
        fullScreenAllowed == false) {
      await nativeGateway.requestFullScreenPermission();
      nativeCapabilities = await nativeGateway.nativeAlarmCapabilities();
      fullScreenAllowed = nativeCapabilities.fullScreenAllowed;
    }
    final strongAlarmAuthorized = !soundEnabled
        ? false
        : switch (nativeCapabilities?.platform) {
            'ios' =>
              nativeCapabilities?.supported == true &&
                  nativeCapabilities?.alarmAuthorization ==
                      NativeAlarmAuthorization.authorized,
            'android' => exactSchedulingAvailable,
            _ => false,
          };
    final deliveryLevel = !notificationsGranted && !alarmKitAuthorized
        ? ReminderDeliveryLevel.unavailable
        : !soundEnabled
        ? ReminderDeliveryLevel.ordinary
        : capabilities?.deliveryLevel ?? ReminderDeliveryLevel.ordinary;
    return ReminderAuthorizationResult(
      notificationsGranted: notificationsGranted || alarmKitAuthorized,
      exactSchedulingAvailable: exactSchedulingAvailable,
      strongAlarmAuthorized: strongAlarmAuthorized,
      fullScreenAllowed: fullScreenAllowed,
      deliveryLevel: deliveryLevel,
    );
  }

  Future<void> openNotificationSettings() async {
    final gateway = _gateway;
    if (gateway is NativeReminderGateway) {
      await (gateway as NativeReminderGateway).openNotificationSettings();
    }
  }

  Future<void> openAlarmSoundSettings() async {
    final gateway = _gateway;
    if (gateway is NativeReminderGateway) {
      await (gateway as NativeReminderGateway).openAlarmSoundSettings();
    }
  }

  Future<bool> openOemAutostartSettings() async {
    final gateway = _gateway;
    if (gateway is! NativeReminderGateway) return false;
    return (gateway as NativeReminderGateway).openOemAutostartSettings();
  }

  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    bool vibrationEnabled = true,
  }) async {
    await initialize();
    final gateway = _gateway;
    if (gateway is! NativeReminderGateway) return;
    await (gateway as NativeReminderGateway).scheduleTestAlarm(
      title: title,
      body: body,
      vibrationEnabled: vibrationEnabled,
    );
  }

  Future<ReminderDeliveryCapabilities> _readCapabilities({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    final capabilityGateway = _gateway;
    if (capabilityGateway is ReminderCapabilityGateway) {
      return (capabilityGateway as ReminderCapabilityGateway)
          .deliveryCapabilities(
            soundEnabled: soundEnabled,
            vibrationEnabled: vibrationEnabled,
          );
    }
    return ReminderDeliveryCapabilities(
      notificationsGranted: await _gateway.permissionsGranted(),
      exactSchedulingAvailable: true,
      exactAlarmPermissionRequired: false,
      soundAvailable: null,
      vibrationAvailable: null,
      vibrationControlledBySystem: false,
      deliveryLevel: ReminderDeliveryLevel.ordinary,
    );
  }

  /// Persists a permission result after a future reminder's first save. A
  /// denial pauses delivery but preserves the selected time.
  Future<void> applyPermissionResultForTask(
    String taskId, {
    required bool granted,
  }) async {
    if (!_gateway.isSupported) return;
    await _mutationGate.protect(() async {
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
    });
    await reconcile();
  }

  Future<bool> handleNotificationAction(
    String? actionId,
    String? payload,
  ) async {
    final identity = ReminderNotificationActionIdentity.tryDecode(payload);
    if (actionId == null || actionId.isEmpty) {
      final legacyTaskId = _legacyManagedTaskId(payload);
      final taskId = identity?.taskId ?? legacyTaskId;
      if (taskId == null) return false;
      await _mutationGate.protect(() async {
        final database = await _readDatabase();
        final deviceGeneration = await _currentDeviceAlarmGeneration(database);
        String? targetId;
        if (identity != null && identity.deviceGeneration == deviceGeneration) {
          final target = await database
              .customSelect(
                'SELECT t.id AS task_id, r.id AS reminder_id, '
                'r.schedule_revision FROM tasks t '
                'JOIN reminders r ON r.task_id = t.id '
                'WHERE t.id = ? AND t.status IN (?, ?) LIMIT 1',
                variables: <Variable<Object>>[
                  Variable.withString(taskId),
                  Variable.withString(TaskStatus.active.name),
                  Variable.withString(TaskStatus.completionPending.name),
                ],
              )
              .getSingleOrNull();
          if (target != null &&
              target.read<String>('reminder_id') == identity.reminderId &&
              target.read<int>('schedule_revision') ==
                  identity.scheduleRevision) {
            targetId = target.read<String>('task_id');
          }
        } else if (identity == null &&
            legacyTaskId != null &&
            deviceGeneration == null) {
          final target = await database
              .customSelect(
                'SELECT id FROM tasks WHERE id = ? AND status IN (?, ?) '
                'LIMIT 1',
                variables: <Variable<Object>>[
                  Variable.withString(taskId),
                  Variable.withString(TaskStatus.active.name),
                  Variable.withString(TaskStatus.completionPending.name),
                ],
              )
              .getSingleOrNull();
          targetId = target?.read<String>('id');
        }
        await _onOpenRequested?.call(targetId);
      });
      return true;
    }
    final minutes = _minutesFromAction(actionId);
    if (minutes == null || identity == null) return false;
    return snoozeReminderForTask(
      identity.taskId,
      minutes: minutes,
      expectedReminderId: identity.reminderId,
      expectedRevision: identity.scheduleRevision,
      expectedSession: identity.sessionId,
      expectedDeviceGeneration: identity.deviceGeneration,
    );
  }

  /// Passing null uses the persisted default (10, 30, or 60 minutes).
  Future<bool> snoozeReminderForTask(
    String taskId, {
    int? minutes,
    String? expectedReminderId,
    int? expectedRevision,
    String? expectedSession,
    String? expectedDeviceGeneration,
  }) async {
    final changed = await _mutationGate.protect(
      () => _snoozeReminderMutation(
        taskId,
        minutes: minutes,
        expectedReminderId: expectedReminderId,
        expectedRevision: expectedRevision,
        expectedSession: expectedSession,
        expectedDeviceGeneration: expectedDeviceGeneration,
      ),
    );
    if (changed) {
      await reconcile();
      await _onStateChanged?.call();
    }
    return changed;
  }

  Future<bool> _snoozeReminderMutation(
    String taskId, {
    int? minutes,
    String? expectedReminderId,
    int? expectedRevision,
    String? expectedSession,
    String? expectedDeviceGeneration,
  }) async {
    final database = await _readDatabase();
    final deviceGeneration = await _currentDeviceAlarmGeneration(database);
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
            'r.scheduled_zone_id, '
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
      final hasExpectedIdentity =
          expectedReminderId != null ||
          expectedRevision != null ||
          expectedSession != null ||
          expectedDeviceGeneration != null;
      if (hasExpectedIdentity &&
          (expectedReminderId != reminderId ||
              expectedRevision != oldRevision ||
              expectedDeviceGeneration != deviceGeneration ||
              expectedSession !=
                  _ordinaryNotificationSession(
                    reminderId,
                    oldRevision,
                    deviceGeneration: deviceGeneration,
                  ))) {
        return;
      }
      final revision = oldRevision + 1;
      final scheduledUtc = nowUtc.add(Duration(minutes: resolvedMinutes));
      final scheduled = _localDateTimeAndZone(
        scheduledUtc,
        reminder.read<String>('scheduled_zone_id'),
      );
      final affected = await database.customUpdate(
        'UPDATE reminders SET scheduled_local_date_time = ?, '
        'scheduled_zone_id = ?, scheduled_at_utc = ?, snoozed_until_utc = ?, '
        'status = ?, pause_reason = NULL, snooze_count = snooze_count + 1, '
        'schedule_revision = ?, last_fired_at_utc = ?, updated_at_utc = ?, '
        'row_version = row_version + 1 '
        'WHERE id = ? AND schedule_revision = ?',
        variables: <Variable<Object>>[
          Variable.withString(scheduled.localDateTime.toIso8601String()),
          Variable.withString(scheduled.zoneId),
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
    return changed;
  }

  /// Drains the durable platform-job outbox with stale-revision protection.
  Future<void> reconcile() => _mutationGate.protect(_reconcileBehindGate);

  Future<void> _reconcileBehindGate() async {
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
    if (_activeDatabase != null && !identical(_activeDatabase, database)) {
      _interruptedJobsRecovered = false;
      _startupRescheduleComplete = false;
      _forceStartupReschedule = true;
      _ordinaryCapacityReminderIds = null;
      _lastExactSchedulingAvailable = null;
      _lastStrongAlarmAuthorized = null;
    }
    _activeDatabase = database;
    await _initializeForDatabase(database);
    final deviceGeneration = await _currentDeviceAlarmGeneration(database);
    final generationGateway = _gateway;
    if (generationGateway is DeviceAlarmGenerationGateway) {
      await (generationGateway as DeviceAlarmGenerationGateway)
          .activateDeviceGeneration(deviceGeneration);
    }
    await _applyNativeAlarmEvents(database, deviceGeneration);
    final capabilities = await _readCapabilities(
      soundEnabled: true,
      vibrationEnabled: true,
    );
    final exactSchedulingAvailable = capabilities.exactSchedulingAvailable;
    if (_lastExactSchedulingAvailable != null &&
        _lastExactSchedulingAvailable != exactSchedulingAvailable) {
      // Android removes future exact alarms when special access is revoked.
      // Replacing every future request with the same stable ID also upgrades
      // inexact fallbacks immediately after the user grants access.
      _startupRescheduleComplete = false;
      _forceStartupReschedule = true;
    }
    _lastExactSchedulingAvailable = exactSchedulingAvailable;
    final strongAlarmAuthorized = capabilities.strongAlarmAuthorized;
    if (_lastStrongAlarmAuthorized != null &&
        strongAlarmAuthorized != null &&
        _lastStrongAlarmAuthorized != strongAlarmAuthorized) {
      _startupRescheduleComplete = false;
      _forceStartupReschedule = true;
    }
    if (strongAlarmAuthorized != null) {
      _lastStrongAlarmAuthorized = strongAlarmAuthorized;
    }
    _exactSchedulingAvailable = exactSchedulingAvailable;
    final expirationCutoff = _nowMicros();
    await _expirePastReminders(database, expirationCutoff, deviceGeneration);
    final iosAlarmGrade =
        _gateway.platformName == 'ios' &&
        capabilities.deliveryLevel == ReminderDeliveryLevel.alarmGrade;
    if (iosAlarmGrade) {
      // AlarmKit authorization does not imply ordinary notification access.
      // Sound alarms can remain scheduled while silent reminders, which use
      // UNUserNotificationCenter, follow that route's independent permission.
      final ordinaryCapabilities = await _readCapabilities(
        soundEnabled: false,
        vibrationEnabled: true,
      );
      final ordinaryPermission = ordinaryCapabilities.notificationsGranted;
      if (ordinaryPermission == false) {
        await _markScheduledRemindersPermissionDenied(
          database,
          soundEnabled: false,
        );
        await _restorePermissionDeniedReminders(soundEnabled: true);
      } else if (ordinaryPermission == true) {
        await _restorePermissionDeniedReminders();
      }
    } else {
      final permission = capabilities.notificationsGranted;
      if (permission == false) {
        await _markScheduledRemindersPermissionDenied(database);
      } else if (permission == true) {
        // Also recover when the user enabled notifications in system settings
        // instead of returning through the in-app permission button.
        await _restorePermissionDeniedReminders();
      }
    }
    // Permission recovery can enqueue a job using a timestamp later than the
    // expiration cutoff above. Take a fresh value so that newly-created jobs
    // are drained during this same reconciliation pass.
    final now = _nowMicros();
    await _configureOrdinaryNotificationCapacity(
      database,
      capabilities,
      now,
      deviceGeneration,
    );
    if (!_interruptedJobsRecovered) {
      await _recoverInterruptedJobs(database, now);
      _interruptedJobsRecovered = true;
    }
    // A replace restore can swap the logical database while this coordinator
    // stays alive. Reconcile the platform snapshot on every pass so reminders
    // removed by the restored database cannot survive until process restart.
    _startupRescheduleComplete = await _rescheduleFutureRemindersAfterStart(
      database,
      now,
      deviceGeneration,
    );
    if (_startupRescheduleComplete) _forceStartupReschedule = false;
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
      await _runJob(database, row, now, deviceGeneration);
    }
    if (rows.length == 64) _reconcileRequested = true;
  }

  Future<void> _configureOrdinaryNotificationCapacity(
    DangguiDatabase database,
    ReminderDeliveryCapabilities capabilities,
    int now,
    String? deviceGeneration,
  ) async {
    final isCapacityLimited = _gateway.platformName == 'ios';
    if (!isCapacityLimited) {
      _ordinaryCapacityReminderIds = null;
      await database.customStatement(
        'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
        'updated_at_utc = ? WHERE kind = ? AND last_error_code = ?',
        <Object?>[
          PlatformJobStatus.failed.name,
          now,
          now,
          PlatformJobKind.scheduleReminder.name,
          'capacity_deferred',
        ],
      );
      return;
    }

    final rows = await database
        .customSelect(
          'SELECT r.id, r.schedule_revision, r.sound_enabled, '
          'nr.platform_notification_id '
          'FROM reminders r JOIN tasks t ON t.id = r.task_id '
          'LEFT JOIN notification_registrations nr ON nr.reminder_id = r.id '
          'AND nr.platform = ? AND nr.schedule_revision = r.schedule_revision '
          'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ? '
          'ORDER BY r.scheduled_at_utc, r.id',
          variables: <Variable<Object>>[
            Variable.withString(_gateway.platformName),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withInt(now),
            Variable.withString(TaskStatus.active.name),
          ],
        )
        .get();
    final alarmKitAuthorized =
        capabilities.deliveryLevel == ReminderDeliveryLevel.alarmGrade;
    final nativeRows = alarmKitAuthorized
        ? rows.where((row) => row.read<bool>('sound_enabled')).toList()
        : const <QueryRow>[];
    final ordinaryRows = alarmKitAuthorized
        ? rows.where((row) => !row.read<bool>('sound_enabled')).toList()
        : rows;
    final allowed = <String>{
      for (final row in nativeRows) row.read<String>('id'),
      for (final row in ordinaryRows.take(_iosOrdinaryNotificationCapacity))
        row.read<String>('id'),
    };
    _ordinaryCapacityReminderIds = allowed;
    final retryAt = now + _lateDeliveryWindow.inMicroseconds;
    for (final row in rows) {
      final reminderId = row.read<String>('id');
      final revision = row.read<int>('schedule_revision');
      if (allowed.contains(reminderId)) {
        await database.customStatement(
          'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
          'updated_at_utc = ? WHERE kind = ? AND aggregate_id = ? '
          'AND aggregate_revision = ? AND last_error_code = ?',
          <Object?>[
            PlatformJobStatus.failed.name,
            now,
            now,
            PlatformJobKind.scheduleReminder.name,
            reminderId,
            revision,
            'capacity_deferred',
          ],
        );
        continue;
      }
      final notificationId = row.readNullable<int>('platform_notification_id');
      await _retireCapacityDeferredProjection(
        reminderId: reminderId,
        scheduleRevision: revision,
        deviceGeneration: deviceGeneration,
      );
      if (notificationId != null) {
        await database.customStatement(
          'DELETE FROM notification_registrations WHERE reminder_id = ? '
          'AND platform = ? AND schedule_revision = ?',
          <Object?>[reminderId, _gateway.platformName, revision],
        );
      }
      await database.customStatement(
        'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
        'last_error_code = ?, updated_at_utc = ? WHERE kind = ? '
        'AND aggregate_id = ? AND aggregate_revision = ?',
        <Object?>[
          PlatformJobStatus.failed.name,
          retryAt,
          'capacity_deferred',
          now,
          PlatformJobKind.scheduleReminder.name,
          reminderId,
          revision,
        ],
      );
    }
  }

  Future<void> _applyNativeAlarmEvents(
    DangguiDatabase database,
    String? deviceGeneration,
  ) async {
    final gateway = _gateway;
    if (gateway is! NativeReminderGateway) return;
    List<NativeAlarmEvent> events;
    try {
      events = await (gateway as NativeReminderGateway).drainAlarmEvents();
    } on Object {
      // Event synchronization repairs durable app state, but a vendor method
      // channel failure must not block ordinary reminder reconciliation.
      return;
    }
    if (events.isEmpty) {
      _nativeEventAcknowledgementPending = false;
      return;
    }
    events.sort(
      (left, right) => left.occurredAtUtc.compareTo(right.occurredAtUtc),
    );
    var changed = false;
    await database.transaction(() async {
      for (final event in events) {
        if (event.reminderId.isEmpty) continue;
        final row = await database
            .customSelect(
              'SELECT r.id, r.task_id, r.status AS reminder_status, '
              'r.schedule_revision, r.scheduled_zone_id, '
              't.status AS task_status '
              'FROM reminders r JOIN tasks t ON t.id = r.task_id '
              'WHERE r.id = ?',
              variables: <Variable<Object>>[
                Variable.withString(event.reminderId),
              ],
            )
            .getSingleOrNull();
        if (row == null ||
            row.read<String>('task_status') != TaskStatus.active.name ||
            (event.taskId.isNotEmpty &&
                row.read<String>('task_id') != event.taskId)) {
          continue;
        }
        final currentRevision = row.read<int>('schedule_revision');
        final mutatesBusinessState = switch (event.type) {
          NativeAlarmEventType.delivered ||
          NativeAlarmEventType.missed ||
          NativeAlarmEventType.stopped ||
          NativeAlarmEventType.snoozed => true,
          _ => false,
        };
        if (mutatesBusinessState &&
            (event.scheduleRevision <= 0 ||
                currentRevision != event.scheduleRevision ||
                event.deviceGeneration != deviceGeneration ||
                event.sessionId == null ||
                event.sessionId!.trim().isEmpty ||
                event.sessionId !=
                    deterministicNativeAlarmSessionId(
                      event.reminderId,
                      currentRevision,
                      deviceGeneration: deviceGeneration,
                    ))) {
          // A business-state event is a compare-and-swap operation. Revision
          // and the deterministic cross-platform session are both mandatory;
          // a missing or arbitrary session must never become a wildcard.
          continue;
        }
        if (!mutatesBusinessState &&
            event.scheduleRevision > 0 &&
            currentRevision != event.scheduleRevision) {
          continue;
        }
        final occurredAt = event.occurredAtUtc.microsecondsSinceEpoch;
        switch (event.type) {
          case NativeAlarmEventType.registered:
          case NativeAlarmEventType.foreground:
          case NativeAlarmEventType.systemAlert:
          case NativeAlarmEventType.audio:
          case NativeAlarmEventType.vibration:
          case NativeAlarmEventType.error:
            // These milestones are retained by the bounded native diagnostic
            // log. They intentionally do not mutate reminder business state.
            continue;
          case NativeAlarmEventType.delivered:
            final affected = await database.customUpdate(
              'UPDATE reminders SET last_fired_at_utc = ?, '
              'updated_at_utc = ?, row_version = row_version + 1 '
              'WHERE id = ? AND schedule_revision = ? AND status = ? '
              'AND (last_fired_at_utc IS NULL OR last_fired_at_utc <> ?)',
              variables: <Variable<Object>>[
                Variable.withInt(occurredAt),
                Variable.withInt(occurredAt),
                Variable.withString(event.reminderId),
                Variable.withInt(currentRevision),
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withInt(occurredAt),
              ],
              updates: <TableInfo<Table, Object?>>{database.reminders},
            );
            changed = affected == 1 || changed;
          case NativeAlarmEventType.missed:
            final revision = currentRevision + 1;
            final affected = await database.customUpdate(
              'UPDATE reminders SET status = ?, pause_reason = NULL, '
              'schedule_revision = ?, updated_at_utc = ?, '
              'row_version = row_version + 1 '
              'WHERE id = ? AND schedule_revision = ? AND status IN (?, ?)',
              variables: <Variable<Object>>[
                Variable.withString(ReminderStatus.expired.name),
                Variable.withInt(revision),
                Variable.withInt(occurredAt),
                Variable.withString(event.reminderId),
                Variable.withInt(currentRevision),
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withString(ReminderStatus.expired.name),
              ],
              updates: <TableInfo<Table, Object?>>{database.reminders},
            );
            if (affected == 1) {
              await _insertOutboxJob(
                database,
                reminderId: event.reminderId,
                taskId: row.read<String>('task_id'),
                revision: revision,
                kind: PlatformJobKind.cancelReminder,
                nowMicros: _nowMicros(),
              );
              changed = true;
            }
          case NativeAlarmEventType.stopped:
            final revision = currentRevision + 1;
            final affected = await database.customUpdate(
              'UPDATE reminders SET status = ?, pause_reason = NULL, '
              'schedule_revision = ?, last_fired_at_utc = ?, '
              'updated_at_utc = ?, row_version = row_version + 1 '
              'WHERE id = ? AND schedule_revision = ? AND status IN (?, ?)',
              variables: <Variable<Object>>[
                Variable.withString(ReminderStatus.expired.name),
                Variable.withInt(revision),
                Variable.withInt(occurredAt),
                Variable.withInt(occurredAt),
                Variable.withString(event.reminderId),
                Variable.withInt(currentRevision),
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withString(ReminderStatus.expired.name),
              ],
              updates: <TableInfo<Table, Object?>>{database.reminders},
            );
            if (affected == 1) {
              await _insertOutboxJob(
                database,
                reminderId: event.reminderId,
                taskId: row.read<String>('task_id'),
                revision: revision,
                kind: PlatformJobKind.cancelReminder,
                nowMicros: _nowMicros(),
              );
              changed = true;
            }
          case NativeAlarmEventType.snoozed:
            final minutes = event.snoozeMinutes;
            if (minutes == null || !_supportedSnoozeMinutes.contains(minutes)) {
              continue;
            }
            final reminderStatus = row.read<String>('reminder_status');
            if (reminderStatus != ReminderStatus.scheduled.name &&
                reminderStatus != ReminderStatus.expired.name) {
              continue;
            }
            final revision = currentRevision + 1;
            final scheduledUtc = event.successorTriggerAtEpochMs == null
                ? event.occurredAtUtc.add(Duration(minutes: minutes))
                : DateTime.fromMillisecondsSinceEpoch(
                    event.successorTriggerAtEpochMs!,
                    isUtc: true,
                  );
            final scheduled = _localDateTimeAndZone(
              scheduledUtc,
              row.read<String>('scheduled_zone_id'),
            );
            final affected = await database.customUpdate(
              'UPDATE reminders SET scheduled_local_date_time = ?, '
              'scheduled_zone_id = ?, scheduled_at_utc = ?, '
              'snoozed_until_utc = ?, status = ?, pause_reason = NULL, '
              'snooze_count = snooze_count + 1, schedule_revision = ?, '
              'last_fired_at_utc = ?, updated_at_utc = ?, '
              'row_version = row_version + 1 '
              'WHERE id = ? AND schedule_revision = ? AND status IN (?, ?)',
              variables: <Variable<Object>>[
                Variable.withString(scheduled.localDateTime.toIso8601String()),
                Variable.withString(scheduled.zoneId),
                Variable.withInt(scheduledUtc.microsecondsSinceEpoch),
                Variable.withInt(scheduledUtc.microsecondsSinceEpoch),
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withInt(revision),
                Variable.withInt(occurredAt),
                Variable.withInt(occurredAt),
                Variable.withString(event.reminderId),
                Variable.withInt(currentRevision),
                Variable.withString(ReminderStatus.scheduled.name),
                Variable.withString(ReminderStatus.expired.name),
              ],
              updates: <TableInfo<Table, Object?>>{database.reminders},
            );
            if (affected == 1) {
              await _insertOutboxJob(
                database,
                reminderId: event.reminderId,
                taskId: row.read<String>('task_id'),
                revision: revision,
                kind: PlatformJobKind.scheduleReminder,
                nowMicros: _nowMicros(),
              );
              changed = true;
            }
        }
      }
    });
    if (changed) await _onStateChanged?.call();
    try {
      await (gateway as NativeReminderGateway).acknowledgeAlarmEvents(
        events.map((event) => event.eventId).toSet(),
      );
      _nativeEventAcknowledgementPending = false;
    } on Object {
      // Business mutations above are replay-safe through revision/session
      // compare-and-swap. A transient acknowledgement failure must not abort
      // capacity repair or the outbox drain; retain a process-local retry bit
      // and let the existing bounded retry timer drain the native events again.
      _nativeEventAcknowledgementPending = true;
    }
  }

  /// Makes an elapsed reminder a durable historical state instead of leaving
  /// it looking scheduled forever after the operating system has fired it.
  /// Permission-denied reminders also expire without catch-up delivery.
  Future<void> _expirePastReminders(
    DangguiDatabase database,
    int now,
    String? deviceGeneration,
  ) async {
    final missedBefore = now - _lateDeliveryWindow.inMicroseconds;
    final candidates = await database
        .customSelect(
          'SELECT r.id, r.schedule_revision, r.scheduled_at_utc '
          'FROM reminders r JOIN tasks t ON t.id = r.task_id '
          'WHERE r.scheduled_at_utc < ? AND r.status IN (?, ?) '
          'AND t.status = ?',
          variables: <Variable<Object>>[
            Variable.withInt(missedBefore),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withString(ReminderStatus.permissionDenied.name),
            Variable.withString(TaskStatus.active.name),
          ],
        )
        .get();
    if (candidates.isEmpty) return;

    // All delivery mechanisms share the same bounded recovery window. This is
    // deliberately independent of whether the request was exact, inexact,
    // AlarmKit, or an ordinary notification: opening the app after the window
    // must never turn a stale reminder into a surprise alarm.
    final pendingIds = await _gateway.pendingNotificationIds();
    final expiringRows = <QueryRow>[];
    for (final row in candidates) {
      final reminderId = row.read<String>('id');
      final notificationId = _notificationId(reminderId);
      final isPending = pendingIds.contains(notificationId);
      if (isPending) {
        await _cancelPlatformReminder(
          reminderId: row.read<String>('id'),
          notificationId: notificationId,
          deviceGeneration: deviceGeneration,
        );
      }
      expiringRows.add(row);
    }
    if (expiringRows.isEmpty) return;

    await database.transaction(() async {
      for (final row in expiringRows) {
        final reminderId = row.read<String>('id');
        final previousRevision = row.read<int>('schedule_revision');
        final revision = previousRevision + 1;
        final changed = await database.customUpdate(
          'UPDATE reminders SET status = ?, pause_reason = NULL, '
          'schedule_revision = ?, updated_at_utc = ?, '
          'row_version = row_version + 1 WHERE id = ? '
          'AND schedule_revision = ? AND scheduled_at_utc < ? '
          'AND status IN (?, ?)',
          variables: <Variable<Object>>[
            Variable.withString(ReminderStatus.expired.name),
            Variable.withInt(revision),
            Variable.withInt(now),
            Variable.withString(reminderId),
            Variable.withInt(previousRevision),
            Variable.withInt(missedBefore),
            Variable.withString(ReminderStatus.scheduled.name),
            Variable.withString(ReminderStatus.permissionDenied.name),
          ],
          updates: <TableInfo<Table, Object?>>{database.reminders},
        );
        if (changed == 1) {
          await database.customStatement(
            'UPDATE platform_jobs SET last_error_code = ?, '
            'updated_at_utc = ? WHERE aggregate_id = ? '
            'AND aggregate_revision = ?',
            <Object?>['missed', now, reminderId, previousRevision],
          );
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

  /// Repairs only device state that differs from the durable reminder state.
  ///
  /// Reading snapshots first avoids the previous blind startup rebuild, which
  /// could replace an already-correct alarm and create a delivery gap. Jobs
  /// still owned by the outbox are excluded so the two recovery paths cannot
  /// schedule the same revision in one reconciliation pass.
  Future<bool> _rescheduleFutureRemindersAfterStart(
    DangguiDatabase database,
    int now,
    String? deviceGeneration,
  ) async {
    final Set<int> pendingNotificationIds;
    final Map<int, String?>? pendingNotificationPayloads;
    final List<NativeAlarmSnapshot> nativeSnapshots;
    try {
      final gateway = _gateway;
      if (gateway is PendingNotificationPayloadGateway) {
        final pending = await (gateway as PendingNotificationPayloadGateway)
            .pendingNotificationSnapshots();
        pendingNotificationPayloads = <int, String?>{
          for (final snapshot in pending)
            snapshot.notificationId: snapshot.payload,
        };
        pendingNotificationIds = pendingNotificationPayloads.keys.toSet();
      } else {
        pendingNotificationPayloads = null;
        pendingNotificationIds = await gateway.pendingNotificationIds();
      }
      nativeSnapshots = gateway is NativeReminderGateway
          ? await (gateway as NativeReminderGateway)
                .activeNativeAlarmSnapshots()
          : const <NativeAlarmSnapshot>[];
    } on Object {
      // Platform state is the source of truth for this repair. Retrying later
      // is safer than assuming an empty snapshot and rebuilding everything.
      return false;
    }
    final snapshotsByReminderId = <String, NativeAlarmSnapshot>{};
    var complete = true;
    final logicalRows = await database
        .customSelect('SELECT id, task_id, schedule_revision FROM reminders')
        .get();
    final logicalTaskByReminderId = <String, String>{
      for (final row in logicalRows)
        row.read<String>('id'): row.read<String>('task_id'),
    };
    final logicalReminderTaskIds = logicalTaskByReminderId.values.toSet();
    final logicalRevisionByReminderId = <String, int>{
      for (final row in logicalRows)
        row.read<String>('id'): row.read<int>('schedule_revision'),
    };

    // Native snapshots come only from Danggui's own durable mirror, so a
    // reminder absent from the restored logical database is provably orphaned.
    final nativeGateway = _gateway is NativeReminderGateway
        ? _gateway as NativeReminderGateway
        : null;
    if (nativeGateway != null) {
      for (final snapshot in nativeSnapshots) {
        final reminderId = snapshot.reminderId.trim();
        final currentRevision = logicalRevisionByReminderId[reminderId];
        if (reminderId.isNotEmpty &&
            currentRevision == snapshot.scheduleRevision &&
            snapshot.deviceGeneration == deviceGeneration) {
          snapshotsByReminderId[reminderId] = snapshot;
          continue;
        }
        if (reminderId.isEmpty) continue;
        try {
          await _retireNativeProjection(
            snapshot: snapshot,
            nativeGateway: nativeGateway,
          );
        } on Object {
          complete = false;
        }
      }
    }

    // Payload-less and foreign-schema requests remain untouched. Only a valid
    // Danggui v2 identity or the narrowly-scoped legacy task payload proves
    // that an ordinary pending request belongs to this reminder subsystem.
    if (pendingNotificationPayloads != null) {
      for (final entry in pendingNotificationPayloads.entries) {
        final identity = ReminderNotificationActionIdentity.tryDecode(
          entry.value,
        );
        if (identity != null) {
          final logicalTaskId = logicalTaskByReminderId[identity.reminderId];
          final logicalRevision =
              logicalRevisionByReminderId[identity.reminderId];
          if (logicalTaskId != null &&
              logicalTaskId == identity.taskId &&
              logicalRevision == identity.scheduleRevision &&
              identity.deviceGeneration == deviceGeneration) {
            continue;
          }
          try {
            await _gateway.cancel(entry.key);
            pendingNotificationIds.remove(entry.key);
          } on Object {
            complete = false;
          }
          continue;
        }
        final legacyTaskId = _legacyManagedTaskId(entry.value);
        if (legacyTaskId == null ||
            (deviceGeneration == null &&
                logicalReminderTaskIds.contains(legacyTaskId))) {
          continue;
        }
        try {
          await _gateway.cancel(entry.key);
          pendingNotificationIds.remove(entry.key);
        } on Object {
          complete = false;
        }
      }
    }
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
    for (final row in rows) {
      final reminderId = row.read<String>('reminder_id');
      final revision = row.read<int>('aggregate_revision');
      final snapshot = snapshotsByReminderId[reminderId];
      final registeredNotificationId = row.readNullable<int>(
        'platform_notification_id',
      );
      final capacity = _ordinaryCapacityReminderIds;
      if (capacity != null && !capacity.contains(reminderId)) {
        try {
          if (snapshot != null && nativeGateway != null) {
            await _retireNativeProjection(
              snapshot: snapshot,
              nativeGateway: nativeGateway,
            );
            snapshotsByReminderId.remove(reminderId);
          }
          final notificationId =
              registeredNotificationId ?? _notificationId(reminderId);
          await _gateway.cancel(notificationId);
          pendingNotificationIds.remove(notificationId);
        } on Object {
          complete = false;
        }
        continue;
      }
      final scheduledAtMs =
          row.read<int>('scheduled_at_utc') ~/
          Duration.microsecondsPerMillisecond;
      final nativeStateMatches =
          !_forceStartupReschedule &&
          snapshot != null &&
          snapshot.state.isActive &&
          snapshot.scheduleRevision == revision &&
          snapshot.deviceGeneration == deviceGeneration &&
          snapshot.triggerAtEpochMs == scheduledAtMs;
      final ordinaryStateMatches =
          !_forceStartupReschedule &&
          snapshot == null &&
          registeredNotificationId != null &&
          pendingNotificationIds.contains(registeredNotificationId) &&
          (pendingNotificationPayloads == null ||
              _pendingIdentityMatches(
                pendingNotificationPayloads[registeredNotificationId],
                reminderId: reminderId,
                taskId: row.read<String>('task_id'),
                scheduleRevision: revision,
                deviceGeneration: deviceGeneration,
              ));
      if (nativeStateMatches || ordinaryStateMatches) continue;
      try {
        final scheduled = await _schedule(
          database,
          row,
          now,
          deviceGeneration,
          notificationId: registeredNotificationId,
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

  Future<void> _retireNativeProjection({
    required NativeAlarmSnapshot snapshot,
    required NativeReminderGateway nativeGateway,
  }) async {
    final routeGateway = _gateway;
    if (routeGateway is NativeReminderRouteGateway &&
        snapshot.scheduleRevision > 0) {
      await (routeGateway as NativeReminderRouteGateway)
          .retireNativeReminderRoute(
            reminderId: snapshot.reminderId,
            scheduleRevision: snapshot.scheduleRevision,
            sessionId: deterministicNativeAlarmSessionId(
              snapshot.reminderId,
              snapshot.scheduleRevision,
              deviceGeneration: snapshot.deviceGeneration,
            ),
            deviceGeneration: snapshot.deviceGeneration,
          );
      return;
    }
    await nativeGateway.cancelReminder(
      reminderId: snapshot.reminderId,
      notificationId: _notificationId(snapshot.reminderId),
      deviceGeneration: snapshot.deviceGeneration,
    );
  }

  Future<void> _runJob(
    DangguiDatabase database,
    QueryRow row,
    int now,
    String? deviceGeneration,
  ) async {
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
        await _cancel(database, row, deviceGeneration);
      } else if (kind == PlatformJobKind.scheduleReminder.name ||
          kind == PlatformJobKind.refreshReminderLocale.name) {
        final capacity = _ordinaryCapacityReminderIds;
        if (capacity != null &&
            !capacity.contains(row.read<String>('reminder_id'))) {
          await _retireCapacityDeferredProjection(
            reminderId: row.read<String>('reminder_id'),
            scheduleRevision: row.read<int>('aggregate_revision'),
            deviceGeneration: deviceGeneration,
          );
          await database.customStatement(
            'UPDATE platform_jobs SET status = ?, next_attempt_at_utc = ?, '
            'last_error_code = ?, updated_at_utc = ? WHERE id = ?',
            <Object?>[
              PlatformJobStatus.failed.name,
              now + _lateDeliveryWindow.inMicroseconds,
              'capacity_deferred',
              now,
              jobId,
            ],
          );
          return;
        }
        final eligible =
            row.read<String>('reminder_status') ==
                ReminderStatus.scheduled.name &&
            row.read<String>('task_status') == TaskStatus.active.name;
        if (!eligible) {
          final reminderId = row.read<String>('reminder_id');
          await _cancelPlatformReminder(
            reminderId: reminderId,
            notificationId: _notificationId(reminderId),
            deviceGeneration: deviceGeneration,
          );
          completionCode = 'ineligible_state_discarded';
        } else if (!await _schedule(database, row, now, deviceGeneration)) {
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

  Future<void> _retireCapacityDeferredProjection({
    required String reminderId,
    required int scheduleRevision,
    required String? deviceGeneration,
  }) async {
    final routeGateway = _gateway;
    if (routeGateway is NativeReminderRouteGateway) {
      await (routeGateway as NativeReminderRouteGateway)
          .retireNativeReminderRoute(
            reminderId: reminderId,
            scheduleRevision: scheduleRevision,
            sessionId: deterministicNativeAlarmSessionId(
              reminderId,
              scheduleRevision,
              deviceGeneration: deviceGeneration,
            ),
            deviceGeneration: deviceGeneration,
          );
    }
    await _gateway.cancel(_notificationId(reminderId));
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
    Duration? delay;
    if (retryAt != null) {
      final delayMicros = retryAt - _nowMicros();
      delay = Duration(microseconds: delayMicros > 0 ? delayMicros : 0);
    }
    if (_nativeEventAcknowledgementPending &&
        (delay == null || _retryBaseDelay < delay)) {
      delay = _retryBaseDelay;
    }
    if (delay == null || _disposed) return;
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
    int now,
    String? deviceGeneration, {
    int? notificationId,
  }) async {
    final scheduledAt = row.read<int>('scheduled_at_utc');
    final reminderId = row.read<String>('reminder_id');
    final taskId = row.read<String>('task_id');
    final revision = row.read<int>('aggregate_revision');
    final id = notificationId ?? _notificationId(reminderId);
    if (scheduledAt < now - _lateDeliveryWindow.inMicroseconds) {
      await _cancelPlatformReminder(
        reminderId: reminderId,
        notificationId: id,
        deviceGeneration: deviceGeneration,
      );
      return true;
    }
    final deliveryAt = scheduledAt <= now
        ? now + const Duration(seconds: 1).inMicroseconds
        : scheduledAt;
    final plan = row.read<String>('plan_text').trim();
    final presentation =
        _presentation ??
        _notificationPresentation(
          LocaleMode.system,
          systemLocaleName: _systemLocaleName(),
        );
    await _gateway.schedule(
      LocalNotificationRequest(
        reminderId: reminderId,
        taskId: taskId,
        scheduleRevision: revision,
        notificationId: id,
        title: row.read<String>('title'),
        body: plan.isEmpty ? presentation.emptyPlanBody : plan,
        scheduledAtUtc: DateTime.fromMicrosecondsSinceEpoch(
          deliveryAt,
          isUtc: true,
        ),
        originalScheduledAtUtc: DateTime.fromMicrosecondsSinceEpoch(
          scheduledAt,
          isUtc: true,
        ),
        soundEnabled: row.read<bool>('sound_enabled'),
        vibrationEnabled: row.read<bool>('vibration_enabled'),
        defaultSnoozeMinutes: row.read<int>('default_snooze_minutes'),
        exactScheduling: _exactSchedulingAvailable,
        payload: ReminderNotificationActionIdentity(
          taskId: taskId,
          reminderId: reminderId,
          scheduleRevision: revision,
          sessionId: _ordinaryNotificationSession(
            reminderId,
            revision,
            deviceGeneration: deviceGeneration,
          ),
          deviceGeneration: deviceGeneration,
        ).encode(),
        localeTag: presentation.localeTag,
        deviceGeneration: deviceGeneration,
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
    if (current == null ||
        current.read<int>('schedule_revision') != revision ||
        current.read<String>('status') != ReminderStatus.scheduled.name) {
      await _cancelPlatformReminder(
        reminderId: reminderId,
        notificationId: id,
        deviceGeneration: deviceGeneration,
      );
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

  Future<void> _cancel(
    DangguiDatabase database,
    QueryRow row,
    String? deviceGeneration,
  ) async {
    final reminderId = row.read<String>('reminder_id');
    final revision = row.read<int>('aggregate_revision');
    await _cancelPlatformReminder(
      reminderId: reminderId,
      notificationId: _notificationId(reminderId),
      deviceGeneration: deviceGeneration,
    );
    await database.customStatement(
      'DELETE FROM notification_registrations '
      'WHERE reminder_id = ? AND schedule_revision <= ?',
      <Object?>[reminderId, revision],
    );
  }

  Future<void> _cancelPlatformReminder({
    required String reminderId,
    required int notificationId,
    required String? deviceGeneration,
  }) async {
    final gateway = _gateway;
    if (gateway is NativeReminderGateway) {
      await (gateway as NativeReminderGateway).cancelReminder(
        reminderId: reminderId,
        notificationId: notificationId,
        deviceGeneration: deviceGeneration,
      );
      return;
    }
    await gateway.cancel(notificationId);
  }

  Future<void> _restorePermissionDeniedReminders({bool? soundEnabled}) async {
    final database = await _readDatabase();
    final now = _nowMicros();
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            'SELECT r.id, r.task_id, r.status, r.schedule_revision, '
            'r.scheduled_at_utc FROM reminders r '
            'JOIN tasks t ON t.id = r.task_id '
            'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ? '
            '${soundEnabled == null ? '' : 'AND r.sound_enabled = ?'}',
            variables: <Variable<Object>>[
              Variable.withString(ReminderStatus.permissionDenied.name),
              Variable.withInt(now),
              Variable.withString(TaskStatus.active.name),
              if (soundEnabled != null) Variable.withInt(soundEnabled ? 1 : 0),
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
    DangguiDatabase database, {
    bool? soundEnabled,
  }) async {
    final now = _nowMicros();
    await database.transaction(() async {
      final rows = await database
          .customSelect(
            'SELECT r.id, r.task_id, r.status, r.schedule_revision, '
            'r.scheduled_at_utc FROM reminders r '
            'JOIN tasks t ON t.id = r.task_id '
            'WHERE r.status = ? AND r.scheduled_at_utc > ? AND t.status = ? '
            '${soundEnabled == null ? '' : 'AND r.sound_enabled = ?'}',
            variables: <Variable<Object>>[
              Variable.withString(ReminderStatus.scheduled.name),
              Variable.withInt(now),
              Variable.withString(TaskStatus.active.name),
              if (soundEnabled != null) Variable.withInt(soundEnabled ? 1 : 0),
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

final class _FlutterNotificationGateway
    implements
        NotificationGateway,
        PendingNotificationPayloadGateway,
        ReminderCapabilityGateway,
        NativeReminderGateway,
        DeviceAlarmGenerationGateway,
        NativeReminderRouteGateway {
  _FlutterNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    NativeAlarmPlatform? nativeAlarmPlatform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _nativeAlarmPlatform =
           nativeAlarmPlatform ?? MethodChannelNativeAlarmPlatform();

  final FlutterLocalNotificationsPlugin _plugin;
  final NativeAlarmPlatform _nativeAlarmPlatform;
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
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final nativeCapabilities = await _nativeAlarmPlatform.getCapabilities();
    if (nativeCapabilities.supported) {
      return _nativeAlarmPlatform.requestExactAlarmPermission();
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final requested = await android?.requestExactAlarmsPermission();
    if (requested != null) return requested;
    return await android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<ReminderDeliveryCapabilities> deliveryCapabilities({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    final nativeCapabilities = await _nativeAlarmPlatform.getCapabilities();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final pluginNotificationsGranted = await android
          ?.areNotificationsEnabled();
      var exactSchedulingAvailable =
          nativeCapabilities.exactAlarmAllowed ?? false;
      if (nativeCapabilities.exactAlarmAllowed == null) {
        try {
          exactSchedulingAvailable =
              await android?.canScheduleExactNotifications() ?? false;
        } on Object {
          // Falling back to an inexact alarm is safer than abandoning delivery
          // when an OEM implementation cannot answer the special-access query.
          exactSchedulingAvailable = false;
        }
      }
      AndroidNotificationChannel? selectedChannel;
      try {
        final channels = await android?.getNotificationChannels();
        if (channels != null) {
          final expectedId = _reminderChannelId(
            soundEnabled: soundEnabled,
            vibrationEnabled: vibrationEnabled,
          );
          for (final channel in channels) {
            if (channel.id == expectedId) {
              selectedChannel = channel;
              break;
            }
          }
        }
      } on Object {
        // Channel diagnostics are advisory. Scheduling must continue when an
        // OEM omits or rejects the channel-list API.
      }
      final channelEnabled =
          selectedChannel == null ||
          selectedChannel.importance.value > Importance.none.value;
      final nativeAlarmChannelEnabled = nativeCapabilities.alarmChannelEnabled;
      final nativeSoundAvailable = nativeAlarmChannelEnabled == false
          ? false
          : nativeCapabilities.alarmVolumeAudible;
      final notificationsGranted =
          nativeCapabilities.notificationsEnabled ?? pluginNotificationsGranted;
      final usesNativeRingingChannel = shouldUseNativeAlarmRoute(
        soundEnabled: soundEnabled,
        nativeSupported: nativeCapabilities.supported,
        isAndroid: true,
        exactAlarmAllowed: nativeCapabilities.exactAlarmAllowed,
        alarmAuthorization: nativeCapabilities.alarmAuthorization,
      );
      final selectedDeliveryChannelReady = selectedAndroidDeliveryChannelReady(
        usesNativeAlarmRoute: usesNativeRingingChannel,
        nativeAlarmChannelEnabled: nativeAlarmChannelEnabled,
        ordinaryChannelEnabled: channelEnabled,
      );
      final resolvedDelivery = resolveAndroidAlarmDeliveryLevel(
        soundEnabled: soundEnabled,
        nativeSupported: usesNativeRingingChannel,
        exactSchedulingAvailable: exactSchedulingAvailable,
        notificationsGranted: notificationsGranted,
        selectedDeliveryChannelReady: selectedDeliveryChannelReady,
        nativeReportedLevel: nativeCapabilities.deliveryLevel,
      );
      return ReminderDeliveryCapabilities(
        notificationsGranted: notificationsGranted,
        exactSchedulingAvailable: exactSchedulingAvailable,
        exactAlarmPermissionRequired: !exactSchedulingAvailable,
        soundAvailable: !soundEnabled
            ? null
            : usesNativeRingingChannel
            ? nativeSoundAvailable
            : selectedChannel == null
            ? null
            : channelEnabled && selectedChannel.playSound,
        vibrationAvailable:
            !vibrationEnabled ||
                usesNativeRingingChannel ||
                selectedChannel == null
            ? null
            : channelEnabled && selectedChannel.enableVibration,
        vibrationControlledBySystem: false,
        deliveryLevel: resolvedDelivery.deliveryLevel,
        strongAlarmAuthorized: resolvedDelivery.strongAlarmAuthorized,
      );
    }

    final options = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    final alarmKitAuthorized =
        soundEnabled &&
        nativeCapabilities.supported &&
        nativeCapabilities.alarmAuthorization ==
            NativeAlarmAuthorization.authorized;
    return ReminderDeliveryCapabilities(
      notificationsGranted: alarmKitAuthorized || (options?.isEnabled == true),
      exactSchedulingAvailable: true,
      exactAlarmPermissionRequired: false,
      soundAvailable: !soundEnabled
          ? null
          : alarmKitAuthorized
          ? true
          : options == null
          ? null
          : options.isAlertEnabled && options.isSoundEnabled,
      vibrationAvailable: null,
      vibrationControlledBySystem: true,
      deliveryLevel: !soundEnabled
          ? (options?.isEnabled == false
                ? ReminderDeliveryLevel.unavailable
                : ReminderDeliveryLevel.ordinary)
          : alarmKitAuthorized
          ? ReminderDeliveryLevel.alarmGrade
          : options?.isEnabled != true
          ? ReminderDeliveryLevel.unavailable
          : nativeCapabilities.timeSensitiveEnabled == true
          ? ReminderDeliveryLevel.timeSensitiveBestEffort
          : ReminderDeliveryLevel.ordinary,
      strongAlarmAuthorized: !soundEnabled || alarmKitAuthorized,
      timeSensitiveAvailable: !soundEnabled || alarmKitAuthorized
          ? true
          : nativeCapabilities.timeSensitiveEnabled,
    );
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
    final requests = await pendingNotificationSnapshots();
    final ids = <int>{for (final request in requests) request.notificationId};
    for (final snapshot in await _nativeAlarmPlatform.listAlarmSnapshots()) {
      if (snapshot.state.isActive) {
        ids.add(_notificationId(snapshot.reminderId));
      }
    }
    return ids;
  }

  @override
  Future<List<PendingLocalNotificationSnapshot>>
  pendingNotificationSnapshots() async {
    final requests = await _plugin.pendingNotificationRequests();
    return <PendingLocalNotificationSnapshot>[
      for (final request in requests)
        PendingLocalNotificationSnapshot(
          notificationId: request.id,
          payload: request.payload,
        ),
    ];
  }

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    final presentation = _presentation;
    if (presentation == null) {
      throw StateError('Notification gateway has not been initialized.');
    }
    if (request.soundEnabled) {
      final capabilities = await _nativeAlarmPlatform.getCapabilities();
      final useNativeAlarm = shouldUseNativeAlarmRoute(
        soundEnabled: request.soundEnabled,
        nativeSupported: capabilities.supported,
        isAndroid: Platform.isAndroid,
        exactAlarmAllowed: capabilities.exactAlarmAllowed,
        alarmAuthorization: capabilities.alarmAuthorization,
      );
      if (useNativeAlarm) {
        await _nativeAlarmPlatform.scheduleAlarm(
          NativeAlarmRequest(
            reminderId: request.reminderId,
            taskId: request.taskId,
            scheduleRevision: request.scheduleRevision,
            triggerAtUtc: nativeAlarmTriggerAtUtc(request),
            title: request.title,
            body: request.body,
            vibrationEnabled: request.vibrationEnabled,
            defaultSnoozeMinutes: request.defaultSnoozeMinutes,
            localeTag: request.localeTag,
            deviceGeneration: request.deviceGeneration,
          ),
        );
        await _plugin.cancel(id: request.notificationId);
        return;
      }
    }
    await _plugin.zonedSchedule(
      id: request.notificationId,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAtUtc, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId(
            soundEnabled: request.soundEnabled,
            vibrationEnabled: request.vibrationEnabled,
          ),
          presentation.channelName,
          channelDescription: presentation.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_stat_danggui',
          playSound: request.soundEnabled,
          enableVibration: request.vibrationEnabled,
          vibrationPattern: request.vibrationEnabled
              ? _defaultVibrationPattern
              : null,
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
          interruptionLevel: request.soundEnabled
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: request.exactScheduling
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payload,
    );
    await retireNativeRouteAfterOrdinarySchedule(
      _nativeAlarmPlatform,
      reminderId: request.reminderId,
      scheduleRevision: request.scheduleRevision,
      deviceGeneration: request.deviceGeneration,
      isIOS: Platform.isIOS,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);

  @override
  Future<NativeAlarmCapabilities> nativeAlarmCapabilities() =>
      _nativeAlarmPlatform.getCapabilities();

  @override
  Future<bool> requestAlarmAuthorization() =>
      _nativeAlarmPlatform.requestAlarmAuthorization();

  @override
  Future<bool> requestFullScreenPermission() =>
      _nativeAlarmPlatform.requestFullScreenPermission();

  @override
  Future<void> openNotificationSettings() =>
      _nativeAlarmPlatform.openNotificationSettings();

  @override
  Future<void> openAlarmSoundSettings() =>
      _nativeAlarmPlatform.openAlarmSoundSettings();

  @override
  Future<bool> openOemAutostartSettings() =>
      _nativeAlarmPlatform.openOemAutostartSettings();

  @override
  Future<void> activateDeviceGeneration(String? deviceGeneration) =>
      _nativeAlarmPlatform.activateDeviceGeneration(deviceGeneration);

  @override
  Future<void> retireNativeReminderRoute({
    required String reminderId,
    required int scheduleRevision,
    required String sessionId,
    required String? deviceGeneration,
  }) => _nativeAlarmPlatform.retireNativeAlarmRoute(
    reminderId,
    scheduleRevision: scheduleRevision,
    sessionId: sessionId,
    deviceGeneration: deviceGeneration,
  );

  @override
  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    required bool vibrationEnabled,
  }) async {
    final capabilities = await _nativeAlarmPlatform.getCapabilities();
    if (capabilities.supported) {
      await _nativeAlarmPlatform.scheduleTestAlarm(
        title: title,
        body: body,
        vibrationEnabled: vibrationEnabled,
      );
      return;
    }
    final presentation = _presentation;
    if (presentation == null) {
      throw StateError('Notification gateway has not been initialized.');
    }
    await _plugin.zonedSchedule(
      id: _notificationId('__danggui_test_alarm__'),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(const Duration(seconds: 15)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId(
            soundEnabled: true,
            vibrationEnabled: vibrationEnabled,
          ),
          presentation.channelName,
          channelDescription: presentation.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          icon: 'ic_stat_danggui',
          playSound: true,
          enableVibration: vibrationEnabled,
          vibrationPattern: vibrationEnabled ? _defaultVibrationPattern : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'danggui-reminders',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'task:__danggui_test_alarm__',
    );
  }

  @override
  Future<void> cancelReminder({
    required String reminderId,
    required int notificationId,
    String? deviceGeneration,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _nativeAlarmPlatform.cancelAlarm(
        reminderId,
        deviceGeneration: deviceGeneration,
      );
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _plugin.cancel(id: notificationId);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  @override
  Future<List<NativeAlarmEvent>> drainAlarmEvents() =>
      _nativeAlarmPlatform.drainAlarmEvents();

  @override
  Future<void> acknowledgeAlarmEvents(Set<String> eventIds) =>
      _nativeAlarmPlatform.acknowledgeAlarmEvents(eventIds);

  @override
  Future<List<NativeAlarmSnapshot>> activeNativeAlarmSnapshots() =>
      _nativeAlarmPlatform.listAlarmSnapshots();
}

/// Retires a superseded native delivery route after the ordinary notification
/// has been durably scheduled.
///
/// iOS capability fallback is reversible: losing AlarmKit authorization must
/// not create a business cancellation high-water mark that permanently blocks
/// the same revision when authorization returns. Android's ordinary route
/// continues to use the existing business cancellation contract.
@visibleForTesting
Future<void> retireNativeRouteAfterOrdinarySchedule(
  NativeAlarmPlatform nativeAlarmPlatform, {
  required String reminderId,
  required int scheduleRevision,
  String? deviceGeneration,
  required bool isIOS,
}) {
  if (isIOS) {
    return nativeAlarmPlatform.retireNativeAlarmRoute(
      reminderId,
      scheduleRevision: scheduleRevision,
      sessionId: deterministicNativeAlarmSessionId(
        reminderId,
        scheduleRevision,
        deviceGeneration: deviceGeneration,
      ),
      deviceGeneration: deviceGeneration,
    );
  }
  return nativeAlarmPlatform.cancelAlarm(
    reminderId,
    deviceGeneration: deviceGeneration,
  );
}

String _reminderChannelId({
  required bool soundEnabled,
  required bool vibrationEnabled,
}) =>
    'danggui-reminders-'
    '${soundEnabled ? 'sound' : 'silent'}-'
    '${vibrationEnabled ? 'vibrate' : 'steady'}';

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

int _notificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

String _ordinaryNotificationSession(
  String reminderId,
  int revision, {
  String? deviceGeneration,
}) => deviceGeneration == null
    ? 'ordinary:${_notificationId(reminderId)}:$revision'
    : 'ordinary:${_notificationId(reminderId)}:$revision:$deviceGeneration';

bool _pendingIdentityMatches(
  String? payload, {
  required String reminderId,
  required String taskId,
  required int scheduleRevision,
  String? deviceGeneration,
}) {
  final identity = ReminderNotificationActionIdentity.tryDecode(payload);
  return identity != null &&
      identity.reminderId == reminderId &&
      identity.taskId == taskId &&
      identity.scheduleRevision == scheduleRevision &&
      identity.deviceGeneration == deviceGeneration &&
      identity.sessionId ==
          _ordinaryNotificationSession(
            reminderId,
            scheduleRevision,
            deviceGeneration: deviceGeneration,
          );
}

Future<String?> _currentDeviceAlarmGeneration(DangguiDatabase database) async {
  final generation = await DeviceAlarmGenerationStore(database).readCurrent();
  return generation.startsWith('legacy:') ? null : generation.toLowerCase();
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
  r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

String? _legacyManagedTaskId(String? payload) {
  const prefix = 'task:';
  if (payload == null || !payload.startsWith(prefix)) return null;
  final taskId = payload.substring(prefix.length).trim();
  if (taskId.isEmpty || taskId == '__danggui_test_alarm__') return null;
  return taskId;
}

bool _timeZoneDatabaseInitialized = false;

({DateTime localDateTime, String zoneId}) _localDateTimeAndZone(
  DateTime scheduledUtc,
  String zoneId,
) {
  final normalizedZoneId = zoneId.trim();
  if (normalizedZoneId.isEmpty) {
    return (localDateTime: scheduledUtc.toUtc(), zoneId: 'UTC');
  }
  try {
    if (!_timeZoneDatabaseInitialized) {
      tz_data.initializeTimeZones();
      _timeZoneDatabaseInitialized = true;
    }
    final location = normalizedZoneId == 'UTC'
        ? tz.UTC
        : tz.getLocation(normalizedZoneId);
    return (
      localDateTime: tz.TZDateTime.from(scheduledUtc.toUtc(), location),
      zoneId: normalizedZoneId,
    );
  } on Object {
    // An invalid legacy zone and a process-local timestamp form a misleading
    // pair. Normalize both fields to UTC so future reads remain deterministic.
    return (localDateTime: scheduledUtc.toUtc(), zoneId: 'UTC');
  }
}

String _errorCode(Object error) {
  final type = error.runtimeType.toString();
  final normalized = type.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
