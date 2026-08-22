import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../domain/repositories.dart';

final class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  @override
  String next() => const Uuid().v4();
}

int utcMicros(DateTime value) => value.toUtc().microsecondsSinceEpoch;

DateTime dateTimeFromUtcMicros(int value) =>
    DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);

String normalizedSearchText(String value) => value.trim().toLowerCase();

String canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalValue(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalValue).toList(growable: false);
  }
  return value;
}

Future<String> sha256Hex(Object? value) async {
  final digest = await Sha256().hash(utf8.encode(canonicalJson(value)));
  final buffer = StringBuffer();
  for (final byte in digest.bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

void validateIsoDate(String? value) {
  if (value == null) return;
  final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(value);
  if (match == null || DateTime.tryParse(value) == null) {
    throw const FormatException('Expected an ISO local date (YYYY-MM-DD).');
  }
}

void validateLocalTime(String value) {
  final match = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
  if (match == null) {
    throw const FormatException('Expected a 24-hour local time (HH:mm).');
  }
}
