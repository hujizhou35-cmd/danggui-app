import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:danggui/src/services/backup/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupCodec', () {
    test('unencrypted package round-trips database and manifest', () async {
      final database = _sqliteFixture();
      final package = await BackupCodec.encode(
        databaseBytes: database,
        manifest: _manifest,
      );

      final decoded = await BackupCodec.decode(package);

      expect(decoded.encrypted, isFalse);
      expect(decoded.databaseBytes, orderedEquals(database));
      expect(decoded.manifest['format'], 'danggui-backup');
      expect(decoded.manifest['manifestVersion'], 1);
      expect(decoded.manifest['databaseSchemaVersion'], 1);
      expect(decoded.manifest['datasetId'], 'dataset-test-001');
      expect(decoded.manifest['encrypted'], isFalse);
      expect(decoded.manifest['databaseSha256'], hasLength(64));
    });

    test(
      'encrypted package round-trips and rejects a wrong password',
      () async {
        final database = _sqliteFixture();
        final package = await BackupCodec.encode(
          databaseBytes: database,
          manifest: _manifest,
          passphrase: 'correct horse battery staple',
        );

        final decoded = await BackupCodec.decode(
          package,
          passphrase: 'correct horse battery staple',
        );

        expect(decoded.encrypted, isTrue);
        expect(decoded.databaseBytes, orderedEquals(database));
        expect(decoded.manifest['encrypted'], isTrue);
        await expectLater(
          BackupCodec.decode(package, passphrase: 'definitely wrong password'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('authenticated encryption rejects ciphertext tampering', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
        passphrase: 'correct horse battery staple',
      );
      final tampered = Uint8List.fromList(package);
      tampered[tampered.length - 1] ^= 0x01;

      await expectLater(
        BackupCodec.decode(
          tampered,
          passphrase: 'correct horse battery staple',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('unencrypted package rejects a database checksum mismatch', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
      );
      final decodedArchive = ZipDecoder().decodeBytes(package, verify: true);
      final manifest = decodedArchive.files
          .singleWhere((file) => file.name == 'manifest.json')
          .content;
      final database = Uint8List.fromList(
        decodedArchive.files
            .singleWhere((file) => file.name == 'data/danggui.sqlite')
            .content,
      );
      database[database.length - 1] ^= 0x01;
      final changedArchive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', utf8.decode(manifest)))
        ..addFile(ArchiveFile.bytes('data/danggui.sqlite', database));
      final tampered = ZipEncoder().encodeBytes(changedArchive, level: 6);

      await expectLater(
        BackupCodec.decode(tampered),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

const _manifest = <String, Object?>{
  'appId': 'com.danggui.memo',
  'appVersion': '1.0.0+1',
  'createdAtUtc': '2026-08-22T00:00:00.000Z',
  'datasetId': 'dataset-test-001',
  'databaseSchemaVersion': 1,
  'recordCounts': <String, int>{'tasks': 2, 'notes': 1},
};

Uint8List _sqliteFixture() {
  final result = Uint8List(4096);
  final signature = utf8.encode('SQLite format 3\u0000');
  result.setRange(0, signature.length, signature);
  for (var index = 100; index < result.length; index++) {
    result[index] = (index * 31) & 0xff;
  }
  return result;
}
