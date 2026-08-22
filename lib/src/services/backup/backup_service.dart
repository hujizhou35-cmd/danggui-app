import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_store.dart';
import '../../data/database.dart';
import '../../domain/models.dart';
import 'backup_codec.dart';
import 'backup_merge.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    readDatabase: () => ref.read(databaseProvider.future),
    readDatabaseFile: () => ref.read(databaseFileProvider.future),
    invalidateDatabase: () {
      ref.invalidate(databaseProvider);
      ref.invalidate(appStoreProvider);
    },
  );
});

final class BackupExport {
  const BackupExport({
    required this.file,
    required this.manifest,
    required this.encrypted,
  });

  final File file;
  final Map<String, Object?> manifest;
  final bool encrypted;
}

final class RestoreResult {
  const RestoreResult({
    required this.manifest,
    required this.safetyCopy,
    required this.encrypted,
    this.mode = RestoreMode.replace,
    this.summary = const <String, Object?>{},
  });

  final Map<String, Object?> manifest;
  final File safetyCopy;
  final bool encrypted;
  final RestoreMode mode;
  final Map<String, Object?> summary;
}

enum RestoreMode { replace, merge }

/// Metadata returned after fully authenticating and opening a backup package.
///
/// Inspection operates only on an isolated temporary copy; it never opens or
/// mutates the live application database.
final class BackupInspection {
  const BackupInspection({
    required this.manifest,
    required this.recordCounts,
    required this.encrypted,
    required this.archiveSha256,
  });

  final Map<String, Object?> manifest;
  final Map<String, int> recordCounts;
  final bool encrypted;
  final String archiveSha256;
}

final class BackupService {
  BackupService({
    required this.readDatabase,
    required this.readDatabaseFile,
    required this.invalidateDatabase,
  });

  static const _uuid = Uuid();

  /// Dependencies are injectable so the service can be exercised without a
  /// global provider container.
  final Future<DangguiDatabase> Function() readDatabase;
  final Future<File> Function() readDatabaseFile;
  final void Function() invalidateDatabase;

  Future<BackupExport> create({
    String? passphrase,
    String kind = 'manual',
    Directory? outputDirectory,
  }) async {
    if (kind != 'manual' && kind != 'daily') {
      throw ArgumentError.value(kind, 'kind', 'Expected manual or daily.');
    }
    final database = await readDatabase();
    final databaseFile = await readDatabaseFile();
    final startedAt = DateTime.now().toUtc();
    final runId = _uuid.v4();
    final encrypted = passphrase != null;
    await _insertBackupRun(database, runId, startedAt, kind);

    File? databaseSnapshot;
    File? partialOutput;
    File? output;
    try {
      await _setBackupRunStatus(database, runId, 'writing');

      // In WAL mode, a truncate checkpoint gives us a self-contained main
      // database image. Later writes start a new WAL generation and therefore
      // do not make this image internally inconsistent.
      await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final temp = await getTemporaryDirectory();
      final workingDirectory = Directory(
        p.join(temp.path, 'danggui-backup-work'),
      );
      final targetDirectory =
          outputDirectory ?? Directory(p.join(temp.path, 'danggui-backups'));
      await workingDirectory.create(recursive: true);
      await targetDirectory.create(recursive: true);
      databaseSnapshot = File(
        p.join(workingDirectory.path, 'snapshot-$runId.sqlite'),
      );
      await databaseFile.copy(databaseSnapshot.path);

      // Export a portable copy rather than device capabilities such as
      // security-scoped locators, wrapped keys and native notification IDs.
      final snapshotDatabase = DangguiDatabase.open(databaseSnapshot);
      late final String datasetId;
      late final Map<String, int> recordCounts;
      try {
        await _stripDeviceStateForExport(snapshotDatabase);
        final quickCheck = await snapshotDatabase.quickCheck();
        final foreignKeys = await snapshotDatabase.foreignKeyCheck();
        if (quickCheck.length != 1 ||
            quickCheck.single.toLowerCase() != 'ok' ||
            foreignKeys.isNotEmpty) {
          throw const FileSystemException(
            'Backup database snapshot validation failed.',
          );
        }
        final metadata = await snapshotDatabase
            .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
            .getSingle();
        datasetId = metadata.read<String>('dataset_id');
        recordCounts = await _recordCounts(snapshotDatabase);
        await snapshotDatabase.customStatement(
          'PRAGMA wal_checkpoint(TRUNCATE)',
        );
      } finally {
        await snapshotDatabase.close();
      }
      await _deleteSidecars(databaseSnapshot);
      final databaseBytes = await databaseSnapshot.readAsBytes();
      await databaseSnapshot.delete();
      databaseSnapshot = null;

      final manifest = <String, Object?>{
        'appId': 'com.danggui.memo',
        'appVersion': '1.0.0+1',
        'createdAtUtc': startedAt.toIso8601String(),
        'datasetId': datasetId,
        'databaseSchemaVersion': database.schemaVersion,
        'kind': kind,
        'recordCounts': recordCounts,
      };
      final packageBytes = await BackupCodec.encode(
        databaseBytes: databaseBytes,
        manifest: manifest,
        passphrase: passphrase,
      );

      final stamp = startedAt
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      output = File(
        p.join(
          targetDirectory.path,
          'danggui-$stamp-${runId.substring(0, 8)}'
          '${encrypted ? '-encrypted' : ''}.dgbak',
        ),
      );
      partialOutput = File('${output.path}.partial');
      await partialOutput.writeAsBytes(packageBytes, flush: true);
      await _setBackupRunStatus(database, runId, 'verifying');

      final persistedBytes = await partialOutput.readAsBytes();
      final archiveHash = await sha256OfBytes(packageBytes);
      if (persistedBytes.length != packageBytes.length ||
          await sha256OfBytes(persistedBytes) != archiveHash) {
        throw const FileSystemException('Backup write verification failed.');
      }
      await partialOutput.rename(output.path);
      partialOutput = null;

      final completedAt = DateTime.now().toUtc();
      await database.customStatement(
        'UPDATE backup_runs SET status = ?, archive_name = ?, '
        'record_counts_json = ?, byte_length = ?, archive_sha256 = ?, '
        'completed_at_utc = ?, error_code = NULL WHERE id = ?',
        <Object?>[
          'succeeded',
          p.basename(output.path),
          jsonEncode(recordCounts),
          packageBytes.length,
          archiveHash,
          completedAt.microsecondsSinceEpoch,
          runId,
        ],
      );
      return BackupExport(
        file: output,
        manifest: manifest,
        encrypted: encrypted,
      );
    } on Object catch (error) {
      await _deleteIfPresent(databaseSnapshot);
      if (databaseSnapshot != null) {
        await _deleteSidecars(databaseSnapshot);
      }
      await _deleteIfPresent(partialOutput);
      await _deleteIfPresent(output);
      try {
        await database.customStatement(
          'UPDATE backup_runs SET status = ?, completed_at_utc = ?, '
          'error_code = ? WHERE id = ?',
          <Object?>[
            'failed',
            DateTime.now().toUtc().microsecondsSinceEpoch,
            _errorCode(error),
            runId,
          ],
        );
      } on Object {
        // Keep the original error when recording the audit failure also fails.
      }
      rethrow;
    }
  }

  Future<File?> pickBackup() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['dgbak'],
    );
    final path = result?.path;
    return path == null ? null : File(path);
  }

  Future<BackupInspection> inspect(File source, {String? passphrase}) async {
    final validated = await _openValidatedBackup(source, passphrase);
    try {
      return BackupInspection(
        manifest: Map<String, Object?>.unmodifiable(validated.decoded.manifest),
        recordCounts: Map<String, int>.unmodifiable(validated.recordCounts),
        encrypted: validated.decoded.encrypted,
        archiveSha256: validated.archiveSha256,
      );
    } finally {
      await validated.dispose();
    }
  }

  /// Restores [source] by replacing the complete dataset (the compatible
  /// default) or by atomically importing user-owned entities into the current
  /// dataset. Package authentication and database validation always complete
  /// before the live database is opened.
  Future<RestoreResult> restore(
    File source, {
    String? passphrase,
    RestoreMode mode = RestoreMode.replace,
  }) async {
    final validated = await _openValidatedBackup(source, passphrase);
    try {
      return await switch (mode) {
        RestoreMode.replace => _restoreReplace(source, validated),
        RestoreMode.merge => _restoreMerge(source, validated),
      };
    } finally {
      await validated.dispose();
    }
  }

  Future<RestoreResult> _restoreReplace(
    File source,
    _ValidatedBackup validated,
  ) async {
    final decoded = validated.decoded;
    final schemaVersion = decoded.manifest['databaseSchemaVersion']! as int;
    final liveDatabase = await readDatabase();
    final liveFile = await readDatabaseFile();
    await liveDatabase.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await liveFile.parent.create(recursive: true);
    if (!await liveFile.exists()) {
      throw const FileSystemException('Live database file does not exist.');
    }

    final operationId = _uuid.v4();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final safetyCopy = File(
      '${liveFile.path}.pre-restore-$stamp-${operationId.substring(0, 8)}',
    );
    try {
      await _prepareRestoredDatabase(validated.database);
      await _insertRestoreAudit(
        validated.database,
        id: operationId,
        sourceName: p.basename(source.path),
        sourceSha256: validated.archiveSha256,
        sourceSchemaVersion: schemaVersion,
        encrypted: decoded.encrypted,
        safetyCopyName: p.basename(safetyCopy.path),
      );
      await validated.database.customStatement(
        'PRAGMA wal_checkpoint(TRUNCATE)',
      );
      await validated.closeDatabase();
      await _deleteSidecars(validated.staging);
    } on Object {
      throw const FormatException('Backup database preparation failed.');
    }
    await liveDatabase.close();
    var movedLive = false;
    try {
      await _deleteSidecars(liveFile);
      await liveFile.rename(safetyCopy.path);
      movedLive = true;
      await validated.staging.rename(liveFile.path);
      validated.stagingMoved = true;
    } on Object {
      if (movedLive && !await liveFile.exists()) {
        await safetyCopy.rename(liveFile.path);
      }
      rethrow;
    } finally {
      // The previous Drift instance was closed regardless of swap outcome.
      invalidateDatabase();
    }
    return RestoreResult(
      manifest: decoded.manifest,
      safetyCopy: safetyCopy,
      encrypted: decoded.encrypted,
      mode: RestoreMode.replace,
      summary: <String, Object?>{
        'mode': RestoreMode.replace.name,
        'recordCounts': validated.recordCounts,
      },
    );
  }

  Future<RestoreResult> _restoreMerge(
    File source,
    _ValidatedBackup validated,
  ) async {
    final decoded = validated.decoded;
    final schemaVersion = decoded.manifest['databaseSchemaVersion']! as int;
    final originDatasetId = decoded.manifest['datasetId']! as String;
    final liveDatabase = await readDatabase();
    final liveFile = await readDatabaseFile();
    await liveDatabase.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    if (!await liveFile.exists()) {
      throw const FileSystemException('Live database file does not exist.');
    }

    final operationId = _uuid.v4();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final safetyCopy = File(
      '${liveFile.path}.pre-merge-$stamp-${operationId.substring(0, 8)}',
    );
    await _createVerifiedSafetyCopy(liveFile, safetyCopy);
    await _insertMergeAuditStarted(
      liveDatabase,
      id: operationId,
      sourceName: p.basename(source.path),
      sourceSha256: validated.archiveSha256,
      sourceSchemaVersion: schemaVersion,
    );

    Map<String, Object?>? summary;
    try {
      final outcome =
          await BackupMergeEngine(
            source: validated.database,
            target: liveDatabase,
            restoreRunId: operationId,
            originDatasetId: originDatasetId,
          ).run(
            beforeCommit: (mergeSummary) async {
              summary = <String, Object?>{
                ...mergeSummary,
                'mode': RestoreMode.merge.name,
                'encrypted': decoded.encrypted,
                'safetyCopy': p.basename(safetyCopy.path),
              };
              // This update is deliberately executed inside the merge engine's
              // transaction. Imported content, conflict/provenance rows and the
              // success audit therefore become durable together or not at all.
              await liveDatabase.customStatement(
                'UPDATE restore_runs SET status = ?, summary_json = ?, '
                'completed_at_utc = ?, error_code = NULL WHERE id = ?',
                <Object?>[
                  'succeeded',
                  jsonEncode(summary),
                  DateTime.now().toUtc().microsecondsSinceEpoch,
                  operationId,
                ],
              );
            },
          );
      summary ??= outcome.summary;
    } on Object catch (error) {
      try {
        await liveDatabase.customStatement(
          'UPDATE restore_runs SET status = ?, completed_at_utc = ?, '
          'error_code = ? WHERE id = ?',
          <Object?>[
            'failed',
            DateTime.now().toUtc().microsecondsSinceEpoch,
            _errorCode(error),
            operationId,
          ],
        );
      } on Object {
        // Preserve the import error when writing its audit also fails.
      }
      rethrow;
    } finally {
      invalidateDatabase();
    }
    return RestoreResult(
      manifest: decoded.manifest,
      safetyCopy: safetyCopy,
      encrypted: decoded.encrypted,
      mode: RestoreMode.merge,
      summary: summary!,
    );
  }

  Future<_ValidatedBackup> _openValidatedBackup(
    File source,
    String? passphrase,
  ) async {
    if (!await source.exists()) {
      throw const FileSystemException('Backup file does not exist.');
    }
    final packageBytes = await source.readAsBytes();
    final archiveSha256 = await sha256OfBytes(packageBytes);
    final decoded = await BackupCodec.decode(
      packageBytes,
      passphrase: passphrase,
    );
    if (decoded.manifest['appId'] != 'com.danggui.memo') {
      throw const FormatException('Backup belongs to a different app.');
    }
    final schemaVersion = decoded.manifest['databaseSchemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw const FormatException('Backup database version is unsupported.');
    }

    final validationDirectory = Directory(
      p.join(Directory.systemTemp.path, 'danggui-restore-validation'),
    );
    await validationDirectory.create(recursive: true);
    final staging = File(
      p.join(validationDirectory.path, 'restore-${_uuid.v4()}.sqlite'),
    );
    await staging.writeAsBytes(decoded.databaseBytes, flush: true);
    final database = DangguiDatabase.open(staging);
    try {
      await _validateRestoreDatabase(database, decoded.manifest);
      final recordCounts = await _recordCounts(database);
      _validateManifestRecordCounts(decoded.manifest, recordCounts);
      return _ValidatedBackup(
        decoded: decoded,
        staging: staging,
        database: database,
        recordCounts: recordCounts,
        archiveSha256: archiveSha256,
      );
    } on FormatException {
      await database.close();
      await _deleteIfPresent(staging);
      await _deleteSidecars(staging);
      rethrow;
    } on Object {
      await database.close();
      await _deleteIfPresent(staging);
      await _deleteSidecars(staging);
      throw const FormatException('Backup database validation failed.');
    }
  }

  static Future<Map<String, int>> _recordCounts(
    DangguiDatabase database,
  ) async {
    const tables = <String>[
      'tasks',
      'notes',
      'folders',
      'document_blocks',
      'past_events',
      'reminders',
      'trash_entries',
    ];
    final result = <String, int>{};
    for (final table in tables) {
      final row = await database
          .customSelect('SELECT COUNT(*) AS total FROM $table')
          .getSingle();
      result[table] = row.read<int>('total');
    }
    return result;
  }

  static Future<void> _insertBackupRun(
    DangguiDatabase database,
    String runId,
    DateTime now,
    String kind,
  ) {
    return database.customStatement(
      'INSERT INTO backup_runs '
      '(id, target_id, encryption_profile_id, kind, status, archive_name, '
      'app_version, database_schema_version, manifest_version, '
      'record_counts_json, byte_length, archive_sha256, started_at_utc, '
      'completed_at_utc, error_code) '
      'VALUES (?, NULL, NULL, ?, ?, NULL, ?, ?, 1, NULL, NULL, NULL, ?, '
      'NULL, NULL)',
      <Object?>[
        runId,
        kind,
        'started',
        '1.0.0+1',
        database.schemaVersion,
        now.microsecondsSinceEpoch,
      ],
    );
  }

  static Future<void> _setBackupRunStatus(
    DangguiDatabase database,
    String runId,
    String status,
  ) {
    return database.customStatement(
      'UPDATE backup_runs SET status = ? WHERE id = ?',
      <Object?>[status, runId],
    );
  }

  static Future<void> _stripDeviceStateForExport(DangguiDatabase database) {
    return database.transaction(() async {
      await database.customStatement('DELETE FROM notification_registrations');
      await database.customStatement('DELETE FROM platform_jobs');
      await database.customStatement('DELETE FROM backup_targets');
      await database.customStatement('DELETE FROM backup_encryption_profiles');
    });
  }

  static Future<void> _validateRestoreDatabase(
    DangguiDatabase database,
    Map<String, Object?> manifest,
  ) async {
    final quickCheck = await database.quickCheck();
    final foreignKeys = await database.foreignKeyCheck();
    if (quickCheck.length != 1 ||
        quickCheck.single.toLowerCase() != 'ok' ||
        foreignKeys.isNotEmpty) {
      throw const FormatException('Backup database integrity check failed.');
    }
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    if (version.data.values.single != database.schemaVersion) {
      throw const FormatException('Backup database schema does not match.');
    }
    final metadata = await database
        .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
        .getSingleOrNull();
    if (metadata == null ||
        metadata.read<String>('dataset_id') != manifest['datasetId']) {
      throw const FormatException('Backup dataset identity does not match.');
    }
    final singletons = await database
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM app_settings WHERE id = 1) AS settings, '
          "(SELECT COUNT(*) FROM documents WHERE singleton_key = 'past.main') "
          'AS past_documents',
        )
        .getSingle();
    if (singletons.read<int>('settings') != 1 ||
        singletons.read<int>('past_documents') != 1) {
      throw const FormatException('Backup singleton records are invalid.');
    }
  }

  static void _validateManifestRecordCounts(
    Map<String, Object?> manifest,
    Map<String, int> actual,
  ) {
    final declared = manifest['recordCounts'];
    if (declared is! Map) {
      throw const FormatException('Backup record counts are missing.');
    }
    for (final entry in actual.entries) {
      final value = declared[entry.key];
      if (value is! int || value != entry.value) {
        throw FormatException(
          'Backup record count does not match for ${entry.key}.',
        );
      }
    }
  }

  static Future<void> _prepareRestoredDatabase(DangguiDatabase database) async {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    await database.transaction(() async {
      // These values describe the source device, not portable user intent.
      await database.customStatement('DELETE FROM notification_registrations');
      await database.customStatement('DELETE FROM platform_jobs');
      await database.customStatement('DELETE FROM backup_targets');
      await database.customStatement('DELETE FROM backup_encryption_profiles');
      await database.customStatement(
        'UPDATE reminders SET status = ?, pause_reason = NULL, '
        'updated_at_utc = ?, row_version = row_version + 1 '
        'WHERE status = ? AND scheduled_at_utc <= ?',
        <Object?>[
          ReminderStatus.expired.name,
          now,
          ReminderStatus.scheduled.name,
          now,
        ],
      );

      // Recreate the device outbox from logical future reminders. The native
      // coordinator will assign new platform notification identifiers.
      final reminders = await database
          .customSelect(
            'SELECT r.id, r.task_id, r.schedule_revision '
            'FROM reminders r JOIN tasks t ON t.id = r.task_id '
            'WHERE r.status = ? AND r.scheduled_at_utc > ? '
            'AND t.status = ? AND t.deleted_at_utc IS NULL',
            variables: <Variable<Object>>[
              Variable.withString(ReminderStatus.scheduled.name),
              Variable.withInt(now),
              Variable.withString(TaskStatus.active.name),
            ],
          )
          .get();
      for (final reminder in reminders) {
        final reminderId = reminder.read<String>('id');
        final taskId = reminder.read<String>('task_id');
        final revision = reminder.read<int>('schedule_revision');
        final kind = PlatformJobKind.scheduleReminder.name;
        await database.customStatement(
          'INSERT INTO platform_jobs '
          '(id, kind, aggregate_id, aggregate_revision, dedupe_key, '
          'payload_json, status, attempts, next_attempt_at_utc, '
          'last_error_code, created_at_utc, updated_at_utc) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, NULL, ?, ?)',
          <Object?>[
            _uuid.v4(),
            kind,
            reminderId,
            revision,
            '$kind:$reminderId:$revision',
            jsonEncode(<String, Object?>{'taskId': taskId}),
            PlatformJobStatus.pending.name,
            now,
            now,
            now,
          ],
        );
      }
      for (final table in const <String>['backup_runs', 'restore_runs']) {
        await database.customStatement(
          'UPDATE $table SET status = ?, completed_at_utc = ?, '
          'error_code = ? WHERE status IN (?, ?, ?)',
          <Object?>[
            'failed',
            now,
            'interruptedByRestore',
            'started',
            'writing',
            'verifying',
          ],
        );
      }
    });
  }

  static Future<void> _insertRestoreAudit(
    DangguiDatabase database, {
    required String id,
    required String sourceName,
    required String sourceSha256,
    required int sourceSchemaVersion,
    required bool encrypted,
    required String safetyCopyName,
  }) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    return database.customStatement(
      'INSERT INTO restore_runs '
      '(id, source_name, source_sha256, mode, source_schema_version, '
      'pre_restore_backup_run_id, status, summary_json, started_at_utc, '
      'completed_at_utc, error_code) '
      'VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, NULL)',
      <Object?>[
        id,
        sourceName,
        sourceSha256,
        'replace',
        sourceSchemaVersion,
        'succeeded',
        jsonEncode(<String, Object?>{
          'encrypted': encrypted,
          'safetyCopy': safetyCopyName,
        }),
        now,
        now,
      ],
    );
  }

  static Future<void> _insertMergeAuditStarted(
    DangguiDatabase database, {
    required String id,
    required String sourceName,
    required String sourceSha256,
    required int sourceSchemaVersion,
  }) {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    return database.customStatement(
      'INSERT INTO restore_runs '
      '(id, source_name, source_sha256, mode, source_schema_version, '
      'pre_restore_backup_run_id, status, summary_json, started_at_utc, '
      'completed_at_utc, error_code) '
      'VALUES (?, ?, ?, ?, ?, NULL, ?, NULL, ?, NULL, NULL)',
      <Object?>[
        id,
        sourceName,
        sourceSha256,
        RestoreMode.merge.name,
        sourceSchemaVersion,
        'started',
        now,
      ],
    );
  }

  static Future<void> _createVerifiedSafetyCopy(
    File liveFile,
    File safetyCopy,
  ) async {
    await liveFile.parent.create(recursive: true);
    var valid = false;
    DangguiDatabase? verification;
    try {
      await liveFile.copy(safetyCopy.path);
      verification = DangguiDatabase.open(safetyCopy);
      final quickCheck = await verification.quickCheck();
      final foreignKeys = await verification.foreignKeyCheck();
      if (quickCheck.length != 1 ||
          quickCheck.single.toLowerCase() != 'ok' ||
          foreignKeys.isNotEmpty) {
        throw const FileSystemException(
          'Pre-merge safety copy validation failed.',
        );
      }
      await verification.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      valid = true;
    } finally {
      await verification?.close();
      await _deleteSidecars(safetyCopy);
      if (!valid) await _deleteIfPresent(safetyCopy);
    }
  }

  static Future<void> _deleteIfPresent(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  static Future<void> _deleteSidecars(File databaseFile) async {
    for (final suffix in const <String>['-wal', '-shm']) {
      final sidecar = File('${databaseFile.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
  }
}

final class _ValidatedBackup {
  _ValidatedBackup({
    required this.decoded,
    required this.staging,
    required this.database,
    required this.recordCounts,
    required this.archiveSha256,
  });

  final DecodedBackup decoded;
  final File staging;
  final DangguiDatabase database;
  final Map<String, int> recordCounts;
  final String archiveSha256;
  bool databaseClosed = false;
  bool stagingMoved = false;

  Future<void> closeDatabase() async {
    if (databaseClosed) return;
    await database.close();
    databaseClosed = true;
  }

  Future<void> dispose() async {
    await closeDatabase();
    if (!stagingMoved) await BackupService._deleteIfPresent(staging);
    await BackupService._deleteSidecars(staging);
  }
}

String _errorCode(Object error) {
  final normalized = error.runtimeType.toString().replaceAll(
    RegExp(r'[^A-Za-z0-9_]'),
    '_',
  );
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
