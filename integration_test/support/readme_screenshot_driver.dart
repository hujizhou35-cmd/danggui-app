import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputPath = Platform.environment['DANGGUI_README_SCREENSHOT_OUTPUT'];
  if (outputPath == null || outputPath.trim().isEmpty) {
    stderr.writeln(
      'DANGGUI_README_SCREENSHOT_OUTPUT must point to the artifact directory.',
    );
    exitCode = 64;
    return;
  }
  final outputDirectory = Directory(outputPath);
  await outputDirectory.create(recursive: true);

  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      if (!RegExp(
        r'^(zh|en)-0[1-7]-[a-z-]+$',
      ).hasMatch(screenshotName)) {
        throw StateError('Unsafe README screenshot name: $screenshotName');
      }
      if (!_hasPngSignature(screenshotBytes)) {
        throw StateError('$screenshotName did not contain a valid PNG.');
      }
      final image = File('${outputDirectory.path}/$screenshotName.png');
      await image.writeAsBytes(screenshotBytes, flush: true);
      return true;
    },
  );
}

bool _hasPngSignature(List<int> bytes) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}
