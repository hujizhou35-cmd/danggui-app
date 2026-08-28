import 'package:danggui/src/services/notifications/local_time_zone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback retains a canonical IANA identifier', () {
    expect(
      fallbackLocalTimeZoneIdentifier(
        'America/New_York',
        const Duration(hours: -5),
      ),
      'America/New_York',
    );
  });

  test('fallback never guesses a region from an ambiguous abbreviation', () {
    expect(
      fallbackLocalTimeZoneIdentifier('CST', const Duration(hours: 8)),
      'unknown',
    );
    expect(
      fallbackLocalTimeZoneIdentifier('PDT', const Duration(hours: -7)),
      'unknown',
    );
  });

  test('zero-offset fallback uses a canonical UTC identifier', () {
    expect(fallbackLocalTimeZoneIdentifier('UTC+0', Duration.zero), 'Etc/UTC');
  });
}
