import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';

part 'database.g.dart';

const _emptySha256 =
    '0000000000000000000000000000000000000000000000000000000000000000';

@DataClassName('AppMetaRow')
class AppMetadata extends Table {
  IntColumn get id => integer()();
  TextColumn get datasetId => text().unique()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get lastIntegrityCheckAtUtc => integer().nullable()();
  TextColumn get ftsMode => text().withDefault(const Constant('unknown'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'app_meta';

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  IntColumn get id => integer()();
  TextColumn get localeMode => textEnum<LocaleMode>()();
  TextColumn get fontMode => textEnum<FontMode>()();
  IntColumn get textScalePercent => integer()();
  TextColumn get density => textEnum<DisplayDensity>()();
  BoolColumn get defaultSoundEnabled => boolean()();
  BoolColumn get defaultVibrationEnabled => boolean()();
  IntColumn get defaultSnoozeMinutes => integer()();
  BoolColumn get autoBackupEnabled => boolean()();
  IntColumn get autoBackupHourLocal =>
      integer().withDefault(const Constant(2))();
  IntColumn get autoBackupMinuteLocal =>
      integer().withDefault(const Constant(0))();
  BoolColumn get backupEncryptionEnabled => boolean()();
  IntColumn get helpSeenVersion => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'app_settings';

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (text_scale_percent BETWEEN 90 AND 120)',
    'CHECK (default_snooze_minutes IN (10, 30, 60))',
    'CHECK (auto_backup_hour_local BETWEEN 0 AND 23)',
    'CHECK (auto_backup_minute_local BETWEEN 0 AND 59)',
  ];
}

@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<DocumentKind>()();
  TextColumn get singletonKey => text().nullable().unique()();
  IntColumn get formatVersion => integer().withDefault(const Constant(1))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get semanticHash => text()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK ((kind = 'past' AND singleton_key = 'past.main') OR "
        "(kind <> 'past' AND singleton_key IS NULL))",
  ];
}

@DataClassName('DocumentBlockRow')
class DocumentBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get parentBlockId => text().nullable().references(
    DocumentBlocks,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get sortRank => integer()();
  TextColumn get blockType => textEnum<DocumentBlockType>()();
  TextColumn get plainText => text().withDefault(const Constant(''))();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
  TextColumn get attributesJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isChecked => boolean().nullable()();
  TextColumn get semanticHash => text()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK ((block_type = 'checklist' AND is_checked IS NOT NULL) OR "
        "(block_type <> 'checklist' AND is_checked IS NULL))",
  ];
}

@DataClassName('DocumentRevisionRow')
class DocumentRevisions extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get revision => integer()();
  TextColumn get reason => text()();
  TextColumn get codec => text().withDefault(const Constant('json-v1'))();
  BlobColumn get snapshotBlob => blob()();
  TextColumn get snapshotSha256 => text()();
  IntColumn get createdAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TaskRow')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get documentId => text().unique().references(
    Documents,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get title => text()();
  TextColumn get dueLocalDate => text().nullable()();
  TextColumn get planText => text().withDefault(const Constant(''))();
  TextColumn get status => textEnum<TaskStatus>()();
  IntColumn get manualRank => integer()();
  IntColumn get closedAtUtc => integer().nullable()();
  TextColumn get closedLocalDate => text().nullable()();
  TextColumn get closedLocalTime => text().nullable()();
  TextColumn get closedZoneId => text().nullable()();
  IntColumn get archivedAtUtc => integer().nullable()();
  IntColumn get deletedAtUtc => integer().nullable()();
  TextColumn get semanticHash => text()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(title)) > 0)',
    "CHECK ((status = 'trashed') = (deleted_at_utc IS NOT NULL))",
    "CHECK (status <> 'completionPending' OR "
        '(closed_at_utc IS NOT NULL AND closed_local_date IS NOT NULL '
        'AND closed_local_time IS NOT NULL AND closed_zone_id IS NOT NULL))',
  ];
}

@DataClassName('ReminderRow')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().unique().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get scheduledLocalDateTime => text()();
  TextColumn get scheduledZoneId => text()();
  IntColumn get scheduledAtUtc => integer()();
  IntColumn get snoozedUntilUtc => integer().nullable()();
  BoolColumn get soundEnabled => boolean()();
  BoolColumn get vibrationEnabled => boolean()();
  TextColumn get status => textEnum<ReminderStatus>()();
  TextColumn get pauseReason => textEnum<ReminderPauseReason>().nullable()();
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();
  IntColumn get scheduleRevision => integer().withDefault(const Constant(1))();
  IntColumn get lastFiredAtUtc => integer().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NotificationRegistrationRow')
class NotificationRegistrations extends Table {
  TextColumn get reminderId =>
      text().references(Reminders, #id, onDelete: KeyAction.cascade)();
  TextColumn get platform => text()();
  IntColumn get platformNotificationId => integer().unique()();
  IntColumn get scheduleRevision => integer()();
  TextColumn get scheduledLocale => text()();
  IntColumn get registeredAtUtc => integer()();
  TextColumn get lastErrorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {reminderId};
}

@DataClassName('PlatformJobRow')
class PlatformJobs extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<PlatformJobKind>()();
  TextColumn get aggregateId => text()();
  IntColumn get aggregateRevision => integer()();
  TextColumn get dedupeKey => text().unique()();
  TextColumn get payloadJson => text()();
  TextColumn get status => textEnum<PlatformJobStatus>()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAtUtc => integer()();
  TextColumn get lastErrorCode => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  IntColumn get sortRank => integer()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get documentId => text().unique().references(
    Documents,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get folderId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get pinnedAtUtc => integer().nullable()();
  IntColumn get deletedAtUtc => integer().nullable()();
  TextColumn get semanticHash => text()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TrashEntryRow')
class TrashEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => textEnum<TrashEntityType>()();
  TextColumn get entityId => text()();
  IntColumn get deletedAtUtc => integer()();
  IntColumn get purgeAfterUtc => integer()();
  TextColumn get restoreContextJson => text()();
  TextColumn get snapshotSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PastEventRow')
class PastEvents extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.restrict)();
  TextColumn get sourceTaskId => text()();
  IntColumn get appendSequence => integer().unique()();
  IntColumn get completedAtUtc => integer()();
  TextColumn get completionLocalDate => text()();
  TextColumn get completionZoneId => text()();
  IntColumn get sourceSnapshotVersion =>
      integer().withDefault(const Constant(1))();
  TextColumn get sourceSnapshotJson => text()();
  TextColumn get sourceSha256 => text()();
  TextColumn get anchorState => textEnum<PastAnchorState>()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PastEventPartRow')
class PastEventParts extends Table {
  TextColumn get id => text()();
  TextColumn get eventId =>
      text().references(PastEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<PastPartRole>()();
  IntColumn get sourceOrder => integer()();
  TextColumn get originalPayloadJson => text()();
  TextColumn get originalPlainText => text()();
  TextColumn get originalSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PastAnchorLinkRow')
class PastAnchorLinks extends Table {
  TextColumn get id => text()();
  TextColumn get partId =>
      text().references(PastEventParts, #id, onDelete: KeyAction.cascade)();
  TextColumn get currentBlockId => text().nullable().references(
    DocumentBlocks,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get lastKnownBlockId => text()();
  TextColumn get relation => textEnum<AnchorRelation>()();
  TextColumn get linkState => textEnum<AnchorLinkState>()();
  TextColumn get currentSha256 => text().nullable()();
  IntColumn get updatedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SearchRecordRow')
class SearchRecords extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get scope => textEnum<SearchScope>()();
  TextColumn get entityId => text()();
  TextColumn get documentId => text().nullable()();
  TextColumn get titleNorm => text().withDefault(const Constant(''))();
  TextColumn get bodyNorm => text().withDefault(const Constant(''))();
  TextColumn get dateKey => text().withDefault(const Constant(''))();
  IntColumn get updatedAtUtc => integer()();
}

@DataClassName('BackupTargetRow')
class BackupTargets extends Table {
  TextColumn get id => text()();
  TextColumn get platform => text()();
  TextColumn get displayName => text()();
  TextColumn get locatorText => text().nullable()();
  BlobColumn get locatorBlob => blob().nullable()();
  TextColumn get permissionState => text()();
  BoolColumn get isDefault => boolean()();
  IntColumn get grantedAtUtc => integer().nullable()();
  IntColumn get lastVerifiedAtUtc => integer().nullable()();
  IntColumn get updatedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BackupEncryptionProfileRow')
class BackupEncryptionProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get kdf => text().withDefault(const Constant('argon2id-v1'))();
  IntColumn get kdfMemoryKib => integer().withDefault(const Constant(65536))();
  IntColumn get kdfIterations => integer().withDefault(const Constant(3))();
  IntColumn get kdfParallelism => integer().withDefault(const Constant(1))();
  BlobColumn get kdfSalt => blob()();
  BlobColumn get passwordEnvelopeNonce => blob()();
  BlobColumn get wrappedMasterKey => blob()();
  BlobColumn get wrappedMasterKeyMac => blob()();
  TextColumn get platformKeyAlias => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get rotatedAtUtc => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'backup_encryption_profiles';
}

@DataClassName('BackupRunRow')
class BackupRuns extends Table {
  TextColumn get id => text()();
  TextColumn get targetId => text().nullable().references(
    BackupTargets,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get encryptionProfileId => text().nullable().references(
    BackupEncryptionProfiles,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get kind => text()();
  TextColumn get status => text()();
  TextColumn get archiveName => text().nullable()();
  TextColumn get appVersion => text()();
  IntColumn get databaseSchemaVersion => integer()();
  IntColumn get manifestVersion => integer()();
  TextColumn get recordCountsJson => text().nullable()();
  IntColumn get byteLength => integer().nullable()();
  TextColumn get archiveSha256 => text().nullable()();
  IntColumn get startedAtUtc => integer()();
  IntColumn get completedAtUtc => integer().nullable()();
  TextColumn get errorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RestoreRunRow')
class RestoreRuns extends Table {
  TextColumn get id => text()();
  TextColumn get sourceName => text()();
  TextColumn get sourceSha256 => text().nullable()();
  TextColumn get mode => text()();
  IntColumn get sourceSchemaVersion => integer().nullable()();
  TextColumn get preRestoreBackupRunId => text().nullable().references(
    BackupRuns,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get status => text()();
  TextColumn get summaryJson => text().nullable()();
  IntColumn get startedAtUtc => integer()();
  IntColumn get completedAtUtc => integer().nullable()();
  TextColumn get errorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RestoreConflictRow')
class RestoreConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get restoreRunId =>
      text().references(RestoreRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get entityType => text()();
  TextColumn get incomingId => text()();
  TextColumn get resolvedLocalId => text().nullable()();
  TextColumn get incomingHash => text().nullable()();
  TextColumn get currentHash => text().nullable()();
  TextColumn get resolution => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  String get tableName => 'restore_conflicts';
}

@DataClassName('ImportProvenanceRow')
class ImportProvenance extends Table {
  TextColumn get originDatasetId => text()();
  TextColumn get entityType => text()();
  TextColumn get originEntityId => text()();
  TextColumn get originHash => text()();
  TextColumn get localEntityId => text()();
  TextColumn get restoreRunId => text().nullable().references(
    RestoreRuns,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get createdAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    originDatasetId,
    entityType,
    originEntityId,
    originHash,
  };

  @override
  String get tableName => 'import_provenance';
}

@DriftDatabase(
  tables: [
    AppMetadata,
    AppSettingsTable,
    Documents,
    DocumentBlocks,
    DocumentRevisions,
    Tasks,
    Reminders,
    NotificationRegistrations,
    PlatformJobs,
    Folders,
    Notes,
    TrashEntries,
    PastEvents,
    PastEventParts,
    PastAnchorLinks,
    SearchRecords,
    BackupTargets,
    BackupEncryptionProfiles,
    BackupRuns,
    RestoreRuns,
    RestoreConflicts,
    ImportProvenance,
  ],
)
class DangguiDatabase extends _$DangguiDatabase {
  DangguiDatabase(super.executor);

  factory DangguiDatabase.open(File file) => DangguiDatabase(
    LazyDatabase(() async {
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(file);
    }),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      // User-authored local-only data favors power-loss durability over the
      // small write-throughput gain of WAL synchronous=NORMAL.
      await customStatement('PRAGMA synchronous = FULL');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA secure_delete = FAST');
      if (details.wasCreated) {
        await _seedNewDatabase();
      }
    },
  );

  Future<void> _createIndexes() async {
    const statements = <String>[
      'CREATE INDEX idx_tasks_status_rank '
          'ON tasks(status, deleted_at_utc, manual_rank, id)',
      'CREATE INDEX idx_tasks_due_date ON tasks(due_local_date, status)',
      'CREATE INDEX idx_blocks_document_rank '
          'ON document_blocks(document_id, parent_block_id, sort_rank, id)',
      'CREATE UNIQUE INDEX idx_revision_document_number '
          'ON document_revisions(document_id, revision)',
      'CREATE INDEX idx_reminders_status_time '
          'ON reminders(status, scheduled_at_utc)',
      'CREATE INDEX idx_platform_jobs_pending '
          'ON platform_jobs(status, next_attempt_at_utc)',
      'CREATE INDEX idx_notes_folder_updated '
          'ON notes(folder_id, deleted_at_utc, updated_at_utc)',
      'CREATE UNIQUE INDEX idx_trash_entity '
          'ON trash_entries(entity_type, entity_id)',
      'CREATE INDEX idx_trash_purge ON trash_entries(purge_after_utc)',
      'CREATE INDEX idx_past_events_date '
          'ON past_events(completion_local_date, append_sequence)',
      'CREATE UNIQUE INDEX idx_past_part_order '
          'ON past_event_parts(event_id, source_order)',
      'CREATE INDEX idx_anchor_block ON past_anchor_links(current_block_id)',
      'CREATE UNIQUE INDEX idx_search_entity '
          'ON search_records(scope, entity_id)',
      'CREATE INDEX idx_import_provenance_local '
          'ON import_provenance(entity_type, local_entity_id)',
      'CREATE INDEX idx_backup_runs_created '
          'ON backup_runs(status, started_at_utc)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _seedNewDatabase() async {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    const uuid = Uuid();
    await transaction(() async {
      await into(appMetadata).insert(
        AppMetadataCompanion.insert(
          id: const Value(1),
          datasetId: uuid.v4(),
          createdAtUtc: now,
        ),
      );
      await into(appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          id: const Value(1),
          localeMode: LocaleMode.system,
          fontMode: FontMode.sans,
          textScalePercent: 100,
          density: DisplayDensity.loose,
          defaultSoundEnabled: true,
          defaultVibrationEnabled: true,
          defaultSnoozeMinutes: 10,
          autoBackupEnabled: true,
          autoBackupHourLocal: const Value(2),
          autoBackupMinuteLocal: const Value(0),
          backupEncryptionEnabled: false,
          helpSeenVersion: 0,
          updatedAtUtc: now,
          rowVersion: 1,
        ),
      );
      await into(documents).insert(
        DocumentsCompanion.insert(
          id: uuid.v4(),
          kind: DocumentKind.past,
          singletonKey: const Value('past.main'),
          semanticHash: _emptySha256,
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
    });
  }

  Future<List<String>> quickCheck() async {
    final rows = await customSelect('PRAGMA quick_check').get();
    return rows.map((row) => row.data.values.first.toString()).toList();
  }

  /// Performs SQLite's full b-tree, index, and uniqueness validation.
  ///
  /// [quickCheck] deliberately omits index/content cross-checks. It remains
  /// suitable for the ordinary no-journal startup fast path, while every
  /// backup, restore, candidate, safety-copy, and recovery decision must use
  /// this full check instead.
  Future<List<String>> integrityCheck() async {
    final rows = await customSelect('PRAGMA integrity_check').get();
    return rows.map((row) => row.data.values.first.toString()).toList();
  }

  Future<List<Map<String, Object?>>> foreignKeyCheck() async {
    final rows = await customSelect('PRAGMA foreign_key_check').get();
    return rows.map((row) => row.data).toList(growable: false);
  }
}
