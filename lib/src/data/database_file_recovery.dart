import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'database.dart';

/// Crash-recovery journal for replacing the live SQLite database.
///
/// The replacement candidate and safety copy must live beside the database.
/// A same-directory rename is the process-crash commit point. The small journal
/// lets startup clean up a prepared-but-uncommitted candidate or recover a
/// missing/damaged live file. Dart cannot fsync the parent directory, so this
/// class deliberately makes no guarantee for sudden power loss.
final class DatabaseFileRecovery {
  const DatabaseFileRecovery._();

  static const _journalVersion = 1;
  static const _journalSuffix = '.restore-journal-v1.json';
  static const _candidateMarker = '.restore-candidate-';
  static const _safetyMarker = '.pre-restore-';

  static File journalFile(File liveFile) =>
      File('${liveFile.absolute.path}$_journalSuffix');

  static File candidateFile(File liveFile, String operationId) => File(
    '${liveFile.absolute.path}$_candidateMarker${_safeOperationId(operationId)}',
  );

  /// Removes plaintext SQLite staging left by an interrupted backup/restore.
  /// Only exact app-owned children of the supplied temporary root are touched.
  static Future<void> purgeStalePlaintextArtifacts(
    Directory temporaryRoot,
  ) async {
    final root = temporaryRoot.absolute;
    for (final name in const <String>[
      'danggui-backup-work',
      'danggui-restore-validation',
      'danggui-portable-exports',
      'danggui-backups',
    ]) {
      final targetPath = p.normalize(p.join(root.path, name));
      if (!p.isWithin(root.path, targetPath)) {
        throw const FileSystemException(
          'Temporary database cleanup path escaped its root.',
        );
      }
      final type = await FileSystemEntity.type(targetPath, followLinks: false);
      switch (type) {
        case FileSystemEntityType.notFound:
          break;
        case FileSystemEntityType.directory:
          await Directory(targetPath).delete(recursive: true);
          break;
        case FileSystemEntityType.file:
          await File(targetPath).delete();
          break;
        case FileSystemEntityType.link:
          await Link(targetPath).delete();
          break;
        default:
          throw const FileSystemException(
            'Temporary database cleanup target has an unsupported type.',
          );
      }
    }
  }

  /// Flushes and records a prepared candidate before replacement.
  ///
  /// This is process-crash-consistent. It is not a power-loss guarantee because
  /// the parent directory cannot be fsynced through Dart's file API.
  static Future<void> writePreparedJournal({
    required File liveFile,
    required File candidate,
    required File safetyCopy,
  }) async {
    final parent = liveFile.absolute.parent;
    _requireSibling(
      parent,
      candidate,
      expectedPrefix: '${p.basename(liveFile.path)}$_candidateMarker',
    );
    _requireSibling(
      parent,
      safetyCopy,
      expectedPrefix: '${p.basename(liveFile.path)}$_safetyMarker',
    );
    if (!await _isValidDatabase(candidate) ||
        !await _isValidDatabase(safetyCopy)) {
      throw const FileSystemException(
        'Restore journal requires fully validated database images.',
      );
    }
    final marker = journalFile(liveFile);
    final temporary = File('${marker.path}.partial');
    if (await marker.exists()) {
      throw const FileSystemException(
        'A previous database restore still requires recovery.',
      );
    }
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': _journalVersion,
        'candidateName': p.basename(candidate.path),
        'safetyCopyName': p.basename(safetyCopy.path),
      }),
      flush: true,
    );
    try {
      await temporary.rename(marker.path);
      await _flushFile(marker);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Resolves an interrupted replacement before Drift opens the live path.
  static Future<void> recoverIfNeeded(File liveFile) async {
    final marker = journalFile(liveFile);
    if (!await marker.exists()) {
      await _purgeOrphanCandidates(liveFile);
      return;
    }

    final liveValid = await _isValidDatabase(liveFile);
    late final _RestoreJournal journal;
    try {
      journal = await _readJournal(liveFile, marker);
    } on Object {
      // A corrupt marker must not make a known-good database unavailable.
      // Unknown candidate paths are deliberately left untouched.
      if (liveValid) {
        await marker.delete();
        return;
      }
      rethrow;
    }

    if (liveValid) {
      // Either the commit never happened (old live image) or it completed
      // before the marker could be removed (new live image). Both are safe.
      await _deleteDatabaseFiles(journal.candidate);
      await marker.delete();
      return;
    }

    File? replacement;
    if (await _isValidDatabase(journal.candidate)) {
      replacement = journal.candidate;
    } else if (await _isValidDatabase(journal.safetyCopy)) {
      replacement = File('${journal.candidate.path}.recovered');
      await _deleteDatabaseFiles(replacement);
      await journal.safetyCopy.copy(replacement.path);
      await _flushFile(replacement);
      if (!await _isValidDatabase(replacement)) {
        await _deleteDatabaseFiles(replacement);
        replacement = null;
      }
    }
    if (replacement == null) {
      throw const FileSystemException(
        'Interrupted restore has no valid database image to recover.',
      );
    }

    if (await liveFile.exists()) {
      await _moveDamagedDatabaseAside(liveFile);
    } else {
      await _deleteSidecars(liveFile);
    }
    await replacement.rename(liveFile.path);
    await _flushFile(liveFile);
    await _deleteSidecars(liveFile);
    if (!await _isValidDatabase(liveFile)) {
      // Keep the journal and safety copy so the next startup can retry from a
      // known-good image instead of accepting an unverified rename result.
      throw const FileSystemException(
        'Recovered database failed post-rename integrity validation.',
      );
    }
    await _deleteSidecars(liveFile);
    await _deleteDatabaseFiles(journal.candidate);
    await marker.delete();
  }

  static Future<_RestoreJournal> _readJournal(
    File liveFile,
    File marker,
  ) async {
    final decoded = jsonDecode(await marker.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != _journalVersion ||
        decoded['candidateName'] is! String ||
        decoded['safetyCopyName'] is! String) {
      throw const FormatException('Database restore journal is invalid.');
    }
    final parent = liveFile.absolute.parent;
    final candidate = File(
      p.join(parent.path, decoded['candidateName']! as String),
    );
    final safetyCopy = File(
      p.join(parent.path, decoded['safetyCopyName']! as String),
    );
    _requireSibling(
      parent,
      candidate,
      expectedPrefix: '${p.basename(liveFile.path)}$_candidateMarker',
    );
    _requireSibling(
      parent,
      safetyCopy,
      expectedPrefix: '${p.basename(liveFile.path)}$_safetyMarker',
    );
    return _RestoreJournal(candidate: candidate, safetyCopy: safetyCopy);
  }

  static void _requireSibling(
    Directory parent,
    File file, {
    required String expectedPrefix,
  }) {
    final absolute = file.absolute;
    final name = p.basename(absolute.path);
    if (!p.equals(absolute.parent.path, parent.path) ||
        !name.startsWith(expectedPrefix) ||
        name.contains('/') ||
        name.contains('\\')) {
      throw const FormatException('Database restore path is invalid.');
    }
  }

  static Future<bool> _isValidDatabase(File file) async {
    if (!await file.exists() ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      return false;
    }
    RandomAccessFile? reader;
    try {
      reader = await file.open();
      if (await reader.length() < 100) return false;
      final header = await reader.read(100);
      if (ascii.decode(header.sublist(0, 16), allowInvalid: true) !=
              'SQLite format 3\u0000' ||
          ByteData.sublistView(Uint8List.fromList(header))
                  .getUint32(60, Endian.big) !=
              1) {
        return false;
      }
    } on Object {
      return false;
    } finally {
      await reader?.close();
    }

    DangguiDatabase? database;
    try {
      database = DangguiDatabase.open(file);
      final integrityCheck = await database.integrityCheck();
      if (integrityCheck.length != 1 ||
          integrityCheck.single.toLowerCase() != 'ok' ||
          (await database.foreignKeyCheck()).isNotEmpty) {
        return false;
      }
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final valid = version.data.values.single == database.schemaVersion;
      if (valid) {
        await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      }
      return valid;
    } on Object {
      return false;
    } finally {
      await database?.close();
    }
  }

  static Future<void> _moveDamagedDatabaseAside(File liveFile) async {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final damaged = File('${liveFile.path}.failed-restore-$stamp');
    await liveFile.rename(damaged.path);
    for (final suffix in const <String>['-wal', '-shm', '-journal']) {
      final sidecar = File('${liveFile.path}$suffix');
      if (await sidecar.exists()) {
        await sidecar.rename('${damaged.path}$suffix');
      }
    }
  }

  static Future<void> _deleteDatabaseFiles(File file) async {
    if (await file.exists()) await file.delete();
    await _deleteSidecars(file);
  }

  static Future<void> _deleteSidecars(File file) async {
    for (final suffix in const <String>['-wal', '-shm', '-journal']) {
      final sidecar = File('${file.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }

  /// Startup-only cleanup for app-owned candidates that cannot belong to an
  /// active restore because no journal exists. Names and entity types are
  /// checked without following links; unrelated siblings are never touched.
  static Future<void> _purgeOrphanCandidates(File liveFile) async {
    final parent = liveFile.absolute.parent;
    if (!await parent.exists()) return;
    final prefix = '${p.basename(liveFile.path)}$_candidateMarker';
    final candidateName = RegExp(
      '^${RegExp.escape(prefix)}[A-Za-z0-9_-]{1,64}'
      r'$',
    );
    await for (final entity in parent.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!candidateName.hasMatch(name)) continue;
      await _deleteEntryNoFollow(entity.path);
      for (final suffix in const <String>['-wal', '-shm', '-journal']) {
        await _deleteEntryNoFollow('${entity.path}$suffix');
      }
    }
  }

  static Future<void> _deleteEntryNoFollow(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.file:
        await File(path).delete();
        return;
      case FileSystemEntityType.link:
        await Link(path).delete();
        return;
      case FileSystemEntityType.directory:
        throw const FileSystemException(
          'Orphan restore candidate has an unsupported type.',
        );
      default:
        throw const FileSystemException(
          'Orphan restore candidate has an unsupported type.',
        );
    }
  }

  static Future<void> _flushFile(File file) async {
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  static String _safeOperationId(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (safe.isEmpty) {
      throw const FormatException('Database restore operation ID is invalid.');
    }
    return safe.length <= 64 ? safe : safe.substring(0, 64);
  }
}

final class _RestoreJournal {
  const _RestoreJournal({required this.candidate, required this.safetyCopy});

  final File candidate;
  final File safetyCopy;
}
