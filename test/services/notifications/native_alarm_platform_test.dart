import 'package:danggui/src/services/notifications/native_alarm_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
