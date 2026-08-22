import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import 'backup_codec.dart';

/// Result of one atomic merge import.
final class BackupMergeOutcome {
  const BackupMergeOutcome(this.summary);

  final Map<String, Object?> summary;
}

/// Imports portable, user-owned state from a validated backup database.
///
/// The engine deliberately does not import settings or any device-owned state.
/// Every write is made through [target.transaction], existing rows are never
/// updated, and provenance is recorded with the imported content.
final class BackupMergeEngine {
  BackupMergeEngine({
    required this.source,
    required this.target,
    required this.restoreRunId,
    required this.originDatasetId,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  static const _uuid = Uuid();

  final DangguiDatabase source;
  final DangguiDatabase target;
  final String restoreRunId;
  final String originDatasetId;
  final DateTime Function() nowUtc;

  final Map<String, String> _folderIds = <String, String>{};
  final Map<String, String> _taskIds = <String, String>{};
  final Map<String, String> _noteIds = <String, String>{};
  final Map<String, String> _documentIds = <String, String>{};
  final Map<String, String> _blockIds = <String, String>{};
  final Map<String, String> _pastEventIds = <String, String>{};
  final Map<String, String> _pastPartIds = <String, String>{};

  final Map<String, int> _imported = <String, int>{};
  final Map<String, int> _skipped = <String, int>{};
  var _conflicts = 0;
  var _pastBlocksAppended = 0;

  Future<BackupMergeOutcome> run({
    Future<void> Function(Map<String, Object?> summary)? beforeCommit,
  }) async {
    late Map<String, Object?> summary;
    await target.transaction(() async {
      if (await _canUseDisjointBulkImport()) {
        await _importDisjointDatasetInBulk();
      } else {
        await _importFolders();
        await _importTasks();
        await _importNotes();
        await _importPast();
        await _importTrash();
      }
      summary = <String, Object?>{
        'originDatasetId': originDatasetId,
        'imported': Map<String, int>.unmodifiable(_imported),
        'skipped': Map<String, int>.unmodifiable(_skipped),
        'conflicts': _conflicts,
        'pastBlocksAppended': _pastBlocksAppended,
        'settingsPolicy': 'kept-current',
        'revisionHistoryPolicy': 'current-blocks-only',
      };
      await beforeCommit?.call(summary);
    });
    return BackupMergeOutcome(summary);
  }

  /// Large imports whose stable ids and normalized folder names are disjoint
  /// from the local dataset can be appended without per-entity resolution.
  /// Existing local content is allowed and remains untouched. Any collision,
  /// or prior provenance for this source dataset, selects the general resolver
  /// so conflict and idempotency semantics stay authoritative.
  Future<bool> _canUseDisjointBulkImport() async {
    final priorProvenance = await target
        .customSelect(
          'SELECT 1 AS found FROM import_provenance '
          'WHERE origin_dataset_id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(originDatasetId)],
        )
        .getSingleOrNull();
    if (priorProvenance != null) return false;

    const domains = <String, String>{
      'folders': '',
      'tasks': '',
      'notes': '',
      'documents': 'WHERE singleton_key IS NULL',
      'document_blocks': '',
      'reminders': '',
      'past_events': '',
      'past_event_parts': '',
      'past_anchor_links': '',
      'trash_entries': '',
    };
    for (final domain in domains.entries) {
      final sourceIds = await _stringSet(
        source,
        'SELECT id AS value FROM ${domain.key} ${domain.value}',
      );
      if (sourceIds.isEmpty) continue;
      final targetIds = await _stringSet(
        target,
        'SELECT id AS value FROM ${domain.key}',
      );
      if (sourceIds.any(targetIds.contains)) return false;
    }

    final sourceFolderNames = await _stringSet(
      source,
      'SELECT normalized_name AS value FROM folders',
    );
    final targetFolderNames = await _stringSet(
      target,
      'SELECT normalized_name AS value FROM folders',
    );
    if (sourceFolderNames.any(targetFolderNames.contains)) return false;

    final sourceSearchKeys = await _stringSet(
      source,
      "SELECT scope || char(0) || entity_id AS value FROM search_records "
      "WHERE scope IN ('task', 'note')",
    );
    final targetSearchKeys = await _stringSet(
      target,
      "SELECT scope || char(0) || entity_id AS value FROM search_records "
      "WHERE scope IN ('task', 'note')",
    );
    if (sourceSearchKeys.any(targetSearchKeys.contains)) return false;

    final targetDedupeKeys = await _stringSet(
      target,
      'SELECT dedupe_key AS value FROM platform_jobs',
    );
    if (targetDedupeKeys.isNotEmpty) {
      final sourceReminders = await source
          .customSelect('SELECT id, schedule_revision FROM reminders')
          .get();
      for (final row in sourceReminders) {
        final id = row.read<String>('id');
        final revision = row.read<int>('schedule_revision');
        final kind = PlatformJobKind.scheduleReminder.name;
        if (targetDedupeKeys.contains('$kind:$id:$revision')) return false;
      }
    }
    return true;
  }

  Future<void> _importDisjointDatasetInBulk() async {
    final folderRows = await _sourceRows(
      'SELECT * FROM folders ORDER BY sort_rank, id',
    );
    final taskRows = await _sourceRows(
      'SELECT * FROM tasks ORDER BY created_at_utc, id',
    );
    final noteRows = await _sourceRows(
      'SELECT * FROM notes ORDER BY created_at_utc, id',
    );
    final documentRows = await _sourceRows(
      'SELECT * FROM documents ORDER BY kind, id',
    );
    final blockRows = await _sourceRows(
      'SELECT * FROM document_blocks ORDER BY document_id, sort_rank, id',
    );
    final reminderRows = await _sourceRows(
      'SELECT * FROM reminders ORDER BY task_id, id',
    );
    final searchRows = await _sourceRows(
      'SELECT * FROM search_records ORDER BY scope, entity_id',
    );
    final eventRows = await _sourceRows(
      'SELECT * FROM past_events ORDER BY append_sequence, id',
    );
    final partRows = await _sourceRows(
      'SELECT * FROM past_event_parts ORDER BY event_id, source_order, id',
    );
    final anchorRows = await _sourceRows(
      'SELECT * FROM past_anchor_links ORDER BY part_id, id',
    );
    final trashRows = await _sourceRows(
      'SELECT * FROM trash_entries ORDER BY deleted_at_utc, id',
    );

    final sourcePastDocument = documentRows.singleWhere(
      (row) => row['singleton_key'] == 'past.main',
    );
    final sourcePastId = sourcePastDocument.string('id');
    final targetPastDocument =
        (await target
                .customSelect(
                  "SELECT * FROM documents WHERE singleton_key = 'past.main' LIMIT 1",
                )
                .getSingle())
            .data;
    final targetPastId = targetPastDocument.string('id');
    _documentIds[sourcePastId] = targetPastId;

    final blocksByDocument = <String, List<Map<String, Object?>>>{};
    for (final block in blockRows) {
      blocksByDocument
          .putIfAbsent(
            block.string('document_id'),
            () => <Map<String, Object?>>[],
          )
          .add(block);
    }
    final documentsById = <String, Map<String, Object?>>{
      for (final document in documentRows) document.string('id'): document,
    };
    final taskById = <String, Map<String, Object?>>{
      for (final task in taskRows) task.string('id'): task,
    };
    final searchByEntity = <String, Map<String, Object?>>{
      for (final row in searchRows)
        '${row.string('scope')}\u0000${row.string('entity_id')}': row,
    };
    final provenance = <_PendingProvenance>[];
    final ownerByDocument = <String, _OwnedDocumentContext>{};

    for (final folder in folderRows) {
      final id = folder.string('id');
      _folderIds[id] = id;
      provenance.add(
        _PendingProvenance(
          entityType: 'folder',
          incomingId: id,
          incomingHash: await _hashText(
            jsonEncode(<Object?>[
              folder.string('normalized_name'),
              folder.string('name'),
            ]),
          ),
          localId: id,
        ),
      );
    }
    for (final task in taskRows) {
      final id = task.string('id');
      final documentId = task.string('document_id');
      final hash = task.string('semantic_hash');
      _taskIds[id] = id;
      _documentIds[documentId] = documentId;
      ownerByDocument[documentId] = _OwnedDocumentContext(
        ownerType: 'task',
        ownerId: id,
        ownerHash: hash,
      );
      provenance.add(
        _PendingProvenance(
          entityType: 'task',
          incomingId: id,
          incomingHash: hash,
          localId: id,
        ),
      );
    }
    for (final note in noteRows) {
      final id = note.string('id');
      final documentId = note.string('document_id');
      final hash = note.string('semantic_hash');
      _noteIds[id] = id;
      _documentIds[documentId] = documentId;
      ownerByDocument[documentId] = _OwnedDocumentContext(
        ownerType: 'note',
        ownerId: id,
        ownerHash: hash,
      );
      provenance.add(
        _PendingProvenance(
          entityType: 'note',
          incomingId: id,
          incomingHash: hash,
          localId: id,
        ),
      );
    }

    for (final entry in ownerByDocument.entries) {
      final document = documentsById[entry.key];
      if (document == null) {
        throw FormatException('Backup is missing documents/${entry.key}.');
      }
      final owner = entry.value;
      provenance.add(
        _PendingProvenance(
          entityType: '${owner.ownerType}_document',
          incomingId: entry.key,
          incomingHash: await _hashText(
            '${owner.ownerType}|${owner.ownerId}|${owner.ownerHash}|'
            '${document.string('semantic_hash')}',
          ),
          localId: entry.key,
        ),
      );
      for (final block
          in blocksByDocument[entry.key] ?? const <Map<String, Object?>>[]) {
        final blockId = block.string('id');
        _blockIds[blockId] = blockId;
        provenance.add(
          _PendingProvenance(
            entityType: '${owner.ownerType}_block',
            incomingId: blockId,
            incomingHash: await _hashText(
              '${owner.ownerHash}|${block.string('semantic_hash')}',
            ),
            localId: blockId,
          ),
        );
      }
    }

    final pastBlocks =
        blocksByDocument[sourcePastId] ?? const <Map<String, Object?>>[];
    for (final block in pastBlocks) {
      final id = block.string('id');
      _blockIds[id] = id;
      provenance.add(
        _PendingProvenance(
          entityType: 'past_block',
          incomingId: id,
          incomingHash: block.string('semantic_hash'),
          localId: id,
        ),
      );
    }
    for (final event in eventRows) {
      final id = event.string('id');
      _pastEventIds[id] = id;
      provenance.add(
        _PendingProvenance(
          entityType: 'past_event',
          incomingId: id,
          incomingHash: event.string('source_sha256'),
          localId: id,
        ),
      );
    }
    for (final part in partRows) {
      final id = part.string('id');
      _pastPartIds[id] = id;
      provenance.add(
        _PendingProvenance(
          entityType: 'past_part',
          incomingId: id,
          incomingHash: part.string('original_sha256'),
          localId: id,
        ),
      );
    }
    for (final anchor in anchorRows) {
      final id = anchor.string('id');
      final hash = await _rowHash(anchor);
      provenance.add(
        _PendingProvenance(
          entityType: 'past_anchor',
          incomingId: id,
          incomingHash: hash,
          localId: id,
        ),
      );
    }

    final reminderHashes = <String, String>{};
    for (final reminder in reminderRows) {
      final task = taskById[reminder.string('task_id')];
      if (task == null) continue;
      final id = reminder.string('id');
      final hash = await _rowHash(reminder, salt: task.string('semantic_hash'));
      reminderHashes[id] = hash;
      provenance.add(
        _PendingProvenance(
          entityType: 'reminder',
          incomingId: id,
          incomingHash: hash,
          localId: id,
        ),
      );
    }
    for (final trash in trashRows) {
      final type = trash.string('entity_type');
      final incomingEntityId = trash.string('entity_id');
      if (type == TrashEntityType.task.name
          ? !_taskIds.containsKey(incomingEntityId)
          : !_noteIds.containsKey(incomingEntityId)) {
        continue;
      }
      provenance.add(
        _PendingProvenance(
          entityType: 'trash_entry',
          incomingId: trash.string('id'),
          incomingHash: trash.string('snapshot_sha256'),
          localId: trash.string('id'),
        ),
      );
    }

    final importedAt = nowUtc();
    final now = importedAt.microsecondsSinceEpoch;
    final datasetLabel = originDatasetId.length <= 8
        ? originDatasetId
        : originDatasetId.substring(0, 8);
    final separator =
        '── 导入于 ${importedAt.toLocal().toIso8601String().substring(0, 16)} '
        '· 来源 $datasetLabel ──';
    final separatorId = _uuid.v4();
    final separatorHash = await _hashText(separator);
    var nextPastRank =
        (await target
                .customSelect(
                  'SELECT COALESCE(MAX(sort_rank), 0) AS value '
                  'FROM document_blocks WHERE document_id = ?',
                  variables: <Variable<Object>>[
                    Variable.withString(targetPastId),
                  ],
                )
                .getSingle())
            .read<int>('value');
    var nextEventSequence =
        (await target
                .customSelect(
                  'SELECT COALESCE(MAX(append_sequence), 0) AS value '
                  'FROM past_events',
                )
                .getSingle())
            .read<int>('value');
    var importedReminders = 0;
    var importedJobs = 0;
    var importedTrash = 0;

    await target.batch((batch) {
      for (final folder in folderRows) {
        _batchInsertRow(batch, 'folders', _folderColumns, folder);
      }
      for (final entry in ownerByDocument.entries) {
        final document = documentsById[entry.key]!;
        _batchInsertRow(
          batch,
          'documents',
          _documentColumns,
          document,
          overrides: <String, Object?>{'singleton_key': null, 'revision': 0},
        );
        for (final block
            in blocksByDocument[entry.key] ?? const <Map<String, Object?>>[]) {
          _batchInsertRow(
            batch,
            'document_blocks',
            _documentBlockColumns,
            block,
            overrides: const <String, Object?>{'parent_block_id': null},
          );
        }
      }
      for (final task in taskRows) {
        _batchInsertRow(batch, 'tasks', _taskColumns, task);
        final search =
            searchByEntity['${SearchScope.task.name}\u0000${task.string('id')}'];
        if (search != null) _batchInsertSearch(batch, search);
      }
      for (final note in noteRows) {
        _batchInsertRow(batch, 'notes', _noteColumns, note);
        final search =
            searchByEntity['${SearchScope.note.name}\u0000${note.string('id')}'];
        if (search != null) _batchInsertSearch(batch, search);
      }
      for (final reminder in reminderRows) {
        final task = taskById[reminder.string('task_id')];
        if (task == null ||
            !reminderHashes.containsKey(reminder.string('id'))) {
          continue;
        }
        final scheduledAt = reminder.integer('scheduled_at_utc');
        final expired = scheduledAt <= now;
        final sourceStatus = reminder.string('status');
        _batchInsertRow(
          batch,
          'reminders',
          _reminderColumns,
          reminder,
          overrides: <String, Object?>{
            'status': expired ? ReminderStatus.expired.name : sourceStatus,
            'pause_reason': expired ? null : reminder['pause_reason'],
            'updated_at_utc': now,
          },
        );
        importedReminders++;
        if (!expired &&
            sourceStatus == ReminderStatus.scheduled.name &&
            task.string('status') == TaskStatus.active.name) {
          final reminderId = reminder.string('id');
          final revision = reminder.integer('schedule_revision');
          final kind = PlatformJobKind.scheduleReminder.name;
          batch.customStatement(
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
              jsonEncode(<String, Object?>{'taskId': task.string('id')}),
              PlatformJobStatus.pending.name,
              now,
              now,
              now,
            ],
          );
          importedJobs++;
        }
      }
      if (pastBlocks.isNotEmpty) {
        nextPastRank += 1000;
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, NULL, ?, ?, ?, 1)',
          <Object?>[
            separatorId,
            targetPastId,
            nextPastRank,
            DocumentBlockType.paragraph.name,
            separator,
            '{}',
            jsonEncode(<String, Object?>{'role': 'import-separator'}),
            separatorHash,
            now,
            now,
          ],
        );
        for (final block in pastBlocks) {
          nextPastRank += 1000;
          _batchInsertRow(
            batch,
            'document_blocks',
            _documentBlockColumns,
            block,
            overrides: <String, Object?>{
              'document_id': targetPastId,
              'parent_block_id': null,
              'sort_rank': nextPastRank,
            },
          );
        }
      }
      for (final event in eventRows) {
        nextEventSequence++;
        _batchInsertRow(
          batch,
          'past_events',
          _pastEventColumns,
          event,
          overrides: <String, Object?>{
            'document_id': targetPastId,
            'append_sequence': nextEventSequence,
          },
        );
      }
      for (final part in partRows) {
        _batchInsertRow(batch, 'past_event_parts', _pastPartColumns, part);
      }
      for (final anchor in anchorRows) {
        final currentIncoming = anchor['current_block_id'] as String?;
        final knownIncoming = anchor.string('last_known_block_id');
        final currentLocal =
            currentIncoming != null && _blockIds.containsKey(currentIncoming)
            ? currentIncoming
            : null;
        _batchInsertRow(
          batch,
          'past_anchor_links',
          _pastAnchorColumns,
          anchor,
          overrides: <String, Object?>{
            'current_block_id': currentLocal,
            'last_known_block_id': knownIncoming,
            if (currentIncoming != null && currentLocal == null)
              'link_state': AnchorLinkState.orphaned.name,
          },
        );
      }
      for (final trash in trashRows) {
        final type = trash.string('entity_type');
        final entityId = trash.string('entity_id');
        if (type == TrashEntityType.task.name
            ? !_taskIds.containsKey(entityId)
            : !_noteIds.containsKey(entityId)) {
          continue;
        }
        _batchInsertRow(
          batch,
          'trash_entries',
          _trashColumns,
          trash,
          overrides: <String, Object?>{
            'restore_context_json': _remapJsonIds(
              trash.string('restore_context_json'),
            ),
          },
        );
        importedTrash++;
      }
      for (final entry in ownerByDocument.entries) {
        final sameDocumentIds = <String>{
          for (final block
              in blocksByDocument[entry.key] ?? const <Map<String, Object?>>[])
            block.string('id'),
        };
        for (final block
            in blocksByDocument[entry.key] ?? const <Map<String, Object?>>[]) {
          final parent = block['parent_block_id'] as String?;
          if (parent != null && sameDocumentIds.contains(parent)) {
            batch.customStatement(
              'UPDATE document_blocks SET parent_block_id = ? WHERE id = ?',
              <Object?>[parent, block.string('id')],
            );
          }
        }
      }
      final pastBlockIds = pastBlocks
          .map((block) => block.string('id'))
          .toSet();
      for (final block in pastBlocks) {
        final parent = block['parent_block_id'] as String?;
        if (parent != null && pastBlockIds.contains(parent)) {
          batch.customStatement(
            'UPDATE document_blocks SET parent_block_id = ? WHERE id = ?',
            <Object?>[parent, block.string('id')],
          );
        }
      }
      for (final record in provenance) {
        _batchRecordProvenance(batch, record, now);
      }
    });

    if (folderRows.isNotEmpty) _imported['folders'] = folderRows.length;
    if (taskRows.isNotEmpty) _imported['tasks'] = taskRows.length;
    if (noteRows.isNotEmpty) _imported['notes'] = noteRows.length;
    if (importedReminders > 0) _imported['reminders'] = importedReminders;
    if (importedJobs > 0) _imported['platformJobs'] = importedJobs;
    if (pastBlocks.isNotEmpty) _imported['pastBlocks'] = pastBlocks.length;
    if (eventRows.isNotEmpty) _imported['pastEvents'] = eventRows.length;
    if (partRows.isNotEmpty) _imported['pastParts'] = partRows.length;
    if (anchorRows.isNotEmpty) _imported['pastAnchors'] = anchorRows.length;
    if (importedTrash > 0) _imported['trashEntries'] = importedTrash;
    _pastBlocksAppended = pastBlocks.length;
    if (pastBlocks.isNotEmpty) {
      await _refreshPastDocument(targetPastId, targetPastDocument);
      await _refreshPastSearch(targetPastId);
    }
  }

  Future<void> _importFolders() async {
    final rows = await source
        .customSelect('SELECT * FROM folders ORDER BY sort_rank, id')
        .get();
    for (final queryRow in rows) {
      final row = queryRow.data;
      final incomingId = row.string('id');
      final normalized = row.string('normalized_name');
      final hash = await _hashText(
        jsonEncode(<Object?>[normalized, row.string('name')]),
      );
      final prior = await _provenance('folder', incomingId, hash);
      if (prior != null && await _exists('folders', prior)) {
        _folderIds[incomingId] = prior;
        _count(_skipped, 'folders');
        continue;
      }
      final sameName = await target
          .customSelect(
            'SELECT id FROM folders WHERE normalized_name = ? LIMIT 1',
            variables: <Variable<Object>>[Variable.withString(normalized)],
          )
          .getSingleOrNull();
      if (sameName != null) {
        final localId = sameName.read<String>('id');
        _folderIds[incomingId] = localId;
        await _recordProvenance('folder', incomingId, hash, localId);
        if (localId != incomingId) {
          await _recordConflict(
            entityType: 'folder',
            incomingId: incomingId,
            resolvedLocalId: localId,
            incomingHash: hash,
            resolution: 'reused_normalized_name',
          );
        }
        _count(_skipped, 'folders');
        continue;
      }
      final localId = await _allocateId(
        table: 'folders',
        entityType: 'folder',
        incomingId: incomingId,
        incomingHash: hash,
      );
      await _insertRow(
        'folders',
        const <String>[
          'id',
          'name',
          'normalized_name',
          'sort_rank',
          'created_at_utc',
          'updated_at_utc',
          'row_version',
        ],
        row,
        overrides: <String, Object?>{'id': localId},
      );
      _folderIds[incomingId] = localId;
      await _recordProvenance('folder', incomingId, hash, localId);
      _count(_imported, 'folders');
    }
  }

  Future<void> _importTasks() async {
    final rows = await source
        .customSelect('SELECT * FROM tasks ORDER BY created_at_utc, id')
        .get();
    for (final queryRow in rows) {
      final row = queryRow.data;
      final incomingId = row.string('id');
      final aggregateHash = row.string('semantic_hash');
      final resolution = await _resolveAggregate(
        table: 'tasks',
        entityType: 'task',
        incomingId: incomingId,
        incomingHash: aggregateHash,
        hashColumn: 'semantic_hash',
      );
      _taskIds[incomingId] = resolution.localId;
      if (resolution.skip) {
        // Reminder intent is versioned independently from the task body. A
        // same-hash task may legitimately gain a reminder in a later backup.
        await _importReminder(
          incomingTaskId: incomingId,
          localTaskId: resolution.localId,
          taskHash: aggregateHash,
          taskStatus: row.string('status'),
        );
        _count(_skipped, 'tasks');
        continue;
      }

      final incomingDocumentId = row.string('document_id');
      final document = await _sourceRow('documents', incomingDocumentId);
      final localDocumentId = await _importOwnedDocument(
        document,
        ownerType: 'task',
        ownerOriginId: incomingId,
        ownerHash: aggregateHash,
      );
      await _insertRow(
        'tasks',
        const <String>[
          'id',
          'document_id',
          'title',
          'due_local_date',
          'plan_text',
          'status',
          'manual_rank',
          'closed_at_utc',
          'closed_local_date',
          'closed_local_time',
          'closed_zone_id',
          'archived_at_utc',
          'deleted_at_utc',
          'semantic_hash',
          'created_at_utc',
          'updated_at_utc',
          'row_version',
        ],
        row,
        overrides: <String, Object?>{
          'id': resolution.localId,
          'document_id': localDocumentId,
        },
      );
      await _recordProvenance(
        'task',
        incomingId,
        aggregateHash,
        resolution.localId,
      );
      await _importSearchProjection(
        scope: SearchScope.task.name,
        incomingEntityId: incomingId,
        localEntityId: resolution.localId,
        localDocumentId: localDocumentId,
      );
      await _importReminder(
        incomingTaskId: incomingId,
        localTaskId: resolution.localId,
        taskHash: aggregateHash,
        taskStatus: row.string('status'),
      );
      _count(_imported, 'tasks');
    }
  }

  Future<void> _importNotes() async {
    final rows = await source
        .customSelect('SELECT * FROM notes ORDER BY created_at_utc, id')
        .get();
    for (final queryRow in rows) {
      final row = queryRow.data;
      final incomingId = row.string('id');
      final aggregateHash = row.string('semantic_hash');
      final resolution = await _resolveAggregate(
        table: 'notes',
        entityType: 'note',
        incomingId: incomingId,
        incomingHash: aggregateHash,
        hashColumn: 'semantic_hash',
      );
      _noteIds[incomingId] = resolution.localId;
      if (resolution.skip) {
        _count(_skipped, 'notes');
        continue;
      }

      final incomingDocumentId = row.string('document_id');
      final document = await _sourceRow('documents', incomingDocumentId);
      final localDocumentId = await _importOwnedDocument(
        document,
        ownerType: 'note',
        ownerOriginId: incomingId,
        ownerHash: aggregateHash,
      );
      final sourceFolderId = row['folder_id'] as String?;
      final localFolderId = sourceFolderId == null
          ? null
          : await _mappedEntity(
              entityType: 'folder',
              incomingId: sourceFolderId,
              inRun: _folderIds,
            );
      await _insertRow(
        'notes',
        const <String>[
          'id',
          'document_id',
          'folder_id',
          'title',
          'pinned_at_utc',
          'deleted_at_utc',
          'semantic_hash',
          'created_at_utc',
          'updated_at_utc',
          'row_version',
        ],
        row,
        overrides: <String, Object?>{
          'id': resolution.localId,
          'document_id': localDocumentId,
          'folder_id': localFolderId,
        },
      );
      await _recordProvenance(
        'note',
        incomingId,
        aggregateHash,
        resolution.localId,
      );
      await _importSearchProjection(
        scope: SearchScope.note.name,
        incomingEntityId: incomingId,
        localEntityId: resolution.localId,
        localDocumentId: localDocumentId,
      );
      _count(_imported, 'notes');
    }
  }

  Future<String> _importOwnedDocument(
    Map<String, Object?> document, {
    required String ownerType,
    required String ownerOriginId,
    required String ownerHash,
  }) async {
    final incomingId = document.string('id');
    final contextualHash = await _hashText(
      '$ownerType|$ownerOriginId|$ownerHash|${document.string('semantic_hash')}',
    );
    final localId = await _allocateId(
      table: 'documents',
      entityType: '${ownerType}_document',
      incomingId: incomingId,
      incomingHash: contextualHash,
    );
    await _insertRow(
      'documents',
      const <String>[
        'id',
        'kind',
        'singleton_key',
        'format_version',
        'revision',
        'semantic_hash',
        'created_at_utc',
        'updated_at_utc',
        'row_version',
      ],
      document,
      overrides: <String, Object?>{
        'id': localId,
        'singleton_key': null,
        // Merge carries the current durable content, not device-local undo
        // history. Starting at revision zero prevents a dangling revision
        // counter from claiming snapshots that were not imported.
        'revision': 0,
      },
    );
    _documentIds[incomingId] = localId;

    final blocks = await source
        .customSelect(
          'SELECT * FROM document_blocks WHERE document_id = ? '
          'ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(incomingId)],
        )
        .get();
    final localByIncoming = <String, String>{};
    for (final queryRow in blocks) {
      final block = queryRow.data;
      final blockId = block.string('id');
      final blockHash = await _hashText(
        '$ownerHash|${block.string('semantic_hash')}',
      );
      final localBlockId = await _allocateId(
        table: 'document_blocks',
        entityType: '${ownerType}_block',
        incomingId: blockId,
        incomingHash: blockHash,
      );
      localByIncoming[blockId] = localBlockId;
      _blockIds[blockId] = localBlockId;
      await _insertRow(
        'document_blocks',
        _documentBlockColumns,
        block,
        overrides: <String, Object?>{
          'id': localBlockId,
          'document_id': localId,
          'parent_block_id': null,
        },
      );
      await _recordProvenance(
        '${ownerType}_block',
        blockId,
        blockHash,
        localBlockId,
      );
    }
    for (final queryRow in blocks) {
      final block = queryRow.data;
      final parent = block['parent_block_id'] as String?;
      if (parent != null && localByIncoming[parent] != null) {
        await target.customStatement(
          'UPDATE document_blocks SET parent_block_id = ? WHERE id = ?',
          <Object?>[
            localByIncoming[parent],
            localByIncoming[block.string('id')],
          ],
        );
      }
    }
    await _recordProvenance(
      '${ownerType}_document',
      incomingId,
      contextualHash,
      localId,
    );
    return localId;
  }

  Future<void> _importReminder({
    required String incomingTaskId,
    required String localTaskId,
    required String taskHash,
    required String taskStatus,
  }) async {
    final queryRow = await source
        .customSelect(
          'SELECT * FROM reminders WHERE task_id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(incomingTaskId)],
        )
        .getSingleOrNull();
    if (queryRow == null) return;
    final row = queryRow.data;
    final incomingId = row.string('id');
    final reminderHash = await _rowHash(row, salt: taskHash);
    final prior = await _provenance('reminder', incomingId, reminderHash);
    if (prior != null && await _exists('reminders', prior)) {
      _count(_skipped, 'reminders');
      return;
    }
    final reminderForTask = await target
        .customSelect(
          'SELECT id FROM reminders WHERE task_id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(localTaskId)],
        )
        .getSingleOrNull();
    if (reminderForTask != null) {
      final keptId = reminderForTask.read<String>('id');
      await _recordConflict(
        entityType: 'reminder',
        incomingId: incomingId,
        resolvedLocalId: keptId,
        incomingHash: reminderHash,
        resolution: 'kept_current_for_reused_task',
      );
      await _recordProvenance('reminder', incomingId, reminderHash, keptId);
      _count(_skipped, 'reminders');
      return;
    }
    final localId = await _allocateId(
      table: 'reminders',
      entityType: 'reminder',
      incomingId: incomingId,
      incomingHash: reminderHash,
    );
    final now = nowUtc().microsecondsSinceEpoch;
    final scheduledAt = row.integer('scheduled_at_utc');
    final expired = scheduledAt <= now;
    final sourceStatus = row.string('status');
    final status = expired ? ReminderStatus.expired.name : sourceStatus;
    await _insertRow(
      'reminders',
      const <String>[
        'id',
        'task_id',
        'scheduled_local_date_time',
        'scheduled_zone_id',
        'scheduled_at_utc',
        'snoozed_until_utc',
        'sound_enabled',
        'vibration_enabled',
        'status',
        'pause_reason',
        'snooze_count',
        'schedule_revision',
        'last_fired_at_utc',
        'created_at_utc',
        'updated_at_utc',
        'row_version',
      ],
      row,
      overrides: <String, Object?>{
        'id': localId,
        'task_id': localTaskId,
        'status': status,
        'pause_reason': expired ? null : row['pause_reason'],
        'updated_at_utc': now,
      },
    );
    await _recordProvenance('reminder', incomingId, reminderHash, localId);
    if (!expired &&
        sourceStatus == ReminderStatus.scheduled.name &&
        taskStatus == TaskStatus.active.name) {
      final revision = row.integer('schedule_revision');
      final kind = PlatformJobKind.scheduleReminder.name;
      await target.customStatement(
        'INSERT INTO platform_jobs '
        '(id, kind, aggregate_id, aggregate_revision, dedupe_key, '
        'payload_json, status, attempts, next_attempt_at_utc, '
        'last_error_code, created_at_utc, updated_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, NULL, ?, ?)',
        <Object?>[
          _uuid.v4(),
          kind,
          localId,
          revision,
          '$kind:$localId:$revision',
          jsonEncode(<String, Object?>{'taskId': localTaskId}),
          PlatformJobStatus.pending.name,
          now,
          now,
          now,
        ],
      );
      _count(_imported, 'platformJobs');
    }
    _count(_imported, 'reminders');
  }

  Future<void> _importPast() async {
    final sourceDocumentQuery = await source
        .customSelect(
          "SELECT * FROM documents WHERE singleton_key = 'past.main' LIMIT 1",
        )
        .getSingle();
    final sourceDocument = sourceDocumentQuery.data;
    final sourceDocumentId = sourceDocument.string('id');
    final targetDocumentQuery = await target
        .customSelect(
          "SELECT * FROM documents WHERE singleton_key = 'past.main' LIMIT 1",
        )
        .getSingle();
    final targetDocument = targetDocumentQuery.data;
    final targetDocumentId = targetDocument.string('id');
    _documentIds[sourceDocumentId] = targetDocumentId;

    var nextRank =
        (await target
                .customSelect(
                  'SELECT COALESCE(MAX(sort_rank), 0) AS rank '
                  'FROM document_blocks WHERE document_id = ?',
                  variables: <Variable<Object>>[
                    Variable.withString(targetDocumentId),
                  ],
                )
                .getSingle())
            .read<int>('rank');
    final sourceBlocks = await source
        .customSelect(
          'SELECT * FROM document_blocks WHERE document_id = ? '
          'ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(sourceDocumentId)],
        )
        .get();
    final pending = <Map<String, Object?>>[];
    for (final queryRow in sourceBlocks) {
      final row = queryRow.data;
      final incomingId = row.string('id');
      final hash = row.string('semantic_hash');
      final prior = await _provenance('past_block', incomingId, hash);
      if (prior != null &&
          await _blockBelongsToDocument(prior, targetDocumentId)) {
        _blockIds[incomingId] = prior;
        _count(_skipped, 'pastBlocks');
        continue;
      }
      final identicalLocal = await target
          .customSelect(
            'SELECT id FROM document_blocks WHERE id = ? AND document_id = ? '
            'AND semantic_hash = ? LIMIT 1',
            variables: <Variable<Object>>[
              Variable.withString(incomingId),
              Variable.withString(targetDocumentId),
              Variable.withString(hash),
            ],
          )
          .getSingleOrNull();
      if (identicalLocal != null) {
        _blockIds[incomingId] = incomingId;
        await _recordProvenance('past_block', incomingId, hash, incomingId);
        _count(_skipped, 'pastBlocks');
        continue;
      }
      final localId = await _allocateId(
        table: 'document_blocks',
        entityType: 'past_block',
        incomingId: incomingId,
        incomingHash: hash,
      );
      _blockIds[incomingId] = localId;
      pending.add(row);
    }
    if (pending.isNotEmpty) {
      final importedAt = nowUtc();
      final datasetLabel = originDatasetId.length <= 8
          ? originDatasetId
          : originDatasetId.substring(0, 8);
      final separator =
          '── 导入于 ${importedAt.toLocal().toIso8601String().substring(0, 16)} '
          '· 来源 $datasetLabel ──';
      nextRank += 1000;
      final separatorId = _uuid.v4();
      final separatorHash = await _hashText(separator);
      final now = importedAt.microsecondsSinceEpoch;
      await target.customStatement(
        'INSERT INTO document_blocks '
        '(id, document_id, parent_block_id, sort_rank, block_type, '
        'plain_text, payload_json, attributes_json, is_checked, '
        'semantic_hash, created_at_utc, updated_at_utc, row_version) '
        'VALUES (?, ?, NULL, ?, ?, ?, ?, ?, NULL, ?, ?, ?, 1)',
        <Object?>[
          separatorId,
          targetDocumentId,
          nextRank,
          DocumentBlockType.paragraph.name,
          separator,
          '{}',
          jsonEncode(<String, Object?>{'role': 'import-separator'}),
          separatorHash,
          now,
          now,
        ],
      );
      for (final row in pending) {
        nextRank += 1000;
        final incomingId = row.string('id');
        final localId = _blockIds[incomingId]!;
        await _insertRow(
          'document_blocks',
          _documentBlockColumns,
          row,
          overrides: <String, Object?>{
            'id': localId,
            'document_id': targetDocumentId,
            'parent_block_id': null,
            'sort_rank': nextRank,
          },
        );
        await _recordProvenance(
          'past_block',
          incomingId,
          row.string('semantic_hash'),
          localId,
        );
        _count(_imported, 'pastBlocks');
        _pastBlocksAppended++;
      }
      for (final row in pending) {
        final parent = row['parent_block_id'] as String?;
        final mappedParent = parent == null
            ? null
            : await _mappedPastBlock(parent);
        if (mappedParent != null) {
          await target.customStatement(
            'UPDATE document_blocks SET parent_block_id = ? WHERE id = ?',
            <Object?>[mappedParent, _blockIds[row.string('id')]],
          );
        }
      }
      await _refreshPastDocument(targetDocumentId, targetDocument);
    }
    await _importPastEvents(sourceDocumentId, targetDocumentId);
    if (pending.isNotEmpty) await _refreshPastSearch(targetDocumentId);
  }

  Future<void> _importPastEvents(
    String sourceDocumentId,
    String targetDocumentId,
  ) async {
    var nextSequence =
        (await target
                .customSelect(
                  'SELECT COALESCE(MAX(append_sequence), 0) AS sequence '
                  'FROM past_events',
                )
                .getSingle())
            .read<int>('sequence');
    final events = await source
        .customSelect(
          'SELECT * FROM past_events WHERE document_id = ? '
          'ORDER BY append_sequence, id',
          variables: <Variable<Object>>[Variable.withString(sourceDocumentId)],
        )
        .get();
    for (final queryRow in events) {
      final event = queryRow.data;
      final incomingId = event.string('id');
      final hash = event.string('source_sha256');
      final resolution = await _resolveAggregate(
        table: 'past_events',
        entityType: 'past_event',
        incomingId: incomingId,
        incomingHash: hash,
        hashColumn: 'source_sha256',
      );
      _pastEventIds[incomingId] = resolution.localId;
      if (resolution.skip) {
        _count(_skipped, 'pastEvents');
        continue;
      }
      nextSequence++;
      final sourceTaskId = event.string('source_task_id');
      final mappedTaskId = await _mappedEntity(
        entityType: 'task',
        incomingId: sourceTaskId,
        inRun: _taskIds,
      );
      await _insertRow(
        'past_events',
        const <String>[
          'id',
          'document_id',
          'source_task_id',
          'append_sequence',
          'completed_at_utc',
          'completion_local_date',
          'completion_zone_id',
          'source_snapshot_version',
          'source_snapshot_json',
          'source_sha256',
          'anchor_state',
          'created_at_utc',
          'updated_at_utc',
          'row_version',
        ],
        event,
        overrides: <String, Object?>{
          'id': resolution.localId,
          'document_id': targetDocumentId,
          'source_task_id': mappedTaskId ?? sourceTaskId,
          'append_sequence': nextSequence,
        },
      );
      await _importPastParts(incomingId, resolution.localId);
      await _recordProvenance(
        'past_event',
        incomingId,
        hash,
        resolution.localId,
      );
      _count(_imported, 'pastEvents');
    }
  }

  Future<void> _importPastParts(
    String incomingEventId,
    String localEventId,
  ) async {
    final parts = await source
        .customSelect(
          'SELECT * FROM past_event_parts WHERE event_id = ? '
          'ORDER BY source_order, id',
          variables: <Variable<Object>>[Variable.withString(incomingEventId)],
        )
        .get();
    for (final queryRow in parts) {
      final part = queryRow.data;
      final incomingPartId = part.string('id');
      final hash = part.string('original_sha256');
      final localPartId = await _allocateId(
        table: 'past_event_parts',
        entityType: 'past_part',
        incomingId: incomingPartId,
        incomingHash: hash,
      );
      _pastPartIds[incomingPartId] = localPartId;
      await _insertRow(
        'past_event_parts',
        const <String>[
          'id',
          'event_id',
          'role',
          'source_order',
          'original_payload_json',
          'original_plain_text',
          'original_sha256',
        ],
        part,
        overrides: <String, Object?>{
          'id': localPartId,
          'event_id': localEventId,
        },
      );
      await _recordProvenance('past_part', incomingPartId, hash, localPartId);
      final anchors = await source
          .customSelect(
            'SELECT * FROM past_anchor_links WHERE part_id = ? ORDER BY id',
            variables: <Variable<Object>>[Variable.withString(incomingPartId)],
          )
          .get();
      for (final anchorQuery in anchors) {
        final anchor = anchorQuery.data;
        final incomingAnchorId = anchor.string('id');
        final anchorHash = await _rowHash(anchor);
        final localAnchorId = await _allocateId(
          table: 'past_anchor_links',
          entityType: 'past_anchor',
          incomingId: incomingAnchorId,
          incomingHash: anchorHash,
        );
        final currentIncoming = anchor['current_block_id'] as String?;
        final knownIncoming = anchor.string('last_known_block_id');
        final currentLocal = currentIncoming == null
            ? null
            : await _mappedPastBlock(currentIncoming);
        final knownLocal = await _mappedPastBlock(knownIncoming);
        await _insertRow(
          'past_anchor_links',
          const <String>[
            'id',
            'part_id',
            'current_block_id',
            'last_known_block_id',
            'relation',
            'link_state',
            'current_sha256',
            'updated_at_utc',
          ],
          anchor,
          overrides: <String, Object?>{
            'id': localAnchorId,
            'part_id': localPartId,
            'current_block_id': currentLocal,
            'last_known_block_id': knownLocal ?? knownIncoming,
            if (currentIncoming != null && currentLocal == null)
              'link_state': AnchorLinkState.orphaned.name,
          },
        );
        await _recordProvenance(
          'past_anchor',
          incomingAnchorId,
          anchorHash,
          localAnchorId,
        );
        _count(_imported, 'pastAnchors');
      }
      _count(_imported, 'pastParts');
    }
  }

  Future<void> _importTrash() async {
    final rows = await source
        .customSelect('SELECT * FROM trash_entries ORDER BY deleted_at_utc, id')
        .get();
    for (final queryRow in rows) {
      final row = queryRow.data;
      final type = row.string('entity_type');
      final incomingEntityId = row.string('entity_id');
      final localEntityId = type == TrashEntityType.task.name
          ? await _mappedEntity(
              entityType: 'task',
              incomingId: incomingEntityId,
              inRun: _taskIds,
            )
          : await _mappedEntity(
              entityType: 'note',
              incomingId: incomingEntityId,
              inRun: _noteIds,
            );
      if (localEntityId == null) {
        _count(_skipped, 'trashEntries');
        continue;
      }
      final incomingId = row.string('id');
      final hash = row.string('snapshot_sha256');
      final prior = await _provenance('trash_entry', incomingId, hash);
      if (prior != null && await _exists('trash_entries', prior)) {
        _count(_skipped, 'trashEntries');
        continue;
      }
      final existing = await target
          .customSelect(
            'SELECT id FROM trash_entries '
            'WHERE entity_type = ? AND entity_id = ? LIMIT 1',
            variables: <Variable<Object>>[
              Variable.withString(type),
              Variable.withString(localEntityId),
            ],
          )
          .getSingleOrNull();
      if (existing != null) {
        final keptId = existing.read<String>('id');
        await _recordConflict(
          entityType: 'trash_entry',
          incomingId: incomingId,
          resolvedLocalId: keptId,
          incomingHash: hash,
          resolution: 'kept_current_for_entity',
        );
        await _recordProvenance('trash_entry', incomingId, hash, keptId);
        _count(_skipped, 'trashEntries');
        continue;
      }
      final localId = await _allocateId(
        table: 'trash_entries',
        entityType: 'trash_entry',
        incomingId: incomingId,
        incomingHash: hash,
      );
      await _insertRow(
        'trash_entries',
        const <String>[
          'id',
          'entity_type',
          'entity_id',
          'deleted_at_utc',
          'purge_after_utc',
          'restore_context_json',
          'snapshot_sha256',
        ],
        row,
        overrides: <String, Object?>{
          'id': localId,
          'entity_id': localEntityId,
          'restore_context_json': _remapJsonIds(
            row.string('restore_context_json'),
          ),
        },
      );
      await _recordProvenance('trash_entry', incomingId, hash, localId);
      _count(_imported, 'trashEntries');
    }
  }

  Future<_Resolution> _resolveAggregate({
    required String table,
    required String entityType,
    required String incomingId,
    required String incomingHash,
    required String hashColumn,
  }) async {
    final prior = await _provenance(entityType, incomingId, incomingHash);
    if (prior != null && await _exists(table, prior)) {
      return _Resolution(prior, skip: true);
    }
    final current = await target
        .customSelect(
          'SELECT $hashColumn AS hash FROM $table WHERE id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(incomingId)],
        )
        .getSingleOrNull();
    if (current == null) return _Resolution(incomingId, skip: false);
    final currentHash = current.read<String>('hash');
    if (currentHash == incomingHash) {
      await _recordProvenance(entityType, incomingId, incomingHash, incomingId);
      return _Resolution(incomingId, skip: true);
    }
    final localId = _uuid.v4();
    await _recordConflict(
      entityType: entityType,
      incomingId: incomingId,
      resolvedLocalId: localId,
      incomingHash: incomingHash,
      currentHash: currentHash,
      resolution: 'imported_with_new_uuid',
    );
    return _Resolution(localId, skip: false);
  }

  Future<String> _allocateId({
    required String table,
    required String entityType,
    required String incomingId,
    required String incomingHash,
  }) async {
    if (!await _exists(table, incomingId)) return incomingId;
    final localId = _uuid.v4();
    await _recordConflict(
      entityType: entityType,
      incomingId: incomingId,
      resolvedLocalId: localId,
      incomingHash: incomingHash,
      resolution: 'imported_with_new_uuid',
    );
    return localId;
  }

  Future<void> _recordConflict({
    required String entityType,
    required String incomingId,
    required String? resolvedLocalId,
    required String? incomingHash,
    String? currentHash,
    required String resolution,
  }) async {
    await target.customStatement(
      'INSERT INTO restore_conflicts '
      '(id, restore_run_id, entity_type, incoming_id, resolved_local_id, '
      'incoming_hash, current_hash, resolution) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        _uuid.v4(),
        restoreRunId,
        entityType,
        incomingId,
        resolvedLocalId,
        incomingHash,
        currentHash,
        resolution,
      ],
    );
    _conflicts++;
  }

  Future<String?> _provenance(
    String entityType,
    String incomingId,
    String incomingHash,
  ) async {
    final row = await target
        .customSelect(
          'SELECT local_entity_id FROM import_provenance '
          'WHERE origin_dataset_id = ? AND entity_type = ? '
          'AND origin_entity_id = ? AND origin_hash = ? LIMIT 1',
          variables: <Variable<Object>>[
            Variable.withString(originDatasetId),
            Variable.withString(entityType),
            Variable.withString(incomingId),
            Variable.withString(incomingHash),
          ],
        )
        .getSingleOrNull();
    return row?.read<String>('local_entity_id');
  }

  Future<void> _recordProvenance(
    String entityType,
    String incomingId,
    String incomingHash,
    String localId,
  ) {
    return target.customStatement(
      'INSERT INTO import_provenance '
      '(origin_dataset_id, entity_type, origin_entity_id, origin_hash, '
      'local_entity_id, restore_run_id, created_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(origin_dataset_id, entity_type, origin_entity_id, '
      'origin_hash) DO UPDATE SET '
      'local_entity_id = excluded.local_entity_id, '
      'restore_run_id = excluded.restore_run_id, '
      'created_at_utc = excluded.created_at_utc',
      <Object?>[
        originDatasetId,
        entityType,
        incomingId,
        incomingHash,
        localId,
        restoreRunId,
        nowUtc().microsecondsSinceEpoch,
      ],
    );
  }

  Future<String?> _mappedEntity({
    required String entityType,
    required String incomingId,
    required Map<String, String> inRun,
  }) async {
    final mapped = inRun[incomingId];
    if (mapped != null) return mapped;
    final row = await target
        .customSelect(
          'SELECT local_entity_id FROM import_provenance '
          'WHERE origin_dataset_id = ? AND entity_type = ? '
          'AND origin_entity_id = ? ORDER BY created_at_utc DESC LIMIT 1',
          variables: <Variable<Object>>[
            Variable.withString(originDatasetId),
            Variable.withString(entityType),
            Variable.withString(incomingId),
          ],
        )
        .getSingleOrNull();
    return row?.read<String>('local_entity_id');
  }

  Future<String?> _mappedPastBlock(String incomingId) => _mappedEntity(
    entityType: 'past_block',
    incomingId: incomingId,
    inRun: _blockIds,
  );

  Future<bool> _exists(String table, String id) async {
    final row = await target
        .customSelect(
          'SELECT 1 AS found FROM $table WHERE id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(id)],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<bool> _blockBelongsToDocument(
    String blockId,
    String documentId,
  ) async {
    final row = await target
        .customSelect(
          'SELECT 1 AS found FROM document_blocks '
          'WHERE id = ? AND document_id = ? LIMIT 1',
          variables: <Variable<Object>>[
            Variable.withString(blockId),
            Variable.withString(documentId),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<Map<String, Object?>> _sourceRow(String table, String id) async {
    final row = await source
        .customSelect(
          'SELECT * FROM $table WHERE id = ? LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw FormatException('Backup is missing $table/$id.');
    }
    return row.data;
  }

  Future<List<Map<String, Object?>>> _sourceRows(String sql) async {
    final rows = await source.customSelect(sql).get();
    return rows.map((row) => row.data).toList(growable: false);
  }

  Future<Set<String>> _stringSet(DangguiDatabase database, String sql) async {
    final rows = await database.customSelect(sql).get();
    return rows.map((row) => row.read<String>('value')).toSet();
  }

  void _batchInsertRow(
    Batch batch,
    String table,
    List<String> columns,
    Map<String, Object?> row, {
    Map<String, Object?> overrides = const <String, Object?>{},
  }) {
    final values = <Object?>[
      for (final column in columns)
        _bind(overrides.containsKey(column) ? overrides[column] : row[column]),
    ];
    batch.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES (${List<String>.filled(columns.length, '?').join(', ')})',
      values,
    );
  }

  void _batchInsertSearch(Batch batch, Map<String, Object?> row) {
    batch.customStatement(
      'INSERT INTO search_records '
      '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
      'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        row['scope'],
        row['entity_id'],
        row['document_id'],
        row['title_norm'],
        row['body_norm'],
        row['date_key'],
        row['updated_at_utc'],
      ],
    );
  }

  void _batchRecordProvenance(Batch batch, _PendingProvenance record, int now) {
    batch.customStatement(
      'INSERT INTO import_provenance '
      '(origin_dataset_id, entity_type, origin_entity_id, origin_hash, '
      'local_entity_id, restore_run_id, created_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(origin_dataset_id, entity_type, origin_entity_id, '
      'origin_hash) DO UPDATE SET '
      'local_entity_id = excluded.local_entity_id, '
      'restore_run_id = excluded.restore_run_id, '
      'created_at_utc = excluded.created_at_utc',
      <Object?>[
        originDatasetId,
        record.entityType,
        record.incomingId,
        record.incomingHash,
        record.localId,
        restoreRunId,
        now,
      ],
    );
  }

  Future<void> _insertRow(
    String table,
    List<String> columns,
    Map<String, Object?> row, {
    Map<String, Object?> overrides = const <String, Object?>{},
  }) {
    final values = <Object?>[
      for (final column in columns)
        _bind(overrides.containsKey(column) ? overrides[column] : row[column]),
    ];
    return target.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES (${List<String>.filled(columns.length, '?').join(', ')})',
      values,
    );
  }

  Future<void> _importSearchProjection({
    required String scope,
    required String incomingEntityId,
    required String localEntityId,
    required String localDocumentId,
  }) async {
    final query = await source
        .customSelect(
          'SELECT * FROM search_records WHERE scope = ? AND entity_id = ? LIMIT 1',
          variables: <Variable<Object>>[
            Variable.withString(scope),
            Variable.withString(incomingEntityId),
          ],
        )
        .getSingleOrNull();
    if (query == null) return;
    final row = query.data;
    await target.customStatement(
      'INSERT INTO search_records '
      '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
      'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        scope,
        localEntityId,
        localDocumentId,
        row['title_norm'],
        row['body_norm'],
        row['date_key'],
        row['updated_at_utc'],
      ],
    );
  }

  Future<void> _refreshPastDocument(
    String documentId,
    Map<String, Object?> previous,
  ) async {
    final blocks = await target
        .customSelect(
          'SELECT id, parent_block_id, sort_rank, block_type, plain_text, '
          'payload_json, attributes_json, is_checked, semantic_hash '
          'FROM document_blocks WHERE document_id = ? ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .get();
    final semanticHash = await _hashText(
      jsonEncode(blocks.map((row) => row.data).toList(growable: false)),
    );
    await target.customStatement(
      'UPDATE documents SET revision = revision + 1, semantic_hash = ?, '
      'updated_at_utc = ?, row_version = row_version + 1 WHERE id = ?',
      <Object?>[semanticHash, nowUtc().microsecondsSinceEpoch, documentId],
    );
  }

  Future<void> _refreshPastSearch(String documentId) async {
    final rows = await target
        .customSelect(
          'SELECT plain_text FROM document_blocks WHERE document_id = ? '
          'ORDER BY sort_rank, id',
          variables: <Variable<Object>>[Variable.withString(documentId)],
        )
        .get();
    final body = rows
        .map((row) => row.read<String>('plain_text'))
        .where((text) => text.isNotEmpty)
        .join('\n')
        .toLowerCase();
    await target.customStatement(
      'INSERT INTO search_records '
      '(scope, entity_id, document_id, title_norm, body_norm, date_key, '
      'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(scope, entity_id) DO UPDATE SET '
      'document_id = excluded.document_id, body_norm = excluded.body_norm, '
      'updated_at_utc = excluded.updated_at_utc',
      <Object?>[
        SearchScope.past.name,
        'past.main',
        documentId,
        '',
        body,
        '',
        nowUtc().microsecondsSinceEpoch,
      ],
    );
  }

  String _remapJsonIds(String input) {
    try {
      final decoded = jsonDecode(input);
      Object? walk(Object? value) {
        if (value is String) {
          return _folderIds[value] ??
              _taskIds[value] ??
              _noteIds[value] ??
              _documentIds[value] ??
              _blockIds[value] ??
              value;
        }
        if (value is List) return value.map(walk).toList(growable: false);
        if (value is Map) {
          return <String, Object?>{
            for (final entry in value.entries)
              entry.key.toString(): walk(entry.value),
          };
        }
        return value;
      }

      return jsonEncode(walk(decoded));
    } on Object {
      // The schema stores opaque restore context. Validation of user entities
      // must not fail just because a future producer used a non-JSON payload.
      return input;
    }
  }

  Future<String> _rowHash(Map<String, Object?> row, {String salt = ''}) {
    final sorted = row.keys.toList()..sort();
    return _hashText(
      jsonEncode(<Object?>[
        salt,
        <String, Object?>{for (final key in sorted) key: row[key]},
      ]),
    );
  }

  static Future<String> _hashText(String value) =>
      sha256OfBytes(utf8.encode(value));

  static Object? _bind(Object? value) {
    if (value is bool) return value ? 1 : 0;
    return value;
  }

  static void _count(Map<String, int> counts, String key) {
    counts[key] = (counts[key] ?? 0) + 1;
  }
}

final class _Resolution {
  const _Resolution(this.localId, {required this.skip});

  final String localId;
  final bool skip;
}

final class _OwnedDocumentContext {
  const _OwnedDocumentContext({
    required this.ownerType,
    required this.ownerId,
    required this.ownerHash,
  });

  final String ownerType;
  final String ownerId;
  final String ownerHash;
}

final class _PendingProvenance {
  const _PendingProvenance({
    required this.entityType,
    required this.incomingId,
    required this.incomingHash,
    required this.localId,
  });

  final String entityType;
  final String incomingId;
  final String incomingHash;
  final String localId;
}

extension on Map<String, Object?> {
  String string(String key) => this[key] as String;

  int integer(String key) => this[key] as int;
}

const _documentBlockColumns = <String>[
  'id',
  'document_id',
  'parent_block_id',
  'sort_rank',
  'block_type',
  'plain_text',
  'payload_json',
  'attributes_json',
  'is_checked',
  'semantic_hash',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _folderColumns = <String>[
  'id',
  'name',
  'normalized_name',
  'sort_rank',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _documentColumns = <String>[
  'id',
  'kind',
  'singleton_key',
  'format_version',
  'revision',
  'semantic_hash',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _taskColumns = <String>[
  'id',
  'document_id',
  'title',
  'due_local_date',
  'plan_text',
  'status',
  'manual_rank',
  'closed_at_utc',
  'closed_local_date',
  'closed_local_time',
  'closed_zone_id',
  'archived_at_utc',
  'deleted_at_utc',
  'semantic_hash',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _noteColumns = <String>[
  'id',
  'document_id',
  'folder_id',
  'title',
  'pinned_at_utc',
  'deleted_at_utc',
  'semantic_hash',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _reminderColumns = <String>[
  'id',
  'task_id',
  'scheduled_local_date_time',
  'scheduled_zone_id',
  'scheduled_at_utc',
  'snoozed_until_utc',
  'sound_enabled',
  'vibration_enabled',
  'status',
  'pause_reason',
  'snooze_count',
  'schedule_revision',
  'last_fired_at_utc',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _pastEventColumns = <String>[
  'id',
  'document_id',
  'source_task_id',
  'append_sequence',
  'completed_at_utc',
  'completion_local_date',
  'completion_zone_id',
  'source_snapshot_version',
  'source_snapshot_json',
  'source_sha256',
  'anchor_state',
  'created_at_utc',
  'updated_at_utc',
  'row_version',
];

const _pastPartColumns = <String>[
  'id',
  'event_id',
  'role',
  'source_order',
  'original_payload_json',
  'original_plain_text',
  'original_sha256',
];

const _pastAnchorColumns = <String>[
  'id',
  'part_id',
  'current_block_id',
  'last_known_block_id',
  'relation',
  'link_state',
  'current_sha256',
  'updated_at_utc',
];

const _trashColumns = <String>[
  'id',
  'entity_type',
  'entity_id',
  'deleted_at_utc',
  'purge_after_utc',
  'restore_context_json',
  'snapshot_sha256',
];
