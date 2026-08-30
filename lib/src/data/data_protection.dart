import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const dataProtectionPlatformChannelName = 'com.danggui.memo/data_protection';

enum DataProtectionAvailability { available, unavailable }

final class DataProtectionStatus {
  const DataProtectionStatus._({required this.availability, this.errorCode});

  const DataProtectionStatus.available()
    : this._(availability: DataProtectionAvailability.available);

  const DataProtectionStatus.unavailable(String errorCode)
    : this._(
        availability: DataProtectionAvailability.unavailable,
        errorCode: errorCode,
      );

  final DataProtectionAvailability availability;
  final String? errorCode;

  bool get isAvailable => availability == DataProtectionAvailability.available;
}

final class DataProtectionUnavailableException implements Exception {
  const DataProtectionUnavailableException(this.code);

  final String code;

  @override
  String toString() => 'DataProtectionUnavailableException($code)';
}

abstract class DataProtectionPlatform {
  const DataProtectionPlatform();

  Future<DataProtectionStatus> getStatus();

  Future<DataProtectionStatus> retry();

  Future<DataProtectionStatus> ensureAvailable() async {
    final current = await getStatus();
    return current.isAvailable ? current : retry();
  }
}

final class MethodChannelDataProtectionPlatform extends DataProtectionPlatform {
  const MethodChannelDataProtectionPlatform({
    MethodChannel? channel,
    this.isSupportedOverride,
  }) : _channel =
           channel ?? const MethodChannel(dataProtectionPlatformChannelName);

  static const _stableErrorCodes = <String>{
    'not-checked',
    'policy-pending',
    'create-directory',
    'set-protection',
    'set-backup-exclusion',
    'verify-backup-exclusion',
    'enumerate',
    'unknown',
    'bridge-unavailable',
  };

  final MethodChannel _channel;
  final bool? isSupportedOverride;

  bool get _isSupported =>
      isSupportedOverride ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<DataProtectionStatus> getStatus() =>
      _invoke('getDataProtectionStatus');

  @override
  Future<DataProtectionStatus> retry() => _invoke('retryDataProtection');

  Future<DataProtectionStatus> _invoke(String method) async {
    if (!_isSupported) return const DataProtectionStatus.available();
    try {
      final response = await _channel.invokeMethod<Object?>(method);
      if (response is! Map<Object?, Object?>) {
        return const DataProtectionStatus.unavailable('invalid-response');
      }
      final status = response['status'];
      if (status == 'available') {
        return const DataProtectionStatus.available();
      }
      if (status != 'unavailable') {
        return const DataProtectionStatus.unavailable('invalid-response');
      }
      final errorCode = response['errorCode'];
      if (errorCode is! String || !_stableErrorCodes.contains(errorCode)) {
        return const DataProtectionStatus.unavailable('invalid-response');
      }
      return DataProtectionStatus.unavailable(errorCode);
    } on Object {
      // Platform exception messages can contain paths. Collapse every channel
      // failure into a stable code before it reaches state or diagnostics.
      return const DataProtectionStatus.unavailable('channel-error');
    }
  }
}
