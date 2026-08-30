import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_alarm_platform.dart';

/// Resolves the operating system's canonical time-zone identifier without
/// coupling durable reminder writes to a concrete MethodChannel.
abstract interface class LocalTimeZoneResolver {
  Future<String> currentIdentifier(DateTime localInstant);
}

final class MethodChannelLocalTimeZoneResolver
    implements LocalTimeZoneResolver {
  const MethodChannelLocalTimeZoneResolver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(reminderPlatformChannelName);

  final MethodChannel _channel;

  @override
  Future<String> currentIdentifier(DateTime localInstant) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final identifier = await _channel.invokeMethod<String>(
          'getLocalTimeZoneIdentifier',
        );
        if (_isCanonicalIdentifier(identifier)) return identifier!.trim();
      } on MissingPluginException {
        // Older builds and unit tests may not contain the additive bridge.
      } on PlatformException {
        // Discovery must not make an otherwise valid local edit fail.
      }
    }

    return fallbackLocalTimeZoneIdentifier(
      localInstant.timeZoneName,
      localInstant.timeZoneOffset,
    );
  }

  static bool _isCanonicalIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier == 'UTC' || identifier == 'GMT' || identifier == 'Etc/UTC') {
      return true;
    }
    return RegExp(
      r'^[A-Za-z]+(?:[._+-][A-Za-z0-9]+)*/[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)*$',
    ).hasMatch(identifier);
  }
}

@visibleForTesting
String fallbackLocalTimeZoneIdentifier(String timeZoneName, Duration offset) {
  final identifier = timeZoneName.trim();
  if (MethodChannelLocalTimeZoneResolver._isCanonicalIdentifier(identifier)) {
    return identifier;
  }
  if (offset == Duration.zero) return 'Etc/UTC';
  // CST, IST and similar abbreviations identify several unrelated regions.
  // Persisting one would silently invent DST rules, so retain an explicit
  // unknown marker and let the durable UTC instant remain authoritative.
  return 'unknown';
}
