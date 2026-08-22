import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

const _encryptedMagic = 'DANGGUI-ENC-1\n';
const _databaseEntry = 'data/danggui.sqlite';
const _manifestEntry = 'manifest.json';
const _maximumPackageBytes = 512 * 1024 * 1024;
const _maximumDatabaseBytes = 512 * 1024 * 1024;
const _maximumManifestBytes = 256 * 1024;
const _maximumEncryptedHeaderBytes = 16 * 1024;

final class DecodedBackup {
  const DecodedBackup({
    required this.databaseBytes,
    required this.manifest,
    required this.encrypted,
  });

  final Uint8List databaseBytes;
  final Map<String, Object?> manifest;
  final bool encrypted;
}

/// Portable, versioned codec for `.dgbak` files.
///
/// The inner ZIP is always self-describing and contains only a manifest and a
/// consistent SQLite image. When a passphrase is supplied, the complete ZIP is
/// protected with Argon2id and AES-256-GCM. The codec never embeds a
/// passphrase or derived key in the package; automatic backup may keep the
/// user-supplied passphrase in platform secure storage.
final class BackupCodec {
  const BackupCodec._();

  static Future<Uint8List> encode({
    required Uint8List databaseBytes,
    required Map<String, Object?> manifest,
    String? passphrase,
  }) async {
    _validateSqliteHeader(databaseBytes);
    if (databaseBytes.length > _maximumDatabaseBytes) {
      throw const FormatException('Backup database is too large.');
    }
    _validateApplicationManifest(manifest);
    final encrypted = passphrase != null;
    if (passphrase != null && passphrase.length < 8) {
      throw const FormatException('Backup passphrase must have 8+ characters.');
    }
    final databaseHash = await sha256OfBytes(databaseBytes);
    final normalizedManifest = <String, Object?>{
      ...manifest,
      'format': 'danggui-backup',
      'manifestVersion': 1,
      'databaseEntry': _databaseEntry,
      'databaseSha256': databaseHash,
      'encrypted': encrypted,
    };
    final manifestJson = _canonicalJson(normalizedManifest);
    if (utf8.encode(manifestJson).length > _maximumManifestBytes) {
      throw const FormatException('Backup manifest is too large.');
    }
    final archive = Archive()
      ..addFile(ArchiveFile.string(_manifestEntry, manifestJson))
      ..addFile(ArchiveFile.bytes(_databaseEntry, databaseBytes));
    final zip = ZipEncoder().encodeBytes(archive, level: 6);
    if (zip.length > _maximumPackageBytes) {
      throw const FormatException('Backup package is too large.');
    }
    if (!encrypted) return zip;
    final password = passphrase;

    final salt = _secureRandom(16);
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final kdf = Argon2id(
      memory: 65536,
      parallelism: 1,
      iterations: 3,
      hashLength: 32,
    );
    final key = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final secretBox = await algorithm.encrypt(
      zip,
      secretKey: key,
      nonce: nonce,
    );
    final header = utf8.encode(
      _canonicalJson(<String, Object?>{
        'cipher': 'aes-256-gcm',
        'kdf': 'argon2id-v1',
        'kdfMemoryKib': 65536,
        'kdfIterations': 3,
        'kdfParallelism': 1,
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'mac': base64Encode(secretBox.mac.bytes),
        'ciphertextLength': secretBox.cipherText.length,
      }),
    );
    if (header.length > _maximumEncryptedHeaderBytes) {
      throw const FormatException('Encrypted backup header is too large.');
    }
    final size = ByteData(4)..setUint32(0, header.length, Endian.big);
    return Uint8List.fromList(<int>[
      ...utf8.encode(_encryptedMagic),
      ...size.buffer.asUint8List(),
      ...header,
      ...secretBox.cipherText,
    ]);
  }

  static Future<DecodedBackup> decode(
    Uint8List packageBytes, {
    String? passphrase,
  }) async {
    if (packageBytes.isEmpty || packageBytes.length > _maximumPackageBytes) {
      throw const FormatException('Backup size is invalid.');
    }
    final magic = utf8.encode(_encryptedMagic);
    final encrypted = _startsWith(packageBytes, magic);
    Uint8List zipBytes;
    if (!encrypted) {
      zipBytes = packageBytes;
    } else {
      if (passphrase == null || passphrase.isEmpty) {
        throw const FormatException('This backup requires a passphrase.');
      }
      if (packageBytes.length < magic.length + 4) {
        throw const FormatException('Encrypted backup header is truncated.');
      }
      final headerLength = ByteData.sublistView(
        packageBytes,
        magic.length,
        magic.length + 4,
      ).getUint32(0, Endian.big);
      if (headerLength <= 0 || headerLength > _maximumEncryptedHeaderBytes) {
        throw const FormatException('Encrypted backup header is invalid.');
      }
      final payloadOffset = magic.length + 4 + headerLength;
      if (payloadOffset >= packageBytes.length) {
        throw const FormatException('Encrypted backup payload is missing.');
      }
      final header = _jsonMap(
        utf8.decode(packageBytes.sublist(magic.length + 4, payloadOffset)),
      );
      if (header['cipher'] != 'aes-256-gcm' ||
          header['kdf'] != 'argon2id-v1' ||
          header['kdfMemoryKib'] != 65536 ||
          header['kdfIterations'] != 3 ||
          header['kdfParallelism'] != 1) {
        throw const FormatException('Unsupported encrypted backup profile.');
      }
      final ciphertextLength = header['ciphertextLength'];
      if (ciphertextLength is! int ||
          ciphertextLength <= 0 ||
          ciphertextLength != packageBytes.length - payloadOffset) {
        throw const FormatException('Encrypted backup length is invalid.');
      }
      final salt = _decodeFixedBase64(header['salt'], 16, 'salt');
      final nonce = _decodeFixedBase64(header['nonce'], 12, 'nonce');
      final mac = _decodeFixedBase64(header['mac'], 16, 'mac');
      final key = await Argon2id(
        memory: 65536,
        parallelism: 1,
        iterations: 3,
        hashLength: 32,
      ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
      try {
        final clear = await AesGcm.with256bits().decrypt(
          SecretBox(
            packageBytes.sublist(payloadOffset),
            nonce: nonce,
            mac: Mac(mac),
          ),
          secretKey: key,
        );
        zipBytes = Uint8List.fromList(clear);
      } on SecretBoxAuthenticationError {
        throw const FormatException(
          'Passphrase is wrong or backup is damaged.',
        );
      }
    }
    if (zipBytes.isEmpty || zipBytes.length > _maximumPackageBytes) {
      throw const FormatException('Backup archive size is invalid.');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } on Object {
      throw const FormatException('Backup archive is damaged.');
    }
    if (archive.files.length != 2 ||
        archive.files.any((file) => !file.isFile || file.isSymbolicLink)) {
      throw const FormatException(
        'Backup archive contains unexpected entries.',
      );
    }
    final manifestFiles = archive.files
        .where((file) => file.isFile && file.name == _manifestEntry)
        .toList(growable: false);
    final databaseFiles = archive.files
        .where((file) => file.isFile && file.name == _databaseEntry)
        .toList(growable: false);
    if (manifestFiles.length != 1 || databaseFiles.length != 1) {
      throw const FormatException('Backup entries are missing or duplicated.');
    }
    if (manifestFiles.single.size <= 0 ||
        manifestFiles.single.size > _maximumManifestBytes ||
        databaseFiles.single.size < 100 ||
        databaseFiles.single.size > _maximumDatabaseBytes) {
      throw const FormatException('Backup entry size is invalid.');
    }
    final manifestBytes = manifestFiles.single.content;
    if (manifestBytes.length > _maximumManifestBytes) {
      throw const FormatException('Backup manifest is too large.');
    }
    final manifest = _jsonMap(utf8.decode(manifestBytes));
    if (manifest['format'] != 'danggui-backup' ||
        manifest['manifestVersion'] != 1 ||
        manifest['databaseEntry'] != _databaseEntry ||
        manifest['encrypted'] != encrypted) {
      throw const FormatException('Unsupported backup manifest.');
    }
    _validateApplicationManifest(manifest);
    final databaseBytes = Uint8List.fromList(databaseFiles.single.content);
    if (databaseBytes.length > _maximumDatabaseBytes) {
      throw const FormatException('Backup database is too large.');
    }
    _validateSqliteHeader(databaseBytes);
    if (manifest['databaseSha256'] != await sha256OfBytes(databaseBytes)) {
      throw const FormatException('Backup database checksum does not match.');
    }
    return DecodedBackup(
      databaseBytes: databaseBytes,
      manifest: manifest,
      encrypted: encrypted,
    );
  }
}

void _validateApplicationManifest(Map<String, Object?> manifest) {
  final appId = manifest['appId'];
  final datasetId = manifest['datasetId'];
  final schemaVersion = manifest['databaseSchemaVersion'];
  final createdAt = manifest['createdAtUtc'];
  if (appId is! String ||
      appId.trim().isEmpty ||
      appId.length > 200 ||
      datasetId is! String ||
      datasetId.trim().isEmpty ||
      datasetId.length > 200 ||
      schemaVersion is! int ||
      schemaVersion < 1 ||
      createdAt is! String) {
    throw const FormatException('Backup manifest metadata is invalid.');
  }
  final parsedCreatedAt = DateTime.tryParse(createdAt);
  if (parsedCreatedAt == null || !parsedCreatedAt.isUtc) {
    throw const FormatException('Backup creation time must be UTC.');
  }
}

Future<String> sha256OfBytes(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

void _validateSqliteHeader(List<int> bytes) {
  const signature = 'SQLite format 3\u0000';
  if (bytes.length < 100 || !_startsWith(bytes, utf8.encode(signature))) {
    throw const FormatException('Backup does not contain a SQLite database.');
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) return false;
  }
  return true;
}

Uint8List _secureRandom(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256), growable: false),
  );
}

Uint8List _decodeFixedBase64(Object? value, int length, String field) {
  try {
    final bytes = base64Decode(value as String);
    if (bytes.length != length) throw const FormatException();
    return bytes;
  } on Object {
    throw FormatException('Encrypted backup $field is invalid.');
  }
}

Map<String, Object?> _jsonMap(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded.cast<String, Object?>();
  } on Object {
    throw const FormatException('Backup JSON is invalid.');
  }
}

String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonical).toList(growable: false);
  }
  return value;
}
