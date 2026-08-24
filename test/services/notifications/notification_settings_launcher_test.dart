import 'package:danggui/src/services/notifications/notification_settings_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.danggui.memo/settings');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('opens the operating-system notification settings', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(notificationSettingsLauncherProvider).open();

    expect(received?.method, 'openNotificationSettings');
    expect(received?.arguments, isNull);
  });
}
