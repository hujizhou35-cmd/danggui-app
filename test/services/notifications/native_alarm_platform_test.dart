import 'package:danggui/src/services/notifications/native_alarm_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android native alarm channel diagnostics are preserved', () {
    final capabilities = NativeAlarmCapabilities.fromMap(<Object?, Object?>{
      'platform': 'android',
      'supported': true,
      'alarmChannelEnabled': false,
      'alarmChannelImportance': 0,
    });

    expect(capabilities.alarmChannelEnabled, isFalse);
    expect(capabilities.alarmChannelImportance, 0);
  });

  test(
    'snapshot parser preserves the cross-platform reconciliation contract',
    () {
      final snapshot = NativeAlarmSnapshot.fromMap(<Object?, Object?>{
        'reminderId': 'reminder-1',
        'platformId': 'native-42',
        'revision': 7,
        'triggerAtEpochMs': 1787392800000,
        'state': 'capacity-deferred',
      });

      expect(snapshot.reminderId, 'reminder-1');
      expect(snapshot.platformId, 'native-42');
      expect(snapshot.scheduleRevision, 7);
      expect(snapshot.triggerAtEpochMs, 1787392800000);
      expect(snapshot.state, NativeAlarmSnapshotState.capacityDeferred);
      expect(snapshot.state.isActive, isFalse);
    },
  );

  test('capability levels distinguish AlarmKit from best-effort iOS', () {
    final alarmKit = NativeAlarmCapabilities.fromMap(<Object?, Object?>{
      'platform': 'ios',
      'supported': true,
      'alarmAuthorization': 'authorized',
    });
    final legacy = NativeAlarmCapabilities.fromMap(<Object?, Object?>{
      'platform': 'ios',
      'supported': false,
      'notificationsEnabled': true,
      'timeSensitiveEnabled': true,
    });

    expect(alarmKit.deliveryLevel, ReminderDeliveryLevel.alarmGrade);
    expect(legacy.deliveryLevel, ReminderDeliveryLevel.timeSensitiveBestEffort);
    expect(legacy.strongAlarmAuthorized, isFalse);
    expect(legacy.deliveryLevel.wireName, 'time-sensitive-best-effort');
  });

  test('event parser accepts every v1.1.4 diagnostic milestone', () {
    const expected = <String, NativeAlarmEventType>{
      'registered': NativeAlarmEventType.registered,
      'delivered': NativeAlarmEventType.delivered,
      'foreground': NativeAlarmEventType.foreground,
      'systemAlert': NativeAlarmEventType.systemAlert,
      'audio': NativeAlarmEventType.audio,
      'vibration': NativeAlarmEventType.vibration,
      'missed': NativeAlarmEventType.missed,
      'stopped': NativeAlarmEventType.stopped,
      'snoozed': NativeAlarmEventType.snoozed,
      'error': NativeAlarmEventType.error,
    };

    for (final entry in expected.entries) {
      final event = NativeAlarmEvent.fromMap(<Object?, Object?>{
        'eventId': 'event-${entry.key}',
        'reminderId': 'reminder-1',
        'revision': 3,
        'type': entry.key,
        'occurredAtEpochMs': 1787392800000,
        'successorTriggerAtEpochMs': 1787394600123,
        'sessionId': 'session-3',
      });
      expect(event.type, entry.value);
      expect(event.sessionId, 'session-3');
      expect(event.successorTriggerAtEpochMs, 1787394600123);
    }
  });

  test(
    'stop and snooze transmit revision and session idempotency keys',
    () async {
      const channel = MethodChannel('danggui.test/reminders');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final platform = MethodChannelNativeAlarmPlatform(
        channel: channel,
        isSupportedOverride: true,
      );

      await platform.stopAlarm(
        'reminder-1',
        scheduleRevision: 8,
        sessionId: 'session-8',
      );
      await platform.snoozeAlarm(
        'reminder-1',
        30,
        scheduleRevision: 8,
        sessionId: 'session-8',
      );

      expect(calls.map((call) => call.method), <String>[
        'stopAlarm',
        'snoozeAlarm',
      ]);
      final stop = calls.first.arguments as Map<Object?, Object?>;
      final snooze = calls.last.arguments as Map<Object?, Object?>;
      expect(stop['revision'], 8);
      expect(stop['sessionId'], 'session-8');
      expect(snooze['revision'], 8);
      expect(snooze['sessionId'], 'session-8');
      expect(snooze['snoozeMinutes'], 30);
    },
  );
}
