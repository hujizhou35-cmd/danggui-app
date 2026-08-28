import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_store.dart';
import '../../core/app_version.dart';
import '../../data/database.dart';
import '../../data/database_file_recovery.dart';
import '../../data/database_schema_verifier.dart';
import '../../data/device_alarm_generation_store.dart';
import '../../data/search_projection_rebuilder.dart';
import '../../domain/models.dart';
import '../notifications/native_alarm_platform.dart';
import '../platform_mutation_gate.dart';
import 'backup_codec.dart';
import 'backup_merge.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final nativeAlarms = MethodChannelNativeAlarmPlatform();
  return BackupService(
    readDatabase: () => ref.read(databaseProvider.future),
    readDatabaseFile: () => ref.read(databaseFileProvider.future),
    invalidateDatabase: () {
      ref.invalidate(databaseProvider);
      ref.invalidate(appStoreProvider);
    },
    readTemporaryDirectory: getTemporaryDirectory,
    mutationGate: ref.read(platformMutationGateProvider),
    activateDeviceAlarmGeneration: nativeAlarms.activateDeviceGeneration,
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

/// Deterministic fault points used by recovery and low-storage tests.
/// Production leaves the injector unset.
enum BackupFaultPoint {
  snapshotCreated,
  partialArchiveWritten,
  restoreCandidatePrepared,
  restoreSafetySnapshotCreated,
  restoreJournalWritten,
  restoreSwapCommitted,
}

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
    this.faultInjector,
    Future<Directory> Function()? readTemporaryDirectory,
    Future<void> Function(File file, List<int> bytes)? writeRestoreStaging,
    DangguiDatabase Function(File file)? openRestoreDatabase,
    Future<void> Function(DangguiDatabase database)? closeRestoreDatabase,
    Future<int> Function(File file)? readSourceLength,
    Future<Uint8List> Function(File file)? readSourceBytes,
    Stream<List<int>> Function(File file)? openSourceBytes,
    this.maximumSourceBytes = BackupCodec.maximumPackageBytes,
    Future<void> Function(File file)? deleteCreateArtifact,
    Future<void> Function(File source, File destination)? writeRestoreCandidate,
    Future<void> Function(File file)? deleteRestoreArtifact,
    PlatformMutationGate? mutationGate,
    this.activateDeviceAlarmGeneration,
  }) : assert(maximumSourceBytes > 0),
       assert(maximumSourceBytes <= BackupCodec.maximumPackageBytes),
       readTemporaryDirectory =
           readTemporaryDirectory ?? (() async => Directory.systemTemp),
       writeRestoreStaging =
           writeRestoreStaging ??
           ((file, bytes) => file.writeAsBytes(bytes, flush: true)),
       openRestoreDatabase = openRestoreDatabase ?? DangguiDatabase.open,
       closeRestoreDatabase =
           closeRestoreDatabase ?? ((database) => database.close()),
       readSourceLength =
           readSourceLength ?? ((file) async => (await file.stat()).size),
       openSourceBytes =
           openSourceBytes ??
           (readSourceBytes == null
               ? ((file) => file.openRead())
               : ((file) =>
                     Stream<List<int>>.fromFuture(readSourceBytes(file)))),
       deleteCreateArtifact =
           deleteCreateArtifact ??
           ((file) async {
             if (await file.exists()) await file.delete();
           }),
       writeRestoreCandidate =
           writeRestoreCandidate ??
           ((source, destination) async {
             await source.copy(destination.path);
           }),
       deleteRestoreArtifact =
           deleteRestoreArtifact ??
           ((file) async {
             if (await file.exists()) await file.delete();
           }),
       _mutationGate = mutationGate ?? PlatformMutationGate();

  static const _uuid = Uuid();

  /// Dependencies are injectable so the service can be exercised without a
  /// global provider container.
  final Future<DangguiDatabase> Function() readDatabase;
  final Future<File> Function() readDatabaseFile;
  final void Function() invalidateDatabase;
  final Future<void> Function(BackupFaultPoint point)? faultInjector;
  final Future<Directory> Function() readTemporaryDirectory;
  final Future<void> Function(File file, List<int> bytes) writeRestoreStaging;
  final DangguiDatabase Function(File file) openRestoreDatabase;
  final Future<void> Function(DangguiDatabase database) closeRestoreDatabase;
  final Future<int> Function(File file) readSourceLength;
  final Stream<List<int>> Function(File file) openSourceBytes;
  final int maximumSourceBytes;
  final Future<void> Function(File file) deleteCreateArtifact;
  final Future<void> Function(File source, File destination)
  writeRestoreCandidate;
  final Future<void> Function(File file) deleteRestoreArtifact;
  final PlatformMutationGate _mutationGate;
  final Future<void> Function(String? generation)?
  activateDeviceAlarmGeneration;
  final _AsyncMutex _operationMutex = _AsyncMutex();

  Future<void> _injectFault(BackupFaultPoint point) async {
    await faultInjector?.call(point);
  }

  Future<BackupExport> create({
    String? passphrase,
    String kind = 'manual',
    Directory? outputDirectory,
  }) {
    return _operationMutex.protect(
      () => _create(
        passphrase: passphrase,
        kind: kind,
        outputDirectory: outputDirectory,
      ),
    );
  }

  Future<BackupExport> _create({
    required String? passphrase,
    required String kind,
    required Directory? outputDirectory,
  }) async {
    if (kind != 'manual' && kind != 'daily') {
      throw ArgumentError.value(kind, 'kind', 'Expected manual or daily.');
    }
    final database = await readDatabase();
    final startedAt = DateTime.now().toUtc();
    final runId = _uuid.v4();
    final encrypted = passphrase != null;
    await _insertBackupRun(database, runId, startedAt, kind);

    File? databaseSnapshot;
    File? partialOutput;
    File? output;
    try {
      await _setBackupRunStatus(database, runId, 'writing');

      final temp = await readTemporaryDirectory();
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
      await _deleteIfPresent(databaseSnapshot);
      // SQLite explicitly warns against copying a live database file. VACUUM
      // INTO obtains a consistent snapshot through SQLite itself, including
      // while later application writes continue in WAL mode.
      await database.customStatement('VACUUM INTO ?', <Object?>[
        databaseSnapshot.path,
      ]);
      await _injectFault(BackupFaultPoint.snapshotCreated);

      // Export a portable copy rather than device capabilities such as
      // security-scoped locators, wrapped keys and native notification IDs.
      final snapshotDatabase = DangguiDatabase.open(databaseSnapshot);
      late final String datasetId;
      late final Map<String, int> recordCounts;
      try {
        await _stripDeviceStateForExport(snapshotDatabase);
        final integrityCheck = await snapshotDatabase.integrityCheck();
        final foreignKeys = await snapshotDatabase.foreignKeyCheck();
        if (integrityCheck.length != 1 ||
            integrityCheck.single.toLowerCase() != 'ok' ||
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
        await _checkpointAndSwitchToDelete(snapshotDatabase);
      } finally {
        await snapshotDatabase.close();
      }
      await _verifySelfContainedDatabase(databaseSnapshot);
      final databaseBytes = await databaseSnapshot.readAsBytes();
      await databaseSnapshot.delete();
      databaseSnapshot = null;

      final manifest = <String, Object?>{
        'appId': 'com.danggui.memo',
        'appVersion': appTechnicalVersion,
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
      await _injectFault(BackupFaultPoint.partialArchiveWritten);
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
      await _bestEffortCleanupCreateArtifacts(
        databaseSnapshot: databaseSnapshot,
        partialOutput: partialOutput,
        output: output,
      );
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
    var bodyFailed = false;
    try {
      return BackupInspection(
        manifest: Map<String, Object?>.unmodifiable(validated.decoded.manifest),
        recordCounts: Map<String, int>.unmodifiable(validated.recordCounts),
        encrypted: validated.decoded.encrypted,
        archiveSha256: validated.archiveSha256,
      );
    } on Object {
      bodyFailed = true;
      rethrow;
    } finally {
      await validated.dispose(suppressCloseError: bodyFailed);
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
  }) {
    return _operationMutex.protect(
      () => _restore(source, passphrase: passphrase, mode: mode),
    );
  }

  Future<RestoreResult> _restore(
    File source, {
    required String? passphrase,
    required RestoreMode mode,
  }) async {
    final validated = await _openValidatedBackup(source, passphrase);
    var bodyFailed = false;
    try {
      return await _mutationGate.protect(
        () => switch (mode) {
          RestoreMode.replace => _restoreReplace(source, validated),
          RestoreMode.merge => _restoreMerge(source, validated),
        },
      );
    } on Object {
      bodyFailed = true;
      rethrow;
    } finally {
      await validated.dispose(suppressCloseError: bodyFailed);
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
    await liveFile.parent.create(recursive: true);
    if (!await liveFile.exists()) {
      throw const FileSystemException('Live database file does not exist.');
    }
    final previousGeneration = _nativeDeviceGeneration(
      await DeviceAlarmGenerationStore(liveDatabase).readCurrent(),
    );

    final operationId = _uuid.v4();
    final replacementGeneration = operationId.toLowerCase();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final safetyCopy = File(
      '${liveFile.path}.pre-restore-$stamp-${operationId.substring(0, 8)}',
    );
    final candidate = DatabaseFileRecovery.candidateFile(liveFile, operationId);
    await _prepareRestoredDatabase(validated.database);
    // Re-run schema, semantic, and count contracts after preparation so a
    // trigger or malformed constraint cannot silently change portable data.
    await _validateRestoreDatabase(validated.database, decoded.manifest);
    final preparedCounts = await _recordCounts(validated.database);
    _validateManifestRecordCounts(decoded.manifest, preparedCounts);
    await _insertRestoreAudit(
      validated.database,
      id: operationId,
      sourceName: p.basename(source.path),
      sourceSha256: validated.archiveSha256,
      sourceSchemaVersion: schemaVersion,
      encrypted: decoded.encrypted,
      safetyCopyName: p.basename(safetyCopy.path),
    );
    await _checkpointAndSwitchToDelete(validated.database);
    await validated.closeDatabase();
    await _flushFile(validated.staging);

    var liveClosed = false;
    var journalWritten = false;
    var replacementGenerationActivationAttempted = false;
    var swapCommitted = false;
    try {
      await _deleteRestoreCandidateFiles(candidate);
      await writeRestoreCandidate(validated.staging, candidate);
      await _flushFile(candidate);
      await _verifySelfContainedDatabase(candidate);
      await _injectFault(BackupFaultPoint.restoreCandidatePrepared);
      await liveDatabase.close();
      liveClosed = true;
      await _createVerifiedSafetySnapshotFromFile(liveFile, safetyCopy);
      await _injectFault(BackupFaultPoint.restoreSafetySnapshotCreated);
      // Refuse to swap while any connection still prevents a complete WAL
      // checkpoint. SQLite, rather than direct sidecar deletion, proves the
      // old live image is self-contained before its canonical path changes.
      await _verifySelfContainedDatabase(liveFile);
      // Fence the losing native projection before the database path changes.
      // If the process dies after this point, native recovery stays fail-closed
      // until the database-backed generation is activated again at startup.
      if (activateDeviceAlarmGeneration != null) {
        // The native fence may already be durable even when route retirement
        // subsequently reports an error. Mark the attempt before awaiting so
        // every pre-swap failure best-effort restores the generation owned by
        // the still-winning live database.
        replacementGenerationActivationAttempted = true;
        await activateDeviceAlarmGeneration!(replacementGeneration);
      }
      await DatabaseFileRecovery.writePreparedJournal(
        liveFile: liveFile,
        candidate: candidate,
        safetyCopy: safetyCopy,
      );
      journalWritten = true;
      await _injectFault(BackupFaultPoint.restoreJournalWritten);
      // POSIX/APFS and Dart's File.rename replace the destination as one
      // filesystem operation. The journal stays until the new live image is
      // known to occupy the canonical path.
      await candidate.rename(liveFile.path);
      swapCommitted = true;
      await _flushFile(liveFile);
      await _injectFault(BackupFaultPoint.restoreSwapCommitted);
      await _verifySelfContainedDatabase(liveFile);
      final journal = DatabaseFileRecovery.journalFile(liveFile);
      if (await journal.exists()) await journal.delete();
    } on Object {
      if (replacementGenerationActivationAttempted && !swapCommitted) {
        try {
          await activateDeviceAlarmGeneration?.call(previousGeneration);
        } on Object {
          // Preserve the restore failure. Startup reads the winning database
          // and re-activates its generation before native recovery proceeds.
        }
      }
      if (!journalWritten) {
        await _bestEffortCleanupRestoreCandidate(candidate);
      }
      rethrow;
    } finally {
      if (liveClosed) {
        // The previous Drift instance was closed regardless of swap outcome.
        invalidateDatabase();
      }
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
    await _createVerifiedSafetySnapshot(liveDatabase, safetyCopy);
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
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Backup source must be a regular file.');
    }
    final sourceLength = await readSourceLength(source);
    if (sourceLength <= 0 || sourceLength > maximumSourceBytes) {
      throw const FormatException('Backup size is invalid.');
    }
    // Stat rejects a known-oversized file before opening it. The stream then
    // repeats the bound before every append and requires the observed length
    // to match stat, closing the stat/read replacement and growth window.
    final packageBytes = await _readBoundedSourceBytes(
      source,
      expectedLength: sourceLength,
    );
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

    final temporaryRoot = await readTemporaryDirectory();
    final validationDirectory = Directory(
      p.join(temporaryRoot.absolute.path, 'danggui-restore-validation'),
    );
    await validationDirectory.create(recursive: true);
    final staging = File(
      p.join(validationDirectory.path, 'restore-${_uuid.v4()}.sqlite'),
    );
    DangguiDatabase? database;
    var ownershipTransferred = false;
    try {
      await writeRestoreStaging(staging, decoded.databaseBytes);
      database = openRestoreDatabase(staging);
      await _validateRestoreDatabase(database, decoded.manifest);
      final recordCounts = await _recordCounts(database);
      _validateManifestRecordCounts(decoded.manifest, recordCounts);
      final validated = _ValidatedBackup(
        decoded: decoded,
        staging: staging,
        database: database,
        recordCounts: recordCounts,
        archiveSha256: archiveSha256,
        closeDatabaseOperation: closeRestoreDatabase,
      );
      ownershipTransferred = true;
      return validated;
    } finally {
      if (!ownershipTransferred) {
        await _bestEffortCloseWith(database, closeRestoreDatabase);
        await _bestEffortDeleteDatabaseFiles(staging);
      }
    }
  }

  Future<Uint8List> _readBoundedSourceBytes(
    File source, {
    required int expectedLength,
  }) async {
    final output = BytesBuilder(copy: false);
    var observedLength = 0;
    await for (final chunk in openSourceBytes(source)) {
      if (chunk.isEmpty) continue;
      if (chunk.length > maximumSourceBytes - observedLength) {
        throw const FormatException('Backup size is invalid.');
      }
      output.add(chunk);
      observedLength += chunk.length;
    }
    if (observedLength != expectedLength) {
      throw const FormatException('Backup changed while it was being read.');
    }
    return output.takeBytes();
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
        appTechnicalVersion,
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
      await DeviceAlarmGenerationStore(database).stripFromPortableSnapshot();
    });
  }

  static Future<void> _validateRestoreDatabase(
    DangguiDatabase database,
    Map<String, Object?> manifest,
  ) async {
    await DangguiSchemaVerifier.verify(database);
    final integrityCheck = await database.integrityCheck();
    final foreignKeys = await database.foreignKeyCheck();
    if (integrityCheck.length != 1 ||
        integrityCheck.single.toLowerCase() != 'ok' ||
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
      await SearchProjectionRebuilder.rebuild(database);
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
    return DeviceAlarmGenerationStore(database).createForReplacement(
      operationId: id,
      sourceName: sourceName,
      sourceSha256: sourceSha256,
      sourceSchemaVersion: sourceSchemaVersion,
      encrypted: encrypted,
      safetyCopyName: safetyCopyName,
      completedAtUtc: now,
    );
  }

  static String? _nativeDeviceGeneration(String storedGeneration) =>
      storedGeneration.startsWith('legacy:')
      ? null
      : storedGeneration.toLowerCase();

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

  static Future<void> _createVerifiedSafetySnapshotFromFile(
    File liveFile,
    File safetyCopy,
  ) async {
    await safetyCopy.parent.create(recursive: true);
    final partial = File('${safetyCopy.path}.partial');
    await _deleteIfPresent(partial);
    await _deleteSidecars(partial);
    await _deleteIfPresent(safetyCopy);
    await _deleteSidecars(safetyCopy);
    DangguiDatabase? source;
    try {
      source = DangguiDatabase.open(liveFile);
      await source.customSelect('SELECT 1').getSingle();
      await source.customStatement('VACUUM INTO ?', <Object?>[partial.path]);
      await source.close();
      source = null;
      await _verifySelfContainedDatabase(partial);
      await partial.rename(safetyCopy.path);
      await _flushFile(safetyCopy);
    } on Object {
      await _bestEffortClose(source);
      await _bestEffortDeleteDatabaseFiles(partial);
      await _bestEffortDeleteDatabaseFiles(safetyCopy);
      rethrow;
    }
  }

  static Future<void> _createVerifiedSafetySnapshot(
    DangguiDatabase liveDatabase,
    File safetyCopy,
  ) async {
    await safetyCopy.parent.create(recursive: true);
    final partial = File('${safetyCopy.path}.partial');
    await _deleteIfPresent(partial);
    await _deleteSidecars(partial);
    await _deleteIfPresent(safetyCopy);
    await _deleteSidecars(safetyCopy);
    try {
      await liveDatabase.customStatement('VACUUM INTO ?', <Object?>[
        partial.path,
      ]);
      await _verifySelfContainedDatabase(partial);
      await partial.rename(safetyCopy.path);
      await _flushFile(safetyCopy);
    } on Object {
      await _bestEffortDeleteDatabaseFiles(partial);
      await _bestEffortDeleteDatabaseFiles(safetyCopy);
      rethrow;
    }
  }

  static Future<void> _verifySelfContainedDatabase(File file) async {
    DangguiDatabase? verification;
    try {
      verification = DangguiDatabase.open(file);
      final integrityCheck = await verification.integrityCheck();
      final foreignKeys = await verification.foreignKeyCheck();
      final version = await verification
          .customSelect('PRAGMA user_version')
          .getSingle();
      if (integrityCheck.length != 1 ||
          integrityCheck.single.toLowerCase() != 'ok' ||
          foreignKeys.isNotEmpty ||
          version.data.values.single != verification.schemaVersion) {
        throw const FileSystemException(
          'Prepared restore database validation failed.',
        );
      }
      await _checkpointAndSwitchToDelete(verification);
    } finally {
      await verification?.close();
    }
    await _flushFile(file);
    if (await File('${file.path}-wal').exists() ||
        await File('${file.path}-shm').exists()) {
      throw const FileSystemException(
        'SQLite image still has WAL sidecars after validation.',
      );
    }
  }

  static Future<void> _checkpointAndSwitchToDelete(
    DangguiDatabase database,
  ) async {
    try {
      final checkpoint = await database
          .customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
          .getSingle();
      final busy = checkpoint.data['busy'];
      final logFrames = checkpoint.data['log'];
      final checkpointed = checkpoint.data['checkpointed'];
      if (busy is! int ||
          logFrames is! int ||
          checkpointed is! int ||
          busy != 0 ||
          logFrames != checkpointed) {
        throw const FileSystemException(
          'SQLite WAL checkpoint did not complete.',
        );
      }
      final mode = await database
          .customSelect('PRAGMA journal_mode = DELETE')
          .getSingle();
      if (mode.data.values.single.toString().toLowerCase() != 'delete') {
        throw const FileSystemException(
          'SQLite database could not leave WAL mode.',
        );
      }
    } on FileSystemException {
      rethrow;
    } on Object {
      throw const FileSystemException(
        'SQLite database could not be made self-contained.',
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

  static Future<void> _bestEffortClose(DangguiDatabase? database) async {
    try {
      await database?.close();
    } on Object {
      // Cleanup continues so one close failure cannot retain plaintext files.
    }
  }

  Future<void> _bestEffortCleanupCreateArtifacts({
    required File? databaseSnapshot,
    required File? partialOutput,
    required File? output,
  }) async {
    final artifacts = <File>[
      ?databaseSnapshot,
      if (databaseSnapshot != null)
        for (final suffix in const <String>['-wal', '-shm', '-journal'])
          File('${databaseSnapshot.path}$suffix'),
      ?partialOutput,
      ?output,
    ];
    for (final artifact in artifacts) {
      try {
        await deleteCreateArtifact(artifact);
      } on Object {
        // Cleanup is exhaustive and never replaces the operation's error.
      }
    }
  }

  Future<void> _deleteRestoreCandidateFiles(File candidate) async {
    for (final artifact in _databaseArtifacts(candidate)) {
      await deleteRestoreArtifact(artifact);
    }
  }

  Future<void> _bestEffortCleanupRestoreCandidate(File candidate) async {
    for (final artifact in _databaseArtifacts(candidate)) {
      try {
        await deleteRestoreArtifact(artifact);
      } on Object {
        // Candidate cleanup cannot replace the restore operation's error.
      }
    }
  }

  static List<File> _databaseArtifacts(File database) => <File>[
    database,
    for (final suffix in const <String>['-wal', '-shm', '-journal'])
      File('${database.path}$suffix'),
  ];

  static Future<void> _bestEffortCloseWith(
    DangguiDatabase? database,
    Future<void> Function(DangguiDatabase database) close,
  ) async {
    if (database == null) return;
    try {
      await close(database);
    } on Object {
      // Cleanup continues so one close failure cannot retain plaintext files.
    }
  }

  static Future<void> _bestEffortDeleteDatabaseFiles(File file) async {
    try {
      await _deleteIfPresent(file);
    } on Object {
      // Continue with every sidecar independently.
    }
    for (final suffix in const <String>['-wal', '-shm', '-journal']) {
      try {
        await _deleteIfPresent(File('${file.path}$suffix'));
      } on Object {
        // Best-effort cleanup is intentionally exhaustive.
      }
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
    required this.closeDatabaseOperation,
  });

  final DecodedBackup decoded;
  final File staging;
  final DangguiDatabase database;
  final Map<String, int> recordCounts;
  final String archiveSha256;
  final Future<void> Function(DangguiDatabase database) closeDatabaseOperation;
  bool databaseClosed = false;
  bool stagingMoved = false;

  Future<void> closeDatabase() async {
    if (databaseClosed) return;
    await closeDatabaseOperation(database);
    databaseClosed = true;
  }

  Future<void> dispose({required bool suppressCloseError}) async {
    Object? closeError;
    StackTrace? closeStackTrace;
    try {
      await closeDatabase();
    } on Object catch (error, stackTrace) {
      closeError = error;
      closeStackTrace = stackTrace;
    } finally {
      if (!stagingMoved) {
        await BackupService._bestEffortDeleteDatabaseFiles(staging);
      }
    }
    if (closeError != null && !suppressCloseError) {
      Error.throwWithStackTrace(closeError, closeStackTrace!);
    }
  }
}

/// A FIFO asynchronous mutex. The queue tail never completes with an error,
/// so one failed backup or restore cannot poison later operations.
final class _AsyncMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> protect<T>(Future<T> Function() operation) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        released.complete();
      }
    }();
  }
}

String _errorCode(Object error) {
  final normalized = error.runtimeType.toString().replaceAll(
    RegExp(r'[^A-Za-z0-9_]'),
    '_',
  );
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
