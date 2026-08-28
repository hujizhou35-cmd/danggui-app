import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

const _encryptedMagic = 'DANGGUI-ENC-1\n';
const _databaseEntry = 'data/danggui.sqlite';
const _manifestEntry = 'manifest.json';
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

  /// Checked from file metadata before [File.readAsBytes] and repeated after
  /// the read/decryption boundary.
  static const int maximumPackageBytes = 512 * 1024 * 1024;

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
    if (zip.length > maximumPackageBytes) {
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
    if (packageBytes.isEmpty || packageBytes.length > maximumPackageBytes) {
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
    if (zipBytes.isEmpty || zipBytes.length > maximumPackageBytes) {
      throw const FormatException('Backup archive size is invalid.');
    }

    _preflightZip(zipBytes);

    Archive archive;
    late final ZipDecoder decoder;
    try {
      decoder = ZipDecoder();
      archive = decoder.decodeBytes(zipBytes);
    } on Object {
      throw const FormatException('Backup archive is damaged.');
    }
    final centralDirectoryNames = decoder.directory.fileHeaders
        .map((header) => header.filename)
        .toList(growable: false);
    if (centralDirectoryNames.length != 2 ||
        centralDirectoryNames.toSet().length != centralDirectoryNames.length ||
        centralDirectoryNames.toSet().difference(const <String>{
          _manifestEntry,
          _databaseEntry,
        }).isNotEmpty ||
        archive.files.length != 2 ||
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
    final decodedEntries = <String, Uint8List>{};
    for (final file in archive.files) {
      final output = _BoundedOutputMemoryStream(file.size);
      try {
        file.decompress(output);
      } on FormatException {
        rethrow;
      } on Object {
        throw const FormatException('Backup archive is damaged.');
      }
      if (output.length != file.size) {
        throw const FormatException('Backup entry size is invalid.');
      }
      final content = output.getBytes();
      final expectedCrc = file.crc32;
      if (expectedCrc == null || getCrc32(content) != expectedCrc) {
        throw const FormatException('Backup archive checksum is invalid.');
      }
      decodedEntries[file.name] = content;
    }
    final manifestBytes = decodedEntries[_manifestEntry]!;
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
    final databaseBytes = decodedEntries[_databaseEntry]!;
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

/// Reads only the ZIP directory and local headers. No entry content is
/// decompressed until every declared name, size, type, and offset is bounded.
void _preflightZip(Uint8List zipBytes) {
  try {
    _preflightZipUnchecked(zipBytes);
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('Backup archive is damaged.');
  }
}

void _preflightZipUnchecked(Uint8List zipBytes) {
  const eocdSignature = 0x06054b50;
  const centralSignature = 0x02014b50;
  const minimumEocdLength = 22;
  const maximumCommentLength = 0xffff;
  if (zipBytes.length < minimumEocdLength) {
    throw const FormatException('Backup archive is damaged.');
  }
  final view = ByteData.sublistView(zipBytes);
  final earliestEocd = max(
    0,
    zipBytes.length - minimumEocdLength - maximumCommentLength,
  );
  var eocdOffset = -1;
  for (
    var offset = zipBytes.length - minimumEocdLength;
    offset >= earliestEocd;
    offset--
  ) {
    if (view.getUint32(offset, Endian.little) == eocdSignature) {
      final commentLength = view.getUint16(offset + 20, Endian.little);
      if (offset + minimumEocdLength + commentLength == zipBytes.length) {
        eocdOffset = offset;
        break;
      }
    }
  }
  if (eocdOffset < 0) {
    throw const FormatException('Backup archive is damaged.');
  }

  final numberOfThisDisk = view.getUint16(eocdOffset + 4, Endian.little);
  final centralDirectoryDisk = view.getUint16(eocdOffset + 6, Endian.little);
  final entriesOnDisk = view.getUint16(eocdOffset + 8, Endian.little);
  final totalEntries = view.getUint16(eocdOffset + 10, Endian.little);
  final centralDirectorySize = view.getUint32(eocdOffset + 12, Endian.little);
  final centralDirectoryOffset = view.getUint32(eocdOffset + 16, Endian.little);
  if (numberOfThisDisk != 0 ||
      centralDirectoryDisk != 0 ||
      entriesOnDisk != 2 ||
      totalEntries != 2 ||
      centralDirectorySize <= 0 ||
      centralDirectoryOffset < 0 ||
      centralDirectoryOffset + centralDirectorySize != eocdOffset) {
    throw const FormatException('Backup archive contains unexpected entries.');
  }

  final entries = <_ZipCentralEntry>[];
  var centralCursor = centralDirectoryOffset;
  for (var index = 0; index < totalEntries; index++) {
    if (centralCursor + 46 > eocdOffset ||
        view.getUint32(centralCursor, Endian.little) != centralSignature) {
      throw const FormatException('Backup central directory is invalid.');
    }
    final nameLength = view.getUint16(centralCursor + 28, Endian.little);
    final extraLength = view.getUint16(centralCursor + 30, Endian.little);
    final commentLength = view.getUint16(centralCursor + 32, Endian.little);
    final entryEnd =
        centralCursor + 46 + nameLength + extraLength + commentLength;
    if (entryEnd > eocdOffset) {
      throw const FormatException('Backup central directory is invalid.');
    }
    final nameBytes = zipBytes.sublist(
      centralCursor + 46,
      centralCursor + 46 + nameLength,
    );
    final name = utf8.decode(nameBytes);
    entries.add(
      _ZipCentralEntry(
        name: name,
        versionMadeBy: view.getUint16(centralCursor + 4, Endian.little),
        flags: view.getUint16(centralCursor + 8, Endian.little),
        compressionMethod: view.getUint16(centralCursor + 10, Endian.little),
        crc32: view.getUint32(centralCursor + 16, Endian.little),
        compressedSize: view.getUint32(centralCursor + 20, Endian.little),
        uncompressedSize: view.getUint32(centralCursor + 24, Endian.little),
        diskNumberStart: view.getUint16(centralCursor + 34, Endian.little),
        externalFileAttributes: view.getUint32(
          centralCursor + 38,
          Endian.little,
        ),
        localHeaderOffset: view.getUint32(centralCursor + 42, Endian.little),
      ),
    );
    centralCursor = entryEnd;
  }
  if (centralCursor != eocdOffset) {
    throw const FormatException('Backup central directory is invalid.');
  }

  final names = entries.map((entry) => entry.name).toList(growable: false);
  if (names.toSet().length != names.length ||
      names.toSet().difference(const <String>{
        _manifestEntry,
        _databaseEntry,
      }).isNotEmpty) {
    throw const FormatException('Backup archive contains unexpected entries.');
  }

  var totalUncompressed = 0;
  final occupiedRanges = <({int start, int end})>[];
  for (final entry in entries) {
    final maximumSize = entry.name == _manifestEntry
        ? _maximumManifestBytes
        : _maximumDatabaseBytes;
    final minimumSize = entry.name == _manifestEntry ? 1 : 100;
    if (entry.uncompressedSize < minimumSize ||
        entry.uncompressedSize > maximumSize ||
        entry.compressedSize <= 0 ||
        entry.compressedSize > zipBytes.length ||
        entry.diskNumberStart != 0 ||
        (entry.flags & 0x1) != 0 ||
        (entry.compressionMethod != ZipFile.zipCompressionStore &&
            entry.compressionMethod != ZipFile.zipCompressionDeflate) ||
        !_isRegularZipEntry(entry)) {
      throw const FormatException('Backup entry metadata is invalid.');
    }
    if (totalUncompressed >
        _maximumDatabaseBytes +
            _maximumManifestBytes -
            entry.uncompressedSize) {
      throw const FormatException('Backup archive expands beyond its limit.');
    }
    totalUncompressed += entry.uncompressedSize;
    occupiedRanges.add(
      _validateLocalZipHeader(
        zipBytes,
        entry,
        centralDirectoryOffset: centralDirectoryOffset,
      ),
    );
  }
  occupiedRanges.sort((left, right) => left.start.compareTo(right.start));
  for (var index = 1; index < occupiedRanges.length; index++) {
    if (occupiedRanges[index].start < occupiedRanges[index - 1].end) {
      throw const FormatException('Backup ZIP entries overlap.');
    }
  }
}

bool _isRegularZipEntry(_ZipCentralEntry entry) {
  final creatorSystem = entry.versionMadeBy >> 8;
  if (creatorSystem == 3) {
    final fileType = (entry.externalFileAttributes >> 16) & 0xf000;
    return fileType == 0 || fileType == 0x8000;
  }
  // DOS directory attribute. Exact entry names also reject path aliases.
  return (entry.externalFileAttributes & 0x10) == 0;
}

({int start, int end}) _validateLocalZipHeader(
  Uint8List bytes,
  _ZipCentralEntry entry, {
  required int centralDirectoryOffset,
}) {
  final start = entry.localHeaderOffset;
  if (start < 0 || start + 30 > centralDirectoryOffset) {
    throw const FormatException('Backup ZIP local header is invalid.');
  }
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(start, Endian.little) != ZipFile.zipSignature) {
    throw const FormatException('Backup ZIP local header is invalid.');
  }
  final flags = view.getUint16(start + 6, Endian.little);
  final compressionMethod = view.getUint16(start + 8, Endian.little);
  final crc32 = view.getUint32(start + 14, Endian.little);
  final compressedSize = view.getUint32(start + 18, Endian.little);
  final uncompressedSize = view.getUint32(start + 22, Endian.little);
  final nameLength = view.getUint16(start + 26, Endian.little);
  final extraLength = view.getUint16(start + 28, Endian.little);
  final dataStart = start + 30 + nameLength + extraLength;
  var end = dataStart + entry.compressedSize;
  final localName = utf8.decode(
    bytes.sublist(start + 30, start + 30 + nameLength),
  );
  if (localName != entry.name ||
      flags != entry.flags ||
      (flags & 0x1) != 0 ||
      compressionMethod != entry.compressionMethod ||
      dataStart < start ||
      end < dataStart ||
      end > centralDirectoryOffset) {
    throw const FormatException('Backup ZIP local header is inconsistent.');
  }
  if ((flags & 0x08) == 0) {
    if (crc32 != entry.crc32 ||
        compressedSize != entry.compressedSize ||
        uncompressedSize != entry.uncompressedSize) {
      throw const FormatException('Backup ZIP local header is inconsistent.');
    }
  } else {
    var descriptorOffset = end;
    if (descriptorOffset + 12 > centralDirectoryOffset) {
      throw const FormatException('Backup ZIP data descriptor is invalid.');
    }
    if (view.getUint32(descriptorOffset, Endian.little) == 0x08074b50) {
      descriptorOffset += 4;
    }
    if (descriptorOffset + 12 > centralDirectoryOffset ||
        view.getUint32(descriptorOffset, Endian.little) != entry.crc32 ||
        view.getUint32(descriptorOffset + 4, Endian.little) !=
            entry.compressedSize ||
        view.getUint32(descriptorOffset + 8, Endian.little) !=
            entry.uncompressedSize) {
      throw const FormatException('Backup ZIP data descriptor is invalid.');
    }
    end = descriptorOffset + 12;
  }
  return (start: start, end: end);
}

final class _ZipCentralEntry {
  const _ZipCentralEntry({
    required this.name,
    required this.versionMadeBy,
    required this.flags,
    required this.compressionMethod,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.diskNumberStart,
    required this.externalFileAttributes,
    required this.localHeaderOffset,
  });

  final String name;
  final int versionMadeBy;
  final int flags;
  final int compressionMethod;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int diskNumberStart;
  final int externalFileAttributes;
  final int localHeaderOffset;
}

/// Archive 4.x trusts the central-directory size as an allocation hint. This
/// sink enforces that bound during every inflate write as well, so a forged
/// deflate stream cannot expand past the already preflighted declaration.
final class _BoundedOutputMemoryStream extends OutputMemoryStream {
  _BoundedOutputMemoryStream(this.maximumLength)
    : super(size: min(maximumLength, OutputMemoryStream.defaultBufferSize));

  final int maximumLength;

  void _reserve(int count) {
    if (count < 0 || count > maximumLength - length) {
      throw const FormatException('Backup entry expands beyond its limit.');
    }
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    _reserve(writeLength);
    super.writeBytes(bytes, length: writeLength);
  }

  @override
  void writeStream(InputStream stream) {
    _reserve(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _reserve(count);
    super.writeBackReference(distance, count);
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
