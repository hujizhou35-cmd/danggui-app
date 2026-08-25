// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as path;

const _screenSlugs = <String>[
  'startup',
  'tasks-reminders',
  'task-detail',
  'past',
  'notes',
  'export-settings',
  'privacy-settings',
];

Future<void> main(List<String> arguments) async {
  try {
    final locale = _option(arguments, '--locale');
    final directoryPath = _option(arguments, '--directory');
    if (!const {'zh', 'en'}.contains(locale)) {
      throw FormatException('Unsupported locale "$locale"; expected zh or en.');
    }
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw FileSystemException(
        'Screenshot directory does not exist.',
        directoryPath,
      );
    }

    final expectedNames = <String>[
      for (var index = 0; index < _screenSlugs.length; index += 1)
        '$locale-${(index + 1).toString().padLeft(2, '0')}-${_screenSlugs[index]}.png',
    ];
    final actualNames = await directory
        .list(followLinks: false)
        .where((entity) => entity is File && entity.path.endsWith('.png'))
        .map((entity) => path.basename(entity.path))
        .toList();
    actualNames.sort();
    final sortedExpected = List<String>.of(expectedNames)..sort();
    if (!_sameStrings(actualNames, sortedExpected)) {
      throw StateError(
        'README screenshot set mismatch.\n'
        'Expected: ${sortedExpected.join(', ')}\n'
        'Actual:   ${actualNames.join(', ')}',
      );
    }

    final files = <Map<String, Object?>>[];
    int? sharedWidth;
    int? sharedHeight;
    for (var index = 0; index < expectedNames.length; index += 1) {
      final name = expectedNames[index];
      final bytes = await File(path.join(directoryPath, name)).readAsBytes();
      final dimensions = _pngDimensions(bytes, name);
      if (dimensions.width < 720 ||
          dimensions.height < 1280 ||
          dimensions.height <= dimensions.width) {
        throw StateError(
          '$name has unexpected screenshot dimensions '
          '${dimensions.width}x${dimensions.height}.',
        );
      }
      sharedWidth ??= dimensions.width;
      sharedHeight ??= dimensions.height;
      if (dimensions.width != sharedWidth ||
          dimensions.height != sharedHeight) {
        throw StateError(
          '$name does not match the first screenshot dimensions '
          '${sharedWidth}x$sharedHeight.',
        );
      }
      final digest = await Sha256().hash(bytes);
      files.add(<String, Object?>{
        'order': index + 1,
        'id': _screenSlugs[index],
        'file': name,
        'width': dimensions.width,
        'height': dimensions.height,
        'bytes': bytes.length,
        'sha256': _hex(digest.bytes),
      });
    }

    final manifest = <String, Object?>{
      'schemaVersion': 1,
      'product': 'Danggui',
      'locale': locale,
      'platform': 'android',
      'androidApiLevel': 36,
      'captureTool': 'IntegrationTestWidgetsFlutterBinding.takeScreenshot',
      'sourceCommit': Platform.environment['GITHUB_SHA'] ?? 'local',
      'files': files,
    };
    final manifestFile = File(path.join(directoryPath, '$locale-manifest.json'));
    await manifestFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
      flush: true,
    );
    print(
      'Verified ${files.length} $locale README screenshots at '
      '${sharedWidth}x$sharedHeight and wrote ${manifestFile.path}.',
    );
  } on Object catch (error) {
    stderr.writeln('README screenshot verification failed: $error');
    exitCode = 1;
  }
}

String _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) {
    throw FormatException('Missing required option $name.');
  }
  return arguments[index + 1];
}

({int width, int height}) _pngDimensions(Uint8List bytes, String name) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) {
    throw StateError('$name is too short to be a PNG.');
  }
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) {
      throw StateError('$name does not have the PNG signature.');
    }
  }
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _hex(List<int> bytes) => bytes
    .map((value) => value.toRadixString(16).padLeft(2, '0'))
    .join();
