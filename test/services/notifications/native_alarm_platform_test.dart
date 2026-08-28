import 'package:danggui/src/services/notifications/native_alarm_platform.dart';
import 'package:danggui/src/services/notifications/notification_coordinator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deterministic session matches shared Swift and Kotlin vectors', () {
    expect(
      deterministicNativeAlarmSessionId('reminder-1', 1),
      'cd5bd2da-9bbc-58bd-a180-035d29ea7098',
    );
    expect(
      deterministicNativeAlarmSessionId('r1', 7),
      '0e210420-bdf8-57ba-a6e5-c5b048e22881',
    );
    expect(
      deterministicNativeAlarmSessionId('提醒-😀', 42),
      '9c41e0b6-c7b9-5488-a7a2-0b8885caae3b',
    );
    expect(
      deterministicNativeAlarmSessionId(
        'r1',
        7,
        deviceGeneration: '99999999-9999-4999-8999-999999999999',
      ),
      '7583af8c-382e-5b5d-ae26-48dd1489d676',
    );
    expect(
      deterministicNativeAlarmSessionId(
        'r1',
        7,
        deviceGeneration: 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF',
      ),
      deterministicNativeAlarmSessionId(
        'r1',
        7,
        deviceGeneration: 'abcdefab-cdef-4abc-8def-abcdefabcdef',
      ),
    );
  });

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
        'deviceGeneration': '99999999-9999-4999-8999-999999999999',
      });

      expect(snapshot.reminderId, 'reminder-1');
      expect(snapshot.platformId, 'native-42');
      expect(snapshot.scheduleRevision, 7);
      expect(snapshot.triggerAtEpochMs, 1787392800000);
      expect(snapshot.state, NativeAlarmSnapshotState.capacityDeferred);
      expect(snapshot.state.isActive, isFalse);
      expect(snapshot.deviceGeneration, '99999999-9999-4999-8999-999999999999');
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
        if (entry.key == 'snoozed') 'snoozeMinutes': 30,
        'sessionId': 'session-3',
        'deviceGeneration': '99999999-9999-4999-8999-999999999999',
      });
      expect(event.type, entry.value);
      expect(event.sessionId, 'session-3');
      expect(event.deviceGeneration, '99999999-9999-4999-8999-999999999999');
      expect(event.successorTriggerAtEpochMs, 1787394600123);
    }
  });

  test(
    'malformed business event is ackable and does not block a valid sibling',
    () async {
      const channel = MethodChannel('danggui.test/event-drain');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'drainAlarmEvents') {
              return <Object?>[
                <String, Object?>{
                  'eventId': 'bad-event',
                  'reminderId': 'reminder-1',
                  'taskId': 'task-1',
                  'revision': 3,
                  'type': 'snoozed',
                  'occurredAtEpochMs': 9223372036854775807,
                  'snoozeMinutes': 30,
                  'successorTriggerAtEpochMs': double.infinity,
                  'sessionId': 'bad-session',
                },
                <String, Object?>{
                  'eventId': 'good-event',
                  'reminderId': 'reminder-1',
                  'taskId': 'task-1',
                  'revision': 3,
                  'type': 'stopped',
                  'occurredAtEpochMs': 1787392800000,
                  'sessionId': 'good-session',
                },
              ];
            }
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

      final events = await platform.drainAlarmEvents();

      expect(events, hasLength(2));
      expect(events.first.eventId, 'bad-event');
      expect(events.first.type, NativeAlarmEventType.error);
      expect(events.first.errorCode, 'invalid_event_envelope');
      expect(events.last.eventId, 'good-event');
      expect(events.last.type, NativeAlarmEventType.stopped);

      await platform.acknowledgeAlarmEvents(
        events.map((event) => event.eventId).toSet(),
      );
      final acknowledgement = calls.last;
      expect(acknowledgement.method, 'ackAlarmEvents');
      expect(
        (acknowledgement.arguments as Map<Object?, Object?>)['eventIds'],
        containsAll(<String>['bad-event', 'good-event']),
      );
    },
  );

  test('missing business timestamp fails closed while preserving its id', () {
    final event = NativeAlarmEvent.fromMap(<Object?, Object?>{
      'eventId': 'missing-time',
      'reminderId': 'reminder-1',
      'taskId': 'task-1',
      'revision': 3,
      'type': 'stopped',
      'sessionId': 'session-3',
    });

    expect(event.eventId, 'missing-time');
    expect(event.type, NativeAlarmEventType.error);
    expect(event.errorCode, 'invalid_event_envelope');
  });

  test('device generation activation carries UUID and legacy null', () async {
    const channel = MethodChannel('danggui.test/generation-activation');
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

    await platform.activateDeviceGeneration(
      '99999999-9999-4999-8999-999999999999',
    );
    await platform.activateDeviceGeneration(null);

    expect(calls.map((call) => call.method), <String>[
      'activateDeviceGeneration',
      'activateDeviceGeneration',
    ]);
    final generated = calls.first.arguments as Map<Object?, Object?>;
    final legacy = calls.last.arguments as Map<Object?, Object?>;
    expect(
      generated['deviceGeneration'],
      '99999999-9999-4999-8999-999999999999',
    );
    expect(generated['generation'], generated['deviceGeneration']);
    expect(legacy.containsKey('deviceGeneration'), isTrue);
    expect(legacy['deviceGeneration'], isNull);
  });

  test(
    'route retirement, stop and snooze transmit revision/session identities',
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

      await platform.retireNativeAlarmRoute(
        'reminder-1',
        scheduleRevision: 8,
        sessionId: 'session-8',
        deviceGeneration: '99999999-9999-4999-8999-999999999999',
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
        'retireNativeAlarmRoute',
        'stopAlarm',
        'snoozeAlarm',
      ]);
      final retirement = calls.first.arguments as Map<Object?, Object?>;
      final stop = calls[1].arguments as Map<Object?, Object?>;
      final snooze = calls.last.arguments as Map<Object?, Object?>;
      expect(retirement['reminderId'], 'reminder-1');
      expect(retirement['revision'], 8);
      expect(retirement['sessionId'], 'session-8');
      expect(
        retirement['deviceGeneration'],
        '99999999-9999-4999-8999-999999999999',
      );
      expect(stop['revision'], 8);
      expect(stop['sessionId'], 'session-8');
      expect(snooze['revision'], 8);
      expect(snooze['sessionId'], 'session-8');
      expect(snooze['snoozeMinutes'], 30);
    },
  );

  test('business cancellation carries the device generation aliases', () async {
    const channel = MethodChannel('danggui.test/generation-cancellation');
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

    await platform.cancelAlarm(
      'reminder-1',
      deviceGeneration: '99999999-9999-4999-8999-999999999999',
    );
    await platform.cancelAlarm('legacy-reminder');

    expect(calls.map((call) => call.method), <String>[
      'cancelAlarm',
      'cancelAlarm',
    ]);
    final generated = calls.first.arguments as Map<Object?, Object?>;
    final legacy = calls.last.arguments as Map<Object?, Object?>;
    expect(generated['reminderId'], 'reminder-1');
    expect(
      generated['deviceGeneration'],
      '99999999-9999-4999-8999-999999999999',
    );
    expect(generated['generation'], generated['deviceGeneration']);
    expect(legacy['reminderId'], 'legacy-reminder');
    expect(legacy.containsKey('deviceGeneration'), isFalse);
    expect(legacy.containsKey('generation'), isFalse);
  });

  test(
    'ordinary iOS fallback retires route without business cancellation',
    () async {
      const channel = MethodChannel('danggui.test/route-retirement');
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

      await retireNativeRouteAfterOrdinarySchedule(
        platform,
        reminderId: 'reminder-1',
        scheduleRevision: 8,
        isIOS: true,
      );
      await retireNativeRouteAfterOrdinarySchedule(
        platform,
        reminderId: 'reminder-android',
        scheduleRevision: 9,
        isIOS: false,
      );

      expect(calls.map((call) => call.method), <String>[
        'retireNativeAlarmRoute',
        'cancelAlarm',
      ]);
      final retirement = calls.first.arguments as Map<Object?, Object?>;
      expect(retirement['revision'], 8);
      expect(
        retirement['sessionId'],
        deterministicNativeAlarmSessionId('reminder-1', 8),
      );
      expect(calls.where((call) => call.method == 'cancelAlarm'), hasLength(1));
    },
  );
}
