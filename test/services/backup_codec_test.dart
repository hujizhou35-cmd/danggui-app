import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:danggui/src/services/backup/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/zip_test_support.dart';

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
      // Argon2id is intentionally memory-hard. A busy shared CI runner or a
      // full-suite local run can transiently exceed the fast single-file time
      // without indicating a deadlock; retain a finite but realistic bound.
      timeout: const Timeout(Duration(minutes: 5)),
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
    }, timeout: const Timeout(Duration(minutes: 5)));

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

    test('unencrypted package verifies the ZIP CRC for every entry', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: <String, Object?>{..._manifest, 'kind': 'manual'},
      );
      final decodedArchive = ZipDecoder().decodeBytes(package);
      final storedArchive = Archive();
      for (final entry in decodedArchive.files) {
        storedArchive.addFile(
          ArchiveFile.noCompress(
            entry.name,
            entry.content.length,
            entry.content,
          ),
        );
      }
      final tampered = Uint8List.fromList(
        ZipEncoder().encodeBytes(storedArchive),
      );
      final marker = utf8.encode('"kind":"manual"');
      final markerOffset = _indexOf(tampered, marker);
      expect(markerOffset, isNonNegative);
      // Keep valid JSON and the same byte length. Only the central-directory
      // CRC now reveals that the manifest payload was damaged in transit.
      final replacement = utf8.encode('hourly');
      tampered.setRange(
        markerOffset + marker.length - 7,
        markerOffset + marker.length - 1,
        replacement,
      );

      await expectLater(
        BackupCodec.decode(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('package rejects duplicate central-directory entry names', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
      );
      await expectLater(
        BackupCodec.decode(
          duplicateZipCentralDirectoryEntry(package, 'manifest.json'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'preflight rejects a tiny ZIP declaring a bomb-sized database',
      () async {
        final package = await BackupCodec.encode(
          databaseBytes: _sqliteFixture(),
          manifest: _manifest,
        );

        await expectLater(
          BackupCodec.decode(
            setZipCentralUncompressedSize(
              package,
              'data/danggui.sqlite',
              BackupCodec.maximumPackageBytes + 1,
            ),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('inflate cannot exceed the preflighted entry declaration', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
      );

      await expectLater(
        BackupCodec.decode(
          setZipDeclaredUncompressedSize(package, 'data/danggui.sqlite', 100),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('preflight rejects symbolic-link entry metadata', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
      );

      await expectLater(
        BackupCodec.decode(
          markZipEntryAsUnixSymlink(package, 'data/danggui.sqlite'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('preflight rejects mismatched local and central names', () async {
      final package = await BackupCodec.encode(
        databaseBytes: _sqliteFixture(),
        manifest: _manifest,
      );

      await expectLater(
        BackupCodec.decode(
          renameZipLocalEntry(
            package,
            'data/danggui.sqlite',
            'data/danggui.sqlitx',
          ),
        ),
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

int _indexOf(List<int> bytes, List<int> pattern) {
  for (var offset = 0; offset <= bytes.length - pattern.length; offset++) {
    var matches = true;
    for (var index = 0; index < pattern.length; index++) {
      if (bytes[offset + index] != pattern[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return offset;
  }
  return -1;
}
