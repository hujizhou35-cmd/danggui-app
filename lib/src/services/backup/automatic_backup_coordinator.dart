import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/app_store.dart';
import '../../domain/models.dart';
import 'backup_service.dart';

const automaticBackupPassphraseStorageKey =
    'danggui.automatic_backup.passphrase.v1';
const automaticBackupRetentionCount = 30;

final automaticBackupPassphraseStoreProvider =
    Provider<AutomaticBackupPassphraseStore>(
      (ref) => const AutomaticBackupPassphraseStore(),
    );

final class AutomaticBackupPassphraseStore {
  const AutomaticBackupPassphraseStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;

  Future<String?> read() =>
      _storage.read(key: automaticBackupPassphraseStorageKey);

  Future<void> write(String passphrase) {
    if (passphrase.length < 8) {
      throw const FormatException(
        'Automatic backup passphrase must have 8+ characters.',
      );
    }
    return _storage.write(
      key: automaticBackupPassphraseStorageKey,
      value: passphrase,
    );
  }

  Future<void> clear() =>
      _storage.delete(key: automaticBackupPassphraseStorageKey);
}

final automaticBackupCoordinatorProvider = Provider<AutomaticBackupCoordinator>(
  (ref) {
    return AutomaticBackupCoordinator(
      clock: DateTime.now,
      readSettings: () async =>
          (await ref.read(appStoreProvider.future)).settings,
      readPassphrase: ref.read(automaticBackupPassphraseStoreProvider).read,
      readDirectory: () async {
        final support = await getApplicationSupportDirectory();
        return Directory(p.join(support.path, 'danggui', 'backups', 'daily'));
      },
      createBackup:
          ({required passphrase, required kind, required outputDirectory}) =>
              ref
                  .read(backupServiceProvider)
                  .create(
                    passphrase: passphrase,
                    kind: kind,
                    outputDirectory: outputDirectory,
                  ),
    );
  },
);

typedef AutomaticBackupCreator = Future<BackupExport> Function({
  required String? passphrase,
  required String kind,
  required Directory outputDirectory,
});

enum AutomaticBackupTrigger { startup, foreground, explicitCheck }

enum AutomaticBackupStatus {
  created,
  disabled,
  notDue,
  alreadyCompleted,
  skippedMissingEncryptionPassphrase,
}

final class AutomaticBackupResult {
  const AutomaticBackupResult({
    required this.status,
    required this.trigger,
    required this.coveredLocalDate,
    required this.removedOldBackups,
    required this.retentionCompleted,
    this.backup,
    this.retentionErrorCode,
  });

  final AutomaticBackupStatus status;
  final AutomaticBackupTrigger trigger;

  /// The scheduled local date satisfied by this run. A catch-up created after
  /// midnight can therefore cover the preceding date.
  final String? coveredLocalDate;
  final BackupExport? backup;
  final int removedOldBackups;
  final bool retentionCompleted;
  final String? retentionErrorCode;
}

/// Best-effort daily backup policy for startup and foreground reconciliation.
///
/// The coordinator records the *scheduled local date* covered by a successful
/// backup, rather than only the file creation timestamp. This permits a missed
/// 02:00 run to be caught up at 01:00 the next day without suppressing that
/// next day's own 02:00 run.
final class AutomaticBackupCoordinator {
  AutomaticBackupCoordinator({
    required this.clock,
    required this.readSettings,
    required this.readPassphrase,
    required this.readDirectory,
    required this.createBackup,
  });

  final DateTime Function() clock;
  final Future<AppSettingsModel> Function() readSettings;
  final Future<String?> Function() readPassphrase;
  final Future<Directory> Function() readDirectory;
  final AutomaticBackupCreator createBackup;

  Future<AutomaticBackupResult>? _inFlight;
  var _temporaryStateSequence = 0;

  Future<AutomaticBackupResult> onStartup() =>
      _runDeduplicated(AutomaticBackupTrigger.startup);

  Future<AutomaticBackupResult> onForeground() =>
      _runDeduplicated(AutomaticBackupTrigger.foreground);

  Future<AutomaticBackupResult> checkNow() =>
      _runDeduplicated(AutomaticBackupTrigger.explicitCheck);

  Future<AutomaticBackupResult> _runDeduplicated(
    AutomaticBackupTrigger trigger,
  ) {
    final running = _inFlight;
    if (running != null) return running;
    final operation = _runAndClear(trigger);
    _inFlight = operation;
    return operation;
  }

  Future<AutomaticBackupResult> _runAndClear(
    AutomaticBackupTrigger trigger,
  ) async {
    try {
      return await _evaluate(trigger);
    } finally {
      _inFlight = null;
    }
  }

  Future<AutomaticBackupResult> _evaluate(
    AutomaticBackupTrigger trigger,
  ) async {
    final settings = await readSettings();
    _validateSchedule(settings);
    final directory = await readDirectory();
    await directory.create(recursive: true);
    final now = _local(clock());
    final today = _dateKey(now);
    var state = await _readState(directory);

    if (!settings.autoBackupEnabled) {
      if (state == null || state.enabled) {
        state = _AutomaticBackupState(
          enabled: false,
          initializedLocalDate: today,
          lastCoveredLocalDate: state?.lastCoveredLocalDate,
        );
        await _writeState(directory, state, now);
      }
      return AutomaticBackupResult(
        status: AutomaticBackupStatus.disabled,
        trigger: trigger,
        coveredLocalDate: state.lastCoveredLocalDate,
        removedOldBackups: 0,
        retentionCompleted: true,
      );
    }

    final becameEnabled = state == null || !state.enabled;
    if (becameEnabled) {
      state = _AutomaticBackupState(
        enabled: true,
        initializedLocalDate: today,
        lastCoveredLocalDate: state?.lastCoveredLocalDate,
      );
      // Persist initialization even if creation later fails. It is the datum
      // that prevents a first launch before 02:00 from inventing a missed run
      // for the day before installation/enabling.
      await _writeState(directory, state, now);
    }

    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      settings.autoBackupHourLocal,
      settings.autoBackupMinuteLocal,
    );
    final candidateDate = now.isBefore(scheduledToday)
        ? _dateKey(DateTime(now.year, now.month, now.day - 1))
        : today;

    if (candidateDate.compareTo(state.initializedLocalDate) < 0) {
      return _resultWithRetention(
        directory: directory,
        status: AutomaticBackupStatus.notDue,
        trigger: trigger,
        coveredLocalDate: state.lastCoveredLocalDate,
      );
    }
    final lastCovered = state.lastCoveredLocalDate;
    if (lastCovered != null && lastCovered.compareTo(candidateDate) >= 0) {
      return _resultWithRetention(
        directory: directory,
        status: AutomaticBackupStatus.alreadyCompleted,
        trigger: trigger,
        coveredLocalDate: lastCovered,
      );
    }

    String? passphrase;
    if (settings.backupEncryptionEnabled) {
      passphrase = await readPassphrase();
      if (passphrase == null || passphrase.length < 8) {
        return _resultWithRetention(
          directory: directory,
          status: AutomaticBackupStatus.skippedMissingEncryptionPassphrase,
          trigger: trigger,
          coveredLocalDate: lastCovered,
        );
      }
    }

    final backup = await createBackup(
      passphrase: passphrase,
      kind: 'daily',
      outputDirectory: directory,
    );
    state = _AutomaticBackupState(
      enabled: true,
      initializedLocalDate: state.initializedLocalDate,
      lastCoveredLocalDate: candidateDate,
    );
    await _writeState(directory, state, now);
    return _resultWithRetention(
      directory: directory,
      status: AutomaticBackupStatus.created,
      trigger: trigger,
      coveredLocalDate: candidateDate,
      backup: backup,
    );
  }

  Future<AutomaticBackupResult> _resultWithRetention({
    required Directory directory,
    required AutomaticBackupStatus status,
    required AutomaticBackupTrigger trigger,
    required String? coveredLocalDate,
    BackupExport? backup,
  }) async {
    final retention = await _rotateSafely(directory);
    return AutomaticBackupResult(
      status: status,
      trigger: trigger,
      coveredLocalDate: coveredLocalDate,
      backup: backup,
      removedOldBackups: retention.removed,
      retentionCompleted: retention.errorCode == null,
      retentionErrorCode: retention.errorCode,
    );
  }

  Future<_RetentionResult> _rotateSafely(Directory directory) async {
    try {
      final candidates = <({File file, DateTime modified})>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('danggui-') || !name.endsWith('.dgbak')) {
          continue;
        }
        candidates.add((
          file: entity,
          modified: (await entity.stat()).modified,
        ));
      }
      candidates.sort((left, right) {
        final byTime = right.modified.compareTo(left.modified);
        return byTime != 0 ? byTime : right.file.path.compareTo(left.file.path);
      });
      var removed = 0;
      for (final candidate in candidates.skip(automaticBackupRetentionCount)) {
        await candidate.file.delete();
        removed++;
      }
      return _RetentionResult(removed: removed);
    } on Object catch (error) {
      return _RetentionResult(errorCode: _stableErrorCode(error));
    }
  }

  Future<_AutomaticBackupState?> _readState(Directory directory) async {
    final primary = File(p.join(directory.path, _stateFileName));
    final previous = File(p.join(directory.path, _previousStateFileName));
    for (final candidate in <File>[primary, previous]) {
      if (!await candidate.exists()) continue;
      try {
        final decoded = jsonDecode(await candidate.readAsString());
        if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
          continue;
        }
        final initialized = decoded['initializedLocalDate'];
        final covered = decoded['lastCoveredLocalDate'];
        final enabled = decoded['enabled'];
        if (enabled is! bool ||
            initialized is! String ||
            !_validDateKey(initialized) ||
            (covered != null &&
                (covered is! String || !_validDateKey(covered)))) {
          continue;
        }
        return _AutomaticBackupState(
          enabled: enabled,
          initializedLocalDate: initialized,
          lastCoveredLocalDate: covered as String?,
        );
      } on Object {
        // A torn/corrupt marker is treated as first observation. Before the
        // configured time that choice skips, rather than invents, a backup.
      }
    }
    return null;
  }

  Future<void> _writeState(
    Directory directory,
    _AutomaticBackupState state,
    DateTime now,
  ) async {
    await directory.create(recursive: true);
    final primary = File(p.join(directory.path, _stateFileName));
    final previous = File(p.join(directory.path, _previousStateFileName));
    final temporary = File(
      p.join(
        directory.path,
        '$_stateFileName.tmp-${_temporaryStateSequence++}',
      ),
    );
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'enabled': state.enabled,
        'initializedLocalDate': state.initializedLocalDate,
        'lastCoveredLocalDate': state.lastCoveredLocalDate,
        'updatedAtUtc': now.toUtc().toIso8601String(),
      }),
      flush: true,
    );
    if (!await primary.exists() && await previous.exists()) {
      await previous.rename(primary.path);
    }
    if (await previous.exists()) await previous.delete();
    var movedPrimary = false;
    try {
      if (await primary.exists()) {
        await primary.rename(previous.path);
        movedPrimary = true;
      }
      await temporary.rename(primary.path);
      if (await previous.exists()) await previous.delete();
    } on Object {
      if (movedPrimary && !await primary.exists() && await previous.exists()) {
        await previous.rename(primary.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static void _validateSchedule(AppSettingsModel settings) {
    if (settings.autoBackupHourLocal < 0 ||
        settings.autoBackupHourLocal > 23 ||
        settings.autoBackupMinuteLocal < 0 ||
        settings.autoBackupMinuteLocal > 59) {
      throw ArgumentError('Automatic backup local time is invalid.');
    }
  }
}

const _stateFileName = '.automatic-backup-state-v1.json';
const _previousStateFileName = '.automatic-backup-state-v1.previous.json';

final class _AutomaticBackupState {
  const _AutomaticBackupState({
    required this.enabled,
    required this.initializedLocalDate,
    required this.lastCoveredLocalDate,
  });

  final bool enabled;
  final String initializedLocalDate;
  final String? lastCoveredLocalDate;
}

final class _RetentionResult {
  const _RetentionResult({this.removed = 0, this.errorCode});

  final int removed;
  final String? errorCode;
}

DateTime _local(DateTime value) => value.isUtc ? value.toLocal() : value;

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _validDateKey(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && _dateKey(parsed) == value;
}

String _stableErrorCode(Object error) {
  final normalized = error.runtimeType.toString().replaceAll(
    RegExp(r'[^A-Za-z0-9_]'),
    '_',
  );
  return normalized.length <= 64 ? normalized : normalized.substring(0, 64);
}
