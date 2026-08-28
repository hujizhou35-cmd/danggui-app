import 'dart:io';

import 'package:danggui/src/services/export/temporary_share_artifact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory temporaryRoot;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'danggui-share-cleanup-',
    );
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  Future<Directory> readTemporaryDirectory() async => temporaryRoot;

  Future<File> artifact(String directoryName, String fileName) async {
    final directory = Directory(p.join(temporaryRoot.path, directoryName));
    await directory.create(recursive: true);
    return File(p.join(directory.path, fileName))
      ..writeAsStringSync('private user data');
  }

  test('completed share removes its portable export source', () async {
    final file = await artifact(
      'danggui-portable-exports',
      'danggui-full-test.zip',
    );

    final result = await withDangguiTemporaryShareArtifact(
      file: file,
      readTemporaryDirectory: readTemporaryDirectory,
      action: () async {
        expect(await file.exists(), isTrue);
        return 'completed';
      },
    );

    expect(result, 'completed');
    expect(await file.exists(), isFalse);
  });

  test('dismissed share removes its manual backup source', () async {
    final file = await artifact('danggui-backups', 'danggui-manual-test.dgbak');

    final result = await withDangguiTemporaryShareArtifact(
      file: file,
      readTemporaryDirectory: readTemporaryDirectory,
      action: () async => const ShareResult('', ShareResultStatus.dismissed),
    );

    expect(result.status, ShareResultStatus.dismissed);
    expect(await file.exists(), isFalse);
  });

  test('failed share preserves its error and removes the source', () async {
    final file = await artifact(
      'danggui-portable-exports',
      'danggui-note-test.zip',
    );
    final failure = StateError('simulated share failure');

    await expectLater(
      withDangguiTemporaryShareArtifact<void>(
        file: file,
        readTemporaryDirectory: readTemporaryDirectory,
        action: () async => throw failure,
      ),
      throwsA(same(failure)),
    );
    expect(await file.exists(), isFalse);
  });

  test('unmounted short circuit still removes the source', () async {
    final file = await artifact(
      'danggui-portable-exports',
      'danggui-unmounted-test.zip',
    );
    var shareCalled = false;
    final lifecycleState = <bool>[false];

    await withDangguiTemporaryShareArtifact<void>(
      file: file,
      readTemporaryDirectory: readTemporaryDirectory,
      action: () async {
        if (!lifecycleState.single) return;
        shareCalled = true;
      },
    );

    expect(shareCalled, isFalse);
    expect(await file.exists(), isFalse);
  });

  test('formal Application Support daily backup is never deleted', () async {
    final formalRoot = await Directory.systemTemp.createTemp(
      'danggui-formal-backup-',
    );
    addTearDown(() async {
      if (await formalRoot.exists()) await formalRoot.delete(recursive: true);
    });
    final daily = Directory(
      p.join(
        formalRoot.path,
        'Application Support',
        'danggui',
        'backups',
        'daily',
      ),
    );
    await daily.create(recursive: true);
    final file = File(p.join(daily.path, 'danggui-daily-test.dgbak'));
    await file.writeAsString('formal backup');

    await expectLater(
      deleteDangguiTemporaryShareArtifact(
        file,
        readTemporaryDirectory: readTemporaryDirectory,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsString(), 'formal backup');
  });

  test(
    'allowed directory symlink cannot delete a file outside temporary root',
    () async {
      final outsideRoot = await Directory.systemTemp.createTemp(
        'danggui-share-outside-',
      );
      addTearDown(() async {
        if (await outsideRoot.exists()) {
          await outsideRoot.delete(recursive: true);
        }
      });
      final outsideFile = File(p.join(outsideRoot.path, 'danggui-escape.zip'));
      await outsideFile.writeAsString('must survive');
      final allowedLink = Link(
        p.join(temporaryRoot.path, 'danggui-portable-exports'),
      );
      await allowedLink.create(outsideRoot.path);
      final aliasedFile = File(
        p.join(allowedLink.path, p.basename(outsideFile.path)),
      );

      await expectLater(
        deleteDangguiTemporaryShareArtifact(
          aliasedFile,
          readTemporaryDirectory: readTemporaryDirectory,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await outsideFile.readAsString(), 'must survive');
    },
    skip: Platform.isWindows
        ? 'Creating directory symlinks is not portable on Windows CI.'
        : false,
  );
}
