import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const reminderPlatformChannelName = 'com.danggui.memo/reminder_platform';
const _maximumSignedInt64 = 9223372036854775807;
const _minimumSignedInt64 = -9223372036854775808;
// Dart DateTime is limited to +/- 100,000,000 days from the Unix epoch. Keep
// native values inside that range before constructing DateTime or converting
// them to the SQLite microsecond representation.
const _maximumSafeEpochMilliseconds = 8640000000000;
const _supportedNativeSnoozeMinutes = <int>{10, 30, 60};

/// Stable session identifier shared by AlarmKit, Android, and Dart.
///
/// This is byte-for-byte equivalent to `DangguiAlarmIdentifier.platformID`
/// in the iOS bridge. Binding a mutable native event to this value prevents a
/// delayed or forged session from changing a newer reminder revision.
String deterministicNativeAlarmSessionId(
  String reminderId,
  int scheduleRevision, {
  String? deviceGeneration,
}) {
  final normalizedGeneration = deviceGeneration?.trim().toLowerCase();
  final identity = normalizedGeneration == null || normalizedGeneration.isEmpty
      ? '$reminderId\u001f$scheduleRevision'
      : '$reminderId\u001f$scheduleRevision\u001f$normalizedGeneration';
  final bytes = utf8.encode(identity);
  final first = _fnv1a64(bytes, BigInt.parse('cbf29ce484222325', radix: 16));
  final second = _fnv1a64(
    bytes.reversed,
    BigInt.parse('84222325cbf29ce4', radix: 16),
  );
  final characters = <String>[
    ...first.toRadixString(16).padLeft(16, '0').split(''),
    ...second.toRadixString(16).padLeft(16, '0').split(''),
  ];
  // Match the name-derived version and RFC 4122 variant bits used by iOS.
  characters[12] = '5';
  characters[16] = 'a';
  final compact = characters.join();
  return '${compact.substring(0, 8)}-${compact.substring(8, 12)}-'
      '${compact.substring(12, 16)}-${compact.substring(16, 20)}-'
      '${compact.substring(20)}';
}

BigInt _fnv1a64(Iterable<int> bytes, BigInt seed) {
  var hash = seed;
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in bytes) {
    hash ^= BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return hash;
}

enum NativeAlarmAuthorization { unavailable, notDetermined, denied, authorized }

/// Cross-platform delivery guarantees exposed to the Dart layer.
///
/// The wire values intentionally use kebab-case so diagnostics produced by
/// Android, iOS and Dart can be compared without platform-specific aliases.
enum ReminderDeliveryLevel {
  alarmGrade,
  timeSensitiveBestEffort,
  ordinary,
  unavailable;

  String get wireName => switch (this) {
    ReminderDeliveryLevel.alarmGrade => 'alarm-grade',
    ReminderDeliveryLevel.timeSensitiveBestEffort =>
      'time-sensitive-best-effort',
    ReminderDeliveryLevel.ordinary => 'ordinary',
    ReminderDeliveryLevel.unavailable => 'unavailable',
  };
}

final class NativeAlarmCapabilities {
  const NativeAlarmCapabilities({
    required this.supported,
    required this.platform,
    this.notificationsEnabled,
    this.exactAlarmAllowed,
    this.fullScreenAllowed,
    this.alarmVolumeAudible,
    this.alarmChannelEnabled,
    this.alarmChannelImportance,
    this.oemSetupAvailable = false,
    this.manufacturer,
    this.alarmAuthorization = NativeAlarmAuthorization.unavailable,
    this.timeSensitiveEnabled,
    this.reportedDeliveryLevel,
  });

  const NativeAlarmCapabilities.unsupported()
    : supported = false,
      platform = 'unsupported',
      notificationsEnabled = null,
      exactAlarmAllowed = null,
      fullScreenAllowed = null,
      alarmVolumeAudible = null,
      alarmChannelEnabled = null,
      alarmChannelImportance = null,
      oemSetupAvailable = false,
      manufacturer = null,
      alarmAuthorization = NativeAlarmAuthorization.unavailable,
      timeSensitiveEnabled = null,
      reportedDeliveryLevel = ReminderDeliveryLevel.unavailable;

  final bool supported;
  final String platform;
  final bool? notificationsEnabled;
  final bool? exactAlarmAllowed;
  final bool? fullScreenAllowed;
  final bool? alarmVolumeAudible;
  final bool? alarmChannelEnabled;
  final int? alarmChannelImportance;
  final bool oemSetupAvailable;
  final String? manufacturer;
  final NativeAlarmAuthorization alarmAuthorization;
  final bool? timeSensitiveEnabled;
  final ReminderDeliveryLevel? reportedDeliveryLevel;

  ReminderDeliveryLevel get deliveryLevel {
    final reported = reportedDeliveryLevel;
    if (reported != null) return reported;
    if (platform == 'ios') {
      if (supported &&
          alarmAuthorization == NativeAlarmAuthorization.authorized) {
        return ReminderDeliveryLevel.alarmGrade;
      }
      if (notificationsEnabled == false) {
        return ReminderDeliveryLevel.unavailable;
      }
      if (timeSensitiveEnabled == true) {
        return ReminderDeliveryLevel.timeSensitiveBestEffort;
      }
      return notificationsEnabled == true
          ? ReminderDeliveryLevel.ordinary
          : ReminderDeliveryLevel.unavailable;
    }
    if (platform == 'android') {
      if (supported && exactAlarmAllowed == true) {
        return ReminderDeliveryLevel.alarmGrade;
      }
      return notificationsEnabled == false
          ? ReminderDeliveryLevel.unavailable
          : ReminderDeliveryLevel.ordinary;
    }
    return supported
        ? ReminderDeliveryLevel.ordinary
        : ReminderDeliveryLevel.unavailable;
  }

  bool get strongAlarmAuthorized {
    if (!supported) return false;
    if (platform == 'ios') {
      return supported &&
          alarmAuthorization == NativeAlarmAuthorization.authorized;
    }
    return exactAlarmAllowed == true;
  }

  factory NativeAlarmCapabilities.fromMap(Map<Object?, Object?> map) {
    final alarms = _asMap(map['alarms']);
    final platform =
        _string(map, 'platform') ??
        (!kIsWeb && Platform.isIOS ? 'ios' : 'android');
    final rawAuthorization =
        _string(map, 'alarmAuthorization') ??
        _string(map, 'authorizationState') ??
        (alarms == null ? null : _string(alarms, 'authorization')) ??
        'unavailable';
    return NativeAlarmCapabilities(
      supported:
          _bool(map, 'supported') ??
          _bool(map, 'alarmKitSupported') ??
          (alarms == null ? null : _bool(alarms, 'supported')) ??
          true,
      platform: platform,
      notificationsEnabled:
          _bool(map, 'notificationsEnabled') ??
          _bool(map, 'notificationsGranted') ??
          _bool(map, 'notificationAuthorized'),
      exactAlarmAllowed:
          _bool(map, 'exactAlarmAllowed') ??
          _bool(map, 'canScheduleExactAlarms'),
      fullScreenAllowed:
          _bool(map, 'fullScreenAllowed') ??
          _bool(map, 'fullScreenPermissionGranted') ??
          _bool(map, 'canUseFullScreenIntent'),
      alarmVolumeAudible:
          _bool(map, 'alarmVolumeAudible') ??
          _positiveNumber(map, 'alarmVolume'),
      alarmChannelEnabled: _bool(map, 'alarmChannelEnabled'),
      alarmChannelImportance: _int(map, 'alarmChannelImportance'),
      oemSetupAvailable:
          _bool(map, 'oemSetupAvailable') ??
          _bool(map, 'oemSettingsAvailable') ??
          false,
      manufacturer: _string(map, 'manufacturer'),
      alarmAuthorization: switch (rawAuthorization.toLowerCase()) {
        'authorized' || 'granted' => NativeAlarmAuthorization.authorized,
        'denied' => NativeAlarmAuthorization.denied,
        'notdetermined' ||
        'not_determined' => NativeAlarmAuthorization.notDetermined,
        _ => NativeAlarmAuthorization.unavailable,
      },
      timeSensitiveEnabled:
          _bool(map, 'timeSensitiveEnabled') ??
          _bool(map, 'timeSensitiveSupported') ??
          _bool(map, 'timeSensitiveAuthorized'),
      reportedDeliveryLevel: _deliveryLevel(
        _string(map, 'deliveryLevel') ??
            _string(map, 'deliveryCapability') ??
            _string(map, 'capabilityLevel'),
      ),
    );
  }
}

enum NativeAlarmSnapshotState {
  registered,
  ringing,
  stopped,
  snoozed,
  missed,
  capacityDeferred,
  unknown;

  bool get isActive =>
      this == NativeAlarmSnapshotState.registered ||
      this == NativeAlarmSnapshotState.ringing ||
      this == NativeAlarmSnapshotState.snoozed;
}

/// Authoritative platform state used for startup diff reconciliation.
final class NativeAlarmSnapshot {
  const NativeAlarmSnapshot({
    required this.reminderId,
    required this.platformId,
    required this.scheduleRevision,
    required this.triggerAtEpochMs,
    required this.state,
    this.deviceGeneration,
  });

  final String reminderId;
  final String platformId;
  final int scheduleRevision;
  final int triggerAtEpochMs;
  final NativeAlarmSnapshotState state;
  final String? deviceGeneration;

  factory NativeAlarmSnapshot.fromMap(Map<Object?, Object?> map) {
    final reminderId =
        _string(map, 'reminderId') ?? _string(map, 'alarmId') ?? '';
    final rawState = _normalizedWireName(
      _string(map, 'state') ?? _string(map, 'status'),
    );
    return NativeAlarmSnapshot(
      reminderId: reminderId,
      platformId:
          _string(map, 'platformId') ??
          _string(map, 'nativeId') ??
          _string(map, 'id') ??
          reminderId,
      scheduleRevision:
          _int(map, 'scheduleRevision') ?? _int(map, 'revision') ?? 0,
      triggerAtEpochMs:
          _int(map, 'triggerAtEpochMs') ??
          _int(map, 'scheduledAtEpochMs') ??
          _int(map, 'triggerAt') ??
          0,
      state: switch (rawState) {
        'registered' ||
        'scheduled' ||
        'pending' => NativeAlarmSnapshotState.registered,
        'ringing' || 'firing' || 'active' => NativeAlarmSnapshotState.ringing,
        'stopped' || 'stop' => NativeAlarmSnapshotState.stopped,
        'snoozed' || 'snooze' => NativeAlarmSnapshotState.snoozed,
        'missed' || 'expired' => NativeAlarmSnapshotState.missed,
        'capacitydeferred' ||
        'deferred' => NativeAlarmSnapshotState.capacityDeferred,
        _ => NativeAlarmSnapshotState.unknown,
      },
      deviceGeneration:
          _string(map, 'deviceGeneration') ?? _string(map, 'alarmGeneration'),
    );
  }
}

final class NativeAlarmRequest {
  const NativeAlarmRequest({
    required this.reminderId,
    required this.taskId,
    required this.scheduleRevision,
    required this.triggerAtUtc,
    required this.title,
    required this.body,
    required this.vibrationEnabled,
    required this.defaultSnoozeMinutes,
    required this.localeTag,
    this.deviceGeneration,
  });

  final String reminderId;
  final String taskId;
  final int scheduleRevision;
  final DateTime triggerAtUtc;
  final String title;
  final String body;
  final bool vibrationEnabled;
  final int defaultSnoozeMinutes;
  final String localeTag;
  final String? deviceGeneration;

  Map<String, Object?> toMap() => <String, Object?>{
    'reminderId': reminderId,
    'alarmId': reminderId,
    'taskId': taskId,
    'scheduleRevision': scheduleRevision,
    'revision': scheduleRevision,
    'triggerAtEpochMs': triggerAtUtc.toUtc().millisecondsSinceEpoch,
    'scheduledAtEpochMs': triggerAtUtc.toUtc().millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'vibrationEnabled': vibrationEnabled,
    'defaultSnoozeMinutes': defaultSnoozeMinutes,
    'localeTag': localeTag,
    'deviceGeneration': ?deviceGeneration,
  };
}

enum NativeAlarmEventType {
  registered,
  delivered,
  foreground,
  systemAlert,
  audio,
  vibration,
  missed,
  stopped,
  snoozed,
  error,
}

final class NativeAlarmEvent {
  const NativeAlarmEvent({
    required this.eventId,
    required this.reminderId,
    required this.taskId,
    required this.scheduleRevision,
    required this.type,
    required this.occurredAtUtc,
    this.snoozeMinutes,
    this.successorTriggerAtEpochMs,
    this.sessionId,
    this.deviceGeneration,
    this.errorCode,
  });

  final String eventId;
  final String reminderId;
  final String taskId;
  final int scheduleRevision;
  final NativeAlarmEventType type;
  final DateTime occurredAtUtc;
  final int? snoozeMinutes;
  final int? successorTriggerAtEpochMs;
  final String? sessionId;
  final String? deviceGeneration;
  final String? errorCode;

  factory NativeAlarmEvent.fromMap(Map<Object?, Object?> map) {
    try {
      return _fromMap(map);
    } on Object {
      // Method-channel values normally contain primitives only. Still keep one
      // malformed platform value from preventing every later durable Stop,
      // Snooze, Missed, or Delivered event from being drained and acknowledged.
      return _invalidEnvelope(map);
    }
  }

  static NativeAlarmEvent _fromMap(Map<Object?, Object?> map) {
    final rawType = _normalizedWireName(
      _string(map, 'type') ?? _string(map, 'eventType'),
    );
    final parsedType = switch (rawType) {
      'registered' || 'scheduled' => NativeAlarmEventType.registered,
      'delivered' || 'fired' || 'fire' => NativeAlarmEventType.delivered,
      'foreground' => NativeAlarmEventType.foreground,
      'systemalert' => NativeAlarmEventType.systemAlert,
      'audio' => NativeAlarmEventType.audio,
      'vibration' || 'vibrate' => NativeAlarmEventType.vibration,
      'missed' || 'expired' => NativeAlarmEventType.missed,
      'stopped' || 'stop' => NativeAlarmEventType.stopped,
      'snoozed' || 'snooze' => NativeAlarmEventType.snoozed,
      _ => NativeAlarmEventType.error,
    };
    final eventId = _string(map, 'eventId')?.trim();
    final reminderId =
        (_string(map, 'reminderId') ?? _string(map, 'alarmId') ?? '').trim();
    final occurredAtMs =
        _safeInt(map, 'occurredAtEpochMs') ?? _safeInt(map, 'occurredAt');
    final revision =
        _safeInt(map, 'scheduleRevision') ?? _safeInt(map, 'revision') ?? 0;
    final snoozeMinutes = _safeInt(map, 'snoozeMinutes');
    final successorPresent =
        map.containsKey('successorTriggerAtEpochMs') ||
        map.containsKey('nextTriggerAtEpochMs');
    final successorTriggerAtEpochMs =
        _safeInt(map, 'successorTriggerAtEpochMs') ??
        _safeInt(map, 'nextTriggerAtEpochMs');
    final mutatesBusinessState = switch (parsedType) {
      NativeAlarmEventType.delivered ||
      NativeAlarmEventType.missed ||
      NativeAlarmEventType.stopped ||
      NativeAlarmEventType.snoozed => true,
      _ => false,
    };
    final validBusinessEnvelope =
        !mutatesBusinessState ||
        (eventId != null &&
            eventId.isNotEmpty &&
            reminderId.isNotEmpty &&
            revision > 0 &&
            _isSafeEpochMilliseconds(occurredAtMs) &&
            (parsedType != NativeAlarmEventType.snoozed ||
                _supportedNativeSnoozeMinutes.contains(snoozeMinutes)) &&
            (!successorPresent ||
                _isSafeEpochMilliseconds(successorTriggerAtEpochMs)));
    final safeOccurredAtMs = _isSafeEpochMilliseconds(occurredAtMs)
        ? occurredAtMs!
        : DateTime.now().toUtc().millisecondsSinceEpoch;
    return NativeAlarmEvent(
      eventId: eventId == null || eventId.isEmpty
          ? '$reminderId:$safeOccurredAtMs:$rawType'
          : eventId,
      reminderId: reminderId,
      taskId: (_string(map, 'taskId') ?? '').trim(),
      scheduleRevision: revision,
      type: validBusinessEnvelope ? parsedType : NativeAlarmEventType.error,
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        safeOccurredAtMs,
        isUtc: true,
      ),
      snoozeMinutes: snoozeMinutes,
      successorTriggerAtEpochMs: successorTriggerAtEpochMs,
      sessionId: _string(map, 'sessionId') ?? _string(map, 'session'),
      deviceGeneration:
          _string(map, 'deviceGeneration') ?? _string(map, 'alarmGeneration'),
      errorCode: validBusinessEnvelope
          ? _string(map, 'errorCode') ?? _string(map, 'code')
          : 'invalid_event_envelope',
    );
  }

  static NativeAlarmEvent _invalidEnvelope(Map<Object?, Object?> map) {
    final now = DateTime.now().toUtc();
    final eventId = map['eventId'];
    final reminderId = map['reminderId'];
    return NativeAlarmEvent(
      eventId: eventId is String && eventId.trim().isNotEmpty
          ? eventId.trim()
          : 'invalid:${now.microsecondsSinceEpoch}',
      reminderId: reminderId is String ? reminderId.trim() : '',
      taskId: '',
      scheduleRevision: 0,
      type: NativeAlarmEventType.error,
      occurredAtUtc: now,
      errorCode: 'invalid_event_envelope',
    );
  }
}

abstract interface class NativeAlarmPlatform {
  bool get isSupported;

  Future<NativeAlarmCapabilities> getCapabilities();
  Future<bool> requestExactAlarmPermission();
  Future<bool> requestFullScreenPermission();
  Future<bool> requestAlarmAuthorization();
  Future<void> openNotificationSettings();
  Future<void> openAlarmSoundSettings();
  Future<bool> openOemAutostartSettings();
  Future<void> activateDeviceGeneration(String? deviceGeneration);
  Future<void> scheduleAlarm(NativeAlarmRequest request);
  Future<void> cancelAlarm(String reminderId, {String? deviceGeneration});

  /// Retires only the current native delivery route for [reminderId].
  ///
  /// Unlike [cancelAlarm], this is not a business cancellation. It permits the
  /// same logical revision to move back to a stronger native route when a
  /// temporary platform capability (for example AlarmKit authorization) is
  /// restored.
  Future<void> retireNativeAlarmRoute(
    String reminderId, {
    required int scheduleRevision,
    required String sessionId,
    String? deviceGeneration,
  });
  Future<void> stopAlarm(
    String reminderId, {
    required int scheduleRevision,
    required String sessionId,
  });
  Future<void> snoozeAlarm(
    String reminderId,
    int minutes, {
    required int scheduleRevision,
    required String sessionId,
  });
  Future<List<NativeAlarmSnapshot>> listAlarmSnapshots();
  Future<Set<String>> listScheduledAlarmIds();
  Future<List<NativeAlarmEvent>> drainAlarmEvents();
  Future<void> acknowledgeAlarmEvents(Set<String> eventIds);
  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    required bool vibrationEnabled,
  });
}

final class MethodChannelNativeAlarmPlatform implements NativeAlarmPlatform {
  MethodChannelNativeAlarmPlatform({
    MethodChannel? channel,
    bool? isSupportedOverride,
  }) : this._(
         channel ?? const MethodChannel(reminderPlatformChannelName),
         isSupportedOverride,
       );

  MethodChannelNativeAlarmPlatform._(this._channel, this._isSupportedOverride);

  final MethodChannel _channel;
  final bool? _isSupportedOverride;

  @override
  bool get isSupported =>
      _isSupportedOverride ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  @override
  Future<NativeAlarmCapabilities> getCapabilities() async {
    if (!isSupported) return const NativeAlarmCapabilities.unsupported();
    try {
      final value = await _channel.invokeMethod<Object?>('getCapabilities');
      final map = _asMap(value);
      return map == null
          ? const NativeAlarmCapabilities.unsupported()
          : NativeAlarmCapabilities.fromMap(map);
    } on MissingPluginException {
      return const NativeAlarmCapabilities.unsupported();
    }
  }

  @override
  Future<bool> requestExactAlarmPermission() =>
      _invokeBool('requestExactAlarmPermission');

  @override
  Future<bool> requestFullScreenPermission() =>
      _invokeBool('requestFullScreenPermission');

  @override
  Future<bool> requestAlarmAuthorization() =>
      _invokeBool('requestAlarmAuthorization');

  @override
  Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  @override
  Future<void> openAlarmSoundSettings() =>
      _channel.invokeMethod<void>('openAlarmSoundSettings');

  @override
  Future<bool> openOemAutostartSettings() =>
      _invokeBool('openOemAutostartSettings');

  @override
  Future<void> activateDeviceGeneration(String? deviceGeneration) =>
      _channel.invokeMethod<void>('activateDeviceGeneration', <String, Object?>{
        'deviceGeneration': deviceGeneration,
        'generation': deviceGeneration,
      });

  @override
  Future<void> scheduleAlarm(NativeAlarmRequest request) =>
      _channel.invokeMethod<void>('scheduleAlarm', request.toMap());

  @override
  Future<void> cancelAlarm(String reminderId, {String? deviceGeneration}) =>
      _channel.invokeMethod<void>('cancelAlarm', <String, Object?>{
        'reminderId': reminderId,
        'alarmId': reminderId,
        'deviceGeneration': ?deviceGeneration,
        'generation': ?deviceGeneration,
      });

  @override
  Future<void> retireNativeAlarmRoute(
    String reminderId, {
    required int scheduleRevision,
    required String sessionId,
    String? deviceGeneration,
  }) => _channel.invokeMethod<void>('retireNativeAlarmRoute', <String, Object?>{
    'reminderId': reminderId,
    'alarmId': reminderId,
    'scheduleRevision': scheduleRevision,
    'revision': scheduleRevision,
    'sessionId': sessionId,
    'session': sessionId,
    'deviceGeneration': ?deviceGeneration,
  });

  @override
  Future<void> stopAlarm(
    String reminderId, {
    required int scheduleRevision,
    required String sessionId,
  }) => _channel.invokeMethod<void>('stopAlarm', <String, Object?>{
    'reminderId': reminderId,
    'alarmId': reminderId,
    'scheduleRevision': scheduleRevision,
    'revision': scheduleRevision,
    'sessionId': sessionId,
    'session': sessionId,
  });

  @override
  Future<void> snoozeAlarm(
    String reminderId,
    int minutes, {
    required int scheduleRevision,
    required String sessionId,
  }) => _channel.invokeMethod<void>('snoozeAlarm', <String, Object?>{
    'reminderId': reminderId,
    'alarmId': reminderId,
    'minutes': minutes,
    'snoozeMinutes': minutes,
    'scheduleRevision': scheduleRevision,
    'revision': scheduleRevision,
    'sessionId': sessionId,
    'session': sessionId,
  });

  @override
  Future<List<NativeAlarmSnapshot>> listAlarmSnapshots() async {
    if (!isSupported) return const <NativeAlarmSnapshot>[];
    try {
      final value = await _channel.invokeMethod<Object?>('listAlarmSnapshots');
      return _snapshotsFromValue(value);
    } on MissingPluginException {
      try {
        final legacy = await _channel.invokeMethod<Object?>(
          'listScheduledAlarms',
        );
        return _snapshotsFromValue(legacy);
      } on MissingPluginException {
        return const <NativeAlarmSnapshot>[];
      }
    }
  }

  @override
  Future<Set<String>> listScheduledAlarmIds() async {
    return <String>{
      for (final snapshot in await listAlarmSnapshots())
        if (snapshot.reminderId.isNotEmpty && snapshot.state.isActive)
          snapshot.reminderId,
    };
  }

  @override
  Future<List<NativeAlarmEvent>> drainAlarmEvents() async {
    if (!isSupported) return const <NativeAlarmEvent>[];
    try {
      final value = await _channel.invokeMethod<Object?>('drainAlarmEvents');
      if (value is! List<Object?>) return const <NativeAlarmEvent>[];
      return <NativeAlarmEvent>[
        for (final item in value)
          if (_asMap(item) case final map?) NativeAlarmEvent.fromMap(map),
      ];
    } on MissingPluginException {
      return const <NativeAlarmEvent>[];
    }
  }

  @override
  Future<void> acknowledgeAlarmEvents(Set<String> eventIds) async {
    if (!isSupported || eventIds.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('ackAlarmEvents', <String, Object?>{
        'eventIds': eventIds.toList(growable: false),
      });
    } on MissingPluginException {
      // A pre-1.1.3 platform implementation used destructive drain semantics,
      // so there is nothing left to acknowledge in that compatibility case.
    }
  }

  @override
  Future<void> scheduleTestAlarm({
    required String title,
    required String body,
    required bool vibrationEnabled,
  }) => _channel.invokeMethod<void>('scheduleTestAlarm', <String, Object?>{
    'title': title,
    'body': body,
    'vibrationEnabled': vibrationEnabled,
    'delaySeconds': 15,
  });

  Future<bool> _invokeBool(String method) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}

List<NativeAlarmSnapshot> _snapshotsFromValue(Object? value) {
  if (value is! List<Object?>) return const <NativeAlarmSnapshot>[];
  return <NativeAlarmSnapshot>[
    for (final item in value)
      if (item is String && item.isNotEmpty)
        NativeAlarmSnapshot(
          reminderId: item,
          platformId: item,
          scheduleRevision: 0,
          triggerAtEpochMs: 0,
          state: NativeAlarmSnapshotState.registered,
        )
      else if (_asMap(item) case final map?)
        NativeAlarmSnapshot.fromMap(map),
  ];
}

ReminderDeliveryLevel? _deliveryLevel(String? value) {
  return switch (_normalizedWireName(value)) {
    'alarmgrade' => ReminderDeliveryLevel.alarmGrade,
    'timesensitivebesteffort' => ReminderDeliveryLevel.timeSensitiveBestEffort,
    'ordinary' => ReminderDeliveryLevel.ordinary,
    'unavailable' => ReminderDeliveryLevel.unavailable,
    _ => null,
  };
}

String _normalizedWireName(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

Map<Object?, Object?>? _asMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return value.cast<Object?, Object?>();
  return null;
}

String? _string(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : value?.toString();
}

bool? _bool(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return null;
}

int? _int(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

int? _safeInt(Map<Object?, Object?> map, String key) {
  try {
    final value = _int(map, key);
    if (value == null ||
        value < _minimumSignedInt64 ||
        value > _maximumSignedInt64) {
      return null;
    }
    return value;
  } on Object {
    return null;
  }
}

bool _isSafeEpochMilliseconds(int? value) =>
    value != null && value > 0 && value <= _maximumSafeEpochMilliseconds;

bool? _positiveNumber(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is num) return value > 0;
  final parsed = num.tryParse(value?.toString() ?? '');
  return parsed == null ? null : parsed > 0;
}
