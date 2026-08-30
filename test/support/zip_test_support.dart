import 'dart:convert';
import 'dart:typed_data';

/// Adds a second central-directory record pointing at the same local entry.
/// This constructs an input that ordinary Archive.addFile APIs normalize away.
Uint8List duplicateZipCentralDirectoryEntry(
  List<int> source,
  String entryName,
) {
  final bytes = Uint8List.fromList(source);
  final eocd = _lastIndexOf(bytes, const <int>[0x50, 0x4b, 0x05, 0x06]);
  if (eocd < 0 || eocd + 22 > bytes.length) {
    throw const FormatException('ZIP end record is missing.');
  }
  final view = ByteData.sublistView(bytes);
  final entryCount = view.getUint16(eocd + 10, Endian.little);
  final centralSize = view.getUint32(eocd + 12, Endian.little);
  final centralOffset = view.getUint32(eocd + 16, Endian.little);
  var cursor = centralOffset;
  Uint8List? record;
  while (cursor < centralOffset + centralSize) {
    if (view.getUint32(cursor, Endian.little) != 0x02014b50) {
      throw const FormatException('ZIP central directory is invalid.');
    }
    final nameLength = view.getUint16(cursor + 28, Endian.little);
    final extraLength = view.getUint16(cursor + 30, Endian.little);
    final commentLength = view.getUint16(cursor + 32, Endian.little);
    final recordLength = 46 + nameLength + extraLength + commentLength;
    final name = utf8.decode(
      bytes.sublist(cursor + 46, cursor + 46 + nameLength),
    );
    if (name == entryName) {
      record = Uint8List.fromList(bytes.sublist(cursor, cursor + recordLength));
      break;
    }
    cursor += recordLength;
  }
  if (record == null) throw const FormatException('ZIP entry is missing.');

  final result = Uint8List(bytes.length + record.length);
  result.setRange(0, eocd, bytes);
  result.setRange(eocd, eocd + record.length, record);
  result.setRange(eocd + record.length, result.length, bytes, eocd);
  final resultView = ByteData.sublistView(result);
  final newEocd = eocd + record.length;
  resultView.setUint16(newEocd + 8, entryCount + 1, Endian.little);
  resultView.setUint16(newEocd + 10, entryCount + 1, Endian.little);
  resultView.setUint32(
    newEocd + 12,
    centralSize + record.length,
    Endian.little,
  );
  return result;
}

/// Changes only the central-directory size declaration. This creates a tiny
/// compressed input that would request an attacker-controlled allocation if
/// entry content were materialized before metadata preflight.
Uint8List setZipCentralUncompressedSize(
  List<int> source,
  String entryName,
  int uncompressedSize,
) {
  final bytes = Uint8List.fromList(source);
  final record = _centralRecordOffset(bytes, entryName);
  ByteData.sublistView(bytes)
      .setUint32(record + 24, uncompressedSize, Endian.little);
  return bytes;
}

/// Changes both declarations while retaining the original deflate payload.
/// A decoder that trusts metadata only would inflate beyond this smaller size.
Uint8List setZipDeclaredUncompressedSize(
  List<int> source,
  String entryName,
  int uncompressedSize,
) {
  final bytes = Uint8List.fromList(source);
  final record = _centralRecordOffset(bytes, entryName);
  final view = ByteData.sublistView(bytes);
  final localOffset = view.getUint32(record + 42, Endian.little);
  view.setUint32(record + 24, uncompressedSize, Endian.little);
  view.setUint32(localOffset + 22, uncompressedSize, Endian.little);
  return bytes;
}

/// Marks a central-directory entry as a Unix symbolic link without touching
/// its compressed payload.
Uint8List markZipEntryAsUnixSymlink(List<int> source, String entryName) {
  final bytes = Uint8List.fromList(source);
  final record = _centralRecordOffset(bytes, entryName);
  final view = ByteData.sublistView(bytes);
  view.setUint16(record + 4, 0x031e, Endian.little);
  view.setUint32(record + 38, 0xa000 << 16, Endian.little);
  return bytes;
}

/// Rewrites a same-length local-header name while leaving the central name
/// intact, exercising central/local consistency checks.
Uint8List renameZipLocalEntry(
  List<int> source,
  String centralEntryName,
  String replacement,
) {
  final bytes = Uint8List.fromList(source);
  final record = _centralRecordOffset(bytes, centralEntryName);
  final view = ByteData.sublistView(bytes);
  final localOffset = view.getUint32(record + 42, Endian.little);
  final nameLength = view.getUint16(localOffset + 26, Endian.little);
  final replacementBytes = utf8.encode(replacement);
  if (replacementBytes.length != nameLength) {
    throw const FormatException('Replacement ZIP name length differs.');
  }
  bytes.setRange(
    localOffset + 30,
    localOffset + 30 + nameLength,
    replacementBytes,
  );
  return bytes;
}

int _centralRecordOffset(List<int> bytes, String entryName) {
  final eocd = _lastIndexOf(bytes, const <int>[0x50, 0x4b, 0x05, 0x06]);
  if (eocd < 0 || eocd + 22 > bytes.length) {
    throw const FormatException('ZIP end record is missing.');
  }
  final view = ByteData.sublistView(Uint8List.fromList(bytes));
  final centralSize = view.getUint32(eocd + 12, Endian.little);
  final centralOffset = view.getUint32(eocd + 16, Endian.little);
  var cursor = centralOffset;
  while (cursor < centralOffset + centralSize) {
    if (view.getUint32(cursor, Endian.little) != 0x02014b50) {
      throw const FormatException('ZIP central directory is invalid.');
    }
    final nameLength = view.getUint16(cursor + 28, Endian.little);
    final extraLength = view.getUint16(cursor + 30, Endian.little);
    final commentLength = view.getUint16(cursor + 32, Endian.little);
    final name = utf8.decode(
      bytes.sublist(cursor + 46, cursor + 46 + nameLength),
    );
    if (name == entryName) return cursor;
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  throw const FormatException('ZIP entry is missing.');
}

int _lastIndexOf(List<int> bytes, List<int> pattern) {
  for (var offset = bytes.length - pattern.length; offset >= 0; offset--) {
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
