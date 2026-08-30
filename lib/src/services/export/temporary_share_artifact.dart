import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef TemporaryDirectoryReader = Future<Directory> Function();

/// Runs [action] while an app-generated temporary share artifact exists, then
/// removes the source file regardless of whether the platform share sheet was
/// completed, dismissed, or failed.
///
/// Only Danggui's two exact output directories below the application temporary
/// root are eligible. In particular, automatic backups under Application
/// Support/danggui/backups/daily can never be removed through this helper.
Future<T> withDangguiTemporaryShareArtifact<T>({
  required File file,
  required Future<T> Function() action,
  TemporaryDirectoryReader? readTemporaryDirectory,
}) async {
  Object? actionError;
  try {
    return await action();
  } on Object catch (error) {
    actionError = error;
    rethrow;
  } finally {
    try {
      await deleteDangguiTemporaryShareArtifact(
        file,
        readTemporaryDirectory: readTemporaryDirectory,
      );
    } on Object {
      // Keep the original share failure visible. A later startup retries the
      // exact app-owned directory cleanup if deletion itself also failed.
      if (actionError == null) rethrow;
    }
  }
}

Future<void> deleteDangguiTemporaryShareArtifact(
  File file, {
  TemporaryDirectoryReader? readTemporaryDirectory,
}) async {
  final temporaryRoot =
      (await (readTemporaryDirectory ?? getTemporaryDirectory).call()).absolute;
  final artifact = file.absolute;
  final parentName = p.basename(artifact.parent.path);
  final fileName = p.basename(artifact.path);
  final isPortableExport =
      parentName == 'danggui-portable-exports' &&
      fileName.startsWith('danggui-') &&
      fileName.endsWith('.zip');
  final isManualBackup =
      parentName == 'danggui-backups' &&
      fileName.startsWith('danggui-') &&
      fileName.endsWith('.dgbak');
  final expectedParent = p.normalize(p.join(temporaryRoot.path, parentName));
  if (p.normalize(artifact.parent.path) != expectedParent ||
      !p.isWithin(temporaryRoot.path, artifact.path) ||
      (!isPortableExport && !isManualBackup)) {
    throw FileSystemException(
      'Refusing to delete a non-temporary Danggui share artifact.',
      artifact.path,
    );
  }

  final type = await FileSystemEntity.type(artifact.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) return;
  final parentType = await FileSystemEntity.type(
    artifact.parent.path,
    followLinks: false,
  );
  if (parentType != FileSystemEntityType.directory) {
    throw FileSystemException(
      'Temporary share artifact parent is not a regular directory.',
      artifact.parent.path,
    );
  }
  final resolvedRoot = p.normalize(await temporaryRoot.resolveSymbolicLinks());
  final resolvedParent = p.normalize(
    await artifact.parent.resolveSymbolicLinks(),
  );
  if (resolvedParent != p.join(resolvedRoot, parentName)) {
    throw FileSystemException(
      'Temporary share artifact parent escapes the temporary root.',
      artifact.parent.path,
    );
  }
  switch (type) {
    case FileSystemEntityType.file:
      await artifact.delete();
      return;
    case FileSystemEntityType.link:
      await Link(artifact.path).delete();
      return;
    case FileSystemEntityType.directory:
    case FileSystemEntityType.pipe:
    case FileSystemEntityType.unixDomainSock:
      throw FileSystemException(
        'Temporary share artifact has an unsupported type.',
        artifact.path,
      );
    case FileSystemEntityType.notFound:
      return;
  }
}
