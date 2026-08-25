import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const reminderPlatformChannelName = 'com.danggui.memo/reminder_platform';

enum NativeAlarmAuthorization { unavailable, notDetermined, denied, authorized }

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
      timeSensitiveEnabled = null;

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

  bool get strongAlarmAuthorized {
    if (!supported) return false;
    if (platform == 'ios') {
      return alarmAuthorization == NativeAlarmAuthorization.authorized;
    }
    return exactAlarmAllowed != false;
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
  };
}

enum NativeAlarmEventType { fired, stopped, snoozed }

final class NativeAlarmEvent {
  const NativeAlarmEvent({
    required this.eventId,
    required this.reminderId,
    required this.taskId,
    required this.scheduleRevision,
    required this.type,
    required this.occurredAtUtc,
    this.snoozeMinutes,
  });

  final String eventId;
  final String reminderId;
  final String taskId;
  final int scheduleRevision;
  final NativeAlarmEventType type;
  final DateTime occurredAtUtc;
  final int? snoozeMinutes;

  factory NativeAlarmEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = _string(map, 'type') ?? _string(map, 'eventType');
    final occurredAtMs =
        _int(map, 'occurredAtEpochMs') ??
        _int(map, 'occurredAt') ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    return NativeAlarmEvent(
      eventId:
          _string(map, 'eventId') ??
          '${_string(map, 'reminderId') ?? 'unknown'}:$occurredAtMs:$rawType',
      reminderId: _string(map, 'reminderId') ?? _string(map, 'alarmId') ?? '',
      taskId: _string(map, 'taskId') ?? '',
      scheduleRevision:
          _int(map, 'scheduleRevision') ?? _int(map, 'revision') ?? 0,
      type: switch (rawType?.toLowerCase()) {
        'stopped' || 'stop' => NativeAlarmEventType.stopped,
        'snoozed' || 'snooze' => NativeAlarmEventType.snoozed,
        _ => NativeAlarmEventType.fired,
      },
      occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
        occurredAtMs,
        isUtc: true,
      ),
      snoozeMinutes: _int(map, 'snoozeMinutes'),
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
  Future<void> scheduleAlarm(NativeAlarmRequest request);
  Future<void> cancelAlarm(String reminderId);
  Future<void> stopAlarm(String reminderId);
  Future<void> snoozeAlarm(String reminderId, int minutes);
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
  MethodChannelNativeAlarmPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(reminderPlatformChannelName);

  final MethodChannel _channel;

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
  Future<void> scheduleAlarm(NativeAlarmRequest request) =>
      _channel.invokeMethod<void>('scheduleAlarm', request.toMap());

  @override
  Future<void> cancelAlarm(String reminderId) => _channel.invokeMethod<void>(
    'cancelAlarm',
    <String, Object?>{'reminderId': reminderId, 'alarmId': reminderId},
  );

  @override
  Future<void> stopAlarm(String reminderId) => _channel.invokeMethod<void>(
    'stopAlarm',
    <String, Object?>{'reminderId': reminderId, 'alarmId': reminderId},
  );

  @override
  Future<void> snoozeAlarm(String reminderId, int minutes) =>
      _channel.invokeMethod<void>('snoozeAlarm', <String, Object?>{
        'reminderId': reminderId,
        'alarmId': reminderId,
        'minutes': minutes,
        'snoozeMinutes': minutes,
      });

  @override
  Future<Set<String>> listScheduledAlarmIds() async {
    if (!isSupported) return const <String>{};
    try {
      final value = await _channel.invokeMethod<Object?>('listScheduledAlarms');
      if (value is! List<Object?>) return const <String>{};
      return <String>{
        for (final item in value)
          if (item is String && item.isNotEmpty)
            item
          else if (_asMap(item) case final map?)
            if ((_string(map, 'reminderId') ?? _string(map, 'alarmId'))
                case final id? when id.isNotEmpty)
              id,
      };
    } on MissingPluginException {
      return const <String>{};
    }
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

bool? _positiveNumber(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is num) return value > 0;
  final parsed = num.tryParse(value?.toString() ?? '');
  return parsed == null ? null : parsed > 0;
}
