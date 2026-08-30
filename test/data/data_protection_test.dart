import 'dart:io';

import 'package:danggui/src/data/data_protection.dart';
import 'package:danggui/src/data/database_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('danggui.test/data-protection');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ensureAvailable retries a persisted unavailable policy', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'getDataProtectionStatus') {
            return <String, Object?>{
              'status': 'unavailable',
              'errorCode': 'verify-backup-exclusion',
            };
          }
          return <String, Object?>{'status': 'available'};
        });
    final platform = MethodChannelDataProtectionPlatform(
      channel: channel,
      isSupportedOverride: true,
    );

    final result = await platform.ensureAvailable();

    expect(result.isAvailable, isTrue);
    expect(calls, <String>['getDataProtectionStatus', 'retryDataProtection']);
  });

  test('channel errors collapse to a stable path-free code', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'filesystem_error',
            message: 'secret path: /private/var/mobile/example.sqlite',
          );
        });
    final platform = MethodChannelDataProtectionPlatform(
      channel: channel,
      isSupportedOverride: true,
    );

    final result = await platform.getStatus();

    expect(result.isAvailable, isFalse);
    expect(result.errorCode, 'channel-error');
    expect(result.toString(), isNot(contains('/private/var/mobile')));
  });

  test(
    'unknown native values fail closed instead of claiming available',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return <String, Object?>{
              'status': 'unavailable',
              'errorCode': '/private/leaked-path',
            };
          });
      final platform = MethodChannelDataProtectionPlatform(
        channel: channel,
        isSupportedOverride: true,
      );

      final result = await platform.getStatus();

      expect(result.isAvailable, isFalse);
      expect(result.errorCode, 'invalid-response');
    },
  );

  test(
    'database path remains unavailable when the native policy fails',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'danggui-protection-provider-',
      );
      addTearDown(() async {
        if (await temporary.exists()) await temporary.delete(recursive: true);
      });
      await expectLater(
        prepareDatabaseFileForOpen(
          protectionPlatform: const _UnavailableDataProtectionPlatform(),
          readTemporaryDirectory: () async => temporary,
          readApplicationSupportDirectory: () async => throw StateError(
            'Application Support must not be resolved after protection fails.',
          ),
        ),
        throwsA(
          isA<DataProtectionUnavailableException>().having(
            (error) => error.code,
            'code',
            'verify-backup-exclusion',
          ),
        ),
      );
    },
  );

  test(
    'stale plaintext is purged before unavailable protection aborts',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'danggui-protection-order-',
      );
      addTearDown(() async {
        if (await temporary.exists()) await temporary.delete(recursive: true);
      });
      for (final name in const <String>[
        'danggui-backup-work',
        'danggui-restore-validation',
        'danggui-portable-exports',
        'danggui-backups',
      ]) {
        final root = Directory(p.join(temporary.path, name));
        await root.create();
        await File(p.join(root.path, 'plaintext')).writeAsString('sensitive');
      }
      var applicationSupportReads = 0;

      await expectLater(
        prepareDatabaseFileForOpen(
          protectionPlatform: const _UnavailableDataProtectionPlatform(),
          readTemporaryDirectory: () async => temporary,
          readApplicationSupportDirectory: () async {
            applicationSupportReads++;
            throw StateError('must not resolve protected path');
          },
        ),
        throwsA(isA<DataProtectionUnavailableException>()),
      );

      expect(applicationSupportReads, 0);
      for (final name in const <String>[
        'danggui-backup-work',
        'danggui-restore-validation',
        'danggui-portable-exports',
        'danggui-backups',
      ]) {
        expect(await Directory(p.join(temporary.path, name)).exists(), isFalse);
      }
    },
  );
}

final class _UnavailableDataProtectionPlatform extends DataProtectionPlatform {
  const _UnavailableDataProtectionPlatform();

  @override
  Future<DataProtectionStatus> getStatus() async =>
      const DataProtectionStatus.unavailable('verify-backup-exclusion');

  @override
  Future<DataProtectionStatus> retry() => getStatus();
}
