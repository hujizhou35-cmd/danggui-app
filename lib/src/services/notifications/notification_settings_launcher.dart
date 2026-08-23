import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens this app's operating-system notification settings without adding a
/// third-party runtime dependency.
abstract interface class NotificationSettingsLauncher {
  Future<void> open();
}

final notificationSettingsLauncherProvider =
    Provider<NotificationSettingsLauncher>(
      (ref) => const _PlatformNotificationSettingsLauncher(),
    );

final class _PlatformNotificationSettingsLauncher
    implements NotificationSettingsLauncher {
  const _PlatformNotificationSettingsLauncher();

  static const _channel = MethodChannel('com.danggui.memo/settings');

  @override
  Future<void> open() =>
      _channel.invokeMethod<void>('openNotificationSettings');
}
