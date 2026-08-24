import 'dart:convert';
import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/ui/components/components.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const releaseAcceptanceAppId = 'com.danggui.memo';
const releaseAcceptanceContractVersion = 1;
const releaseAcceptanceReminderLead = Duration(minutes: 5);

int releaseAcceptanceApiLevel() {
  const raw = String.fromEnvironment('DANGGUI_ACCEPTANCE_API_LEVEL');
  if (raw.isEmpty) {
    throw StateError('DANGGUI_ACCEPTANCE_API_LEVEL must be provided.');
  }
  final value = int.tryParse(raw);
  if (value == null || value < 24) {
    throw StateError('Invalid DANGGUI_ACCEPTANCE_API_LEVEL: $raw');
  }
  return value;
}

String releaseAcceptanceTitle(int apiLevel) =>
    'Danggui release acceptance API $apiLevel';

String releaseAcceptancePlan(int apiLevel) =>
    'Local reminder retention probe API $apiLevel';

String releaseAcceptanceBody(int apiLevel) =>
    'Same-version signed overlay data sentinel for API $apiLevel.';

String releaseAcceptanceNoteTitle(int apiLevel) =>
    'Danggui retained note API $apiLevel';

String releaseAcceptanceFolderName(int apiLevel) =>
    'Danggui retained folder API $apiLevel';

String releaseAcceptanceNoteBody(int apiLevel) =>
    'Cross-domain note sentinel survives the signed overlay on API $apiLevel.';

String releaseAcceptancePastTitle(int apiLevel) =>
    'Danggui retained Past entry API $apiLevel';

String releaseAcceptancePastBody(int apiLevel) =>
    'Cross-domain Past sentinel survives the signed overlay on API $apiLevel.';

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required String phase,
  Duration timeout = const Duration(seconds: 40),
}) async {
  const interval = Duration(milliseconds: 200);
  final attempts = (timeout.inMicroseconds / interval.inMicroseconds).ceil();
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(interval);
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unhandled Flutter exception during $phase: $exception');
    }
  }
  fail('$phase did not complete within ${timeout.inSeconds} seconds.');
}

ProviderContainer providerContainerFor(WidgetTester tester, Finder finder) {
  return ProviderScope.containerOf(tester.element(finder));
}

Future<File> releaseAcceptanceEvidenceFile(String name) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(
    p.join(support.path, 'danggui', 'release-acceptance'),
  );
  await directory.create(recursive: true);
  return File(p.join(directory.path, name));
}

Future<Map<String, Object?>> readReleaseAcceptanceEvidence(String name) async {
  final file = await releaseAcceptanceEvidenceFile(name);
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException(
      'Release acceptance evidence is not an object.',
    );
  }
  return decoded;
}

Future<void> writeReleaseAcceptanceEvidence(
  String name,
  Map<String, Object?> value,
) async {
  final file = await releaseAcceptanceEvidenceFile(name);
  await file.writeAsString('${jsonEncode(value)}\n', flush: true);
}

Future<Map<String, Object?>> databaseSnapshot(
  DangguiDatabase database, {
  required String taskId,
  required String noteId,
  required String pastTaskId,
  required bool notificationsGranted,
}) async {
  final quickCheck = await database.quickCheck();
  final foreignKeyCheck = await database.foreignKeyCheck();
  final metadata = await database
      .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
      .getSingle();
  final userVersion = await database
      .customSelect('PRAGMA user_version')
      .getSingle();
  final task = await database
      .customSelect(
        'SELECT t.id, t.document_id, t.title, t.due_local_date, t.plan_text, '
        't.status, t.manual_rank, t.semantic_hash, t.created_at_utc, '
        't.updated_at_utc, t.row_version, r.id AS reminder_id, '
        'r.scheduled_local_date_time, r.scheduled_zone_id, '
        'r.scheduled_at_utc, r.sound_enabled, r.vibration_enabled, '
        'r.status AS reminder_status, r.schedule_revision '
        'FROM tasks t JOIN reminders r ON r.task_id = t.id WHERE t.id = ?',
        variables: <Variable<Object>>[Variable.withString(taskId)],
      )
      .getSingle();
  final bodyRows = await database
      .customSelect(
        'SELECT plain_text FROM document_blocks WHERE document_id = ? '
        'ORDER BY sort_rank, id',
        variables: <Variable<Object>>[
          Variable.withString(task.read<String>('document_id')),
        ],
      )
      .get();
  final registration = await database
      .customSelect(
        'SELECT platform, platform_notification_id, schedule_revision, '
        'scheduled_locale, last_error_code FROM notification_registrations '
        'WHERE reminder_id = ?',
        variables: <Variable<Object>>[
          Variable.withString(task.read<String>('reminder_id')),
        ],
      )
      .getSingleOrNull();
  final note = await database
      .customSelect(
        'SELECT id, document_id, folder_id, title, pinned_at_utc, '
        'semantic_hash, created_at_utc, updated_at_utc, row_version '
        'FROM notes WHERE id = ?',
        variables: <Variable<Object>>[Variable.withString(noteId)],
      )
      .getSingle();
  final noteBodyRows = await database
      .customSelect(
        'SELECT block_type, plain_text, is_checked, sort_rank, semantic_hash, '
        'row_version FROM document_blocks WHERE document_id = ? '
        'ORDER BY sort_rank, id',
        variables: <Variable<Object>>[
          Variable.withString(note.read<String>('document_id')),
        ],
      )
      .get();
  final noteFolderId = note.read<String>('folder_id');
  final folder = await database
      .customSelect(
        'SELECT id, name, normalized_name, sort_rank, created_at_utc, '
        'updated_at_utc, row_version FROM folders WHERE id = ?',
        variables: <Variable<Object>>[Variable.withString(noteFolderId)],
      )
      .getSingle();
  final pastEvent = await database
      .customSelect(
        'SELECT id, document_id, source_task_id, append_sequence, '
        'completed_at_utc, completion_local_date, completion_zone_id, '
        'source_snapshot_version, source_snapshot_json, source_sha256, '
        'anchor_state, created_at_utc, updated_at_utc, row_version '
        'FROM past_events WHERE source_task_id = ?',
        variables: <Variable<Object>>[Variable.withString(pastTaskId)],
      )
      .getSingle();
  final pastParts = await database
      .customSelect(
        'SELECT id, role, source_order, original_payload_json, '
        'original_plain_text, original_sha256 FROM past_event_parts '
        'WHERE event_id = ? ORDER BY source_order, id',
        variables: <Variable<Object>>[
          Variable.withString(pastEvent.read<String>('id')),
        ],
      )
      .get();
  final pastAnchors = await database
      .customSelect(
        'SELECT pal.id, pal.part_id, pal.current_block_id, '
        'pal.last_known_block_id, pal.relation, pal.link_state, '
        'pal.current_sha256, db.block_type AS current_block_type, '
        'db.plain_text AS current_plain_text, db.sort_rank AS current_sort_rank '
        'FROM past_anchor_links pal '
        'JOIN past_event_parts pep ON pep.id = pal.part_id '
        'LEFT JOIN document_blocks db ON db.id = pal.current_block_id '
        'WHERE pep.event_id = ? ORDER BY pep.source_order, pal.id',
        variables: <Variable<Object>>[
          Variable.withString(pastEvent.read<String>('id')),
        ],
      )
      .get();
  final pastDocumentBlocks = await database
      .customSelect(
        'SELECT id, block_type, plain_text, is_checked, sort_rank, '
        'semantic_hash, row_version FROM document_blocks '
        'WHERE document_id = ? ORDER BY sort_rank, id',
        variables: <Variable<Object>>[
          Variable.withString(pastEvent.read<String>('document_id')),
        ],
      )
      .get();
  final settings = await database
      .customSelect(
        'SELECT locale_mode, font_mode, text_scale_percent, density, '
        'default_sound_enabled, default_vibration_enabled, '
        'default_snooze_minutes, auto_backup_enabled, '
        'auto_backup_hour_local, auto_backup_minute_local, '
        'backup_encryption_enabled, help_seen_version, updated_at_utc, '
        'row_version FROM app_settings WHERE id = 1',
      )
      .getSingle();
  final counts = <String, int>{};
  for (final table in <String>[
    'tasks',
    'reminders',
    'notification_registrations',
    'platform_jobs',
    'documents',
    'document_blocks',
    'notes',
    'folders',
    'past_events',
    'past_event_parts',
    'past_anchor_links',
    'search_records',
  ]) {
    final row = await database
        .customSelect('SELECT COUNT(*) AS count FROM $table')
        .getSingle();
    counts[table] = row.read<int>('count');
  }
  final pendingJobs = await database
      .customSelect(
        "SELECT COUNT(*) AS count FROM platform_jobs WHERE status <> 'succeeded'",
      )
      .getSingle();

  return <String, Object?>{
    'appId': releaseAcceptanceAppId,
    'databaseSchemaVersion': database.schemaVersion,
    'sqliteUserVersion': userVersion.data.values.first,
    'datasetId': metadata.read<String>('dataset_id'),
    'quickCheck': quickCheck,
    'foreignKeyCheck': foreignKeyCheck,
    'notificationsGranted': notificationsGranted,
    'counts': counts,
    'nonSucceededPlatformJobCount': pendingJobs.read<int>('count'),
    'task': <String, Object?>{
      'id': task.read<String>('id'),
      'documentId': task.read<String>('document_id'),
      'title': task.read<String>('title'),
      'dueLocalDate': task.readNullable<String>('due_local_date'),
      'planText': task.read<String>('plan_text'),
      'bodyText': bodyRows
          .map((row) => row.read<String>('plain_text'))
          .join('\n'),
      'status': task.read<String>('status'),
      'manualRank': task.read<int>('manual_rank'),
      'semanticHash': task.read<String>('semantic_hash'),
      'createdAtUtcMicros': task.read<int>('created_at_utc'),
      'updatedAtUtcMicros': task.read<int>('updated_at_utc'),
      'rowVersion': task.read<int>('row_version'),
      'reminderId': task.read<String>('reminder_id'),
      'reminderScheduledLocalDateTime': task.read<String>(
        'scheduled_local_date_time',
      ),
      'reminderScheduledZoneId': task.read<String>('scheduled_zone_id'),
      'reminderScheduledAtUtcMicros': task.read<int>('scheduled_at_utc'),
      'soundEnabled': task.read<bool>('sound_enabled'),
      'vibrationEnabled': task.read<bool>('vibration_enabled'),
      'reminderStatus': task.read<String>('reminder_status'),
      'reminderScheduleRevision': task.read<int>('schedule_revision'),
    },
    'notificationRegistration': registration == null
        ? null
        : <String, Object?>{
            'platform': registration.read<String>('platform'),
            'platformNotificationId': registration.read<int>(
              'platform_notification_id',
            ),
            'scheduleRevision': registration.read<int>('schedule_revision'),
            'scheduledLocale': registration.read<String>('scheduled_locale'),
            'lastErrorCode': registration.readNullable<String>(
              'last_error_code',
            ),
          },
    'note': <String, Object?>{
      'id': note.read<String>('id'),
      'documentId': note.read<String>('document_id'),
      'folderId': note.readNullable<String>('folder_id'),
      'title': note.read<String>('title'),
      'pinnedAtUtcMicros': note.readNullable<int>('pinned_at_utc'),
      'semanticHash': note.read<String>('semantic_hash'),
      'createdAtUtcMicros': note.read<int>('created_at_utc'),
      'updatedAtUtcMicros': note.read<int>('updated_at_utc'),
      'rowVersion': note.read<int>('row_version'),
      'blocks': noteBodyRows
          .map(
            (row) => <String, Object?>{
              'type': row.read<String>('block_type'),
              'text': row.read<String>('plain_text'),
              'checked': row.readNullable<bool>('is_checked'),
              'sortRank': row.read<int>('sort_rank'),
              'semanticHash': row.read<String>('semantic_hash'),
              'rowVersion': row.read<int>('row_version'),
            },
          )
          .toList(growable: false),
    },
    'folder': <String, Object?>{
      'id': folder.read<String>('id'),
      'name': folder.read<String>('name'),
      'normalizedName': folder.read<String>('normalized_name'),
      'sortRank': folder.read<int>('sort_rank'),
      'createdAtUtcMicros': folder.read<int>('created_at_utc'),
      'updatedAtUtcMicros': folder.read<int>('updated_at_utc'),
      'rowVersion': folder.read<int>('row_version'),
    },
    'past': <String, Object?>{
      'eventId': pastEvent.read<String>('id'),
      'documentId': pastEvent.read<String>('document_id'),
      'sourceTaskId': pastEvent.read<String>('source_task_id'),
      'appendSequence': pastEvent.read<int>('append_sequence'),
      'completedAtUtcMicros': pastEvent.read<int>('completed_at_utc'),
      'completionLocalDate': pastEvent.read<String>('completion_local_date'),
      'completionZoneId': pastEvent.read<String>('completion_zone_id'),
      'sourceSnapshotVersion': pastEvent.read<int>('source_snapshot_version'),
      'sourceSnapshotJson': pastEvent.read<String>('source_snapshot_json'),
      'sourceSha256': pastEvent.read<String>('source_sha256'),
      'anchorState': pastEvent.read<String>('anchor_state'),
      'createdAtUtcMicros': pastEvent.read<int>('created_at_utc'),
      'updatedAtUtcMicros': pastEvent.read<int>('updated_at_utc'),
      'rowVersion': pastEvent.read<int>('row_version'),
      'parts': pastParts
          .map(
            (row) => <String, Object?>{
              'id': row.read<String>('id'),
              'role': row.read<String>('role'),
              'sourceOrder': row.read<int>('source_order'),
              'originalPayloadJson': row.read<String>('original_payload_json'),
              'originalPlainText': row.read<String>('original_plain_text'),
              'originalSha256': row.read<String>('original_sha256'),
            },
          )
          .toList(growable: false),
      'anchors': pastAnchors
          .map(
            (row) => <String, Object?>{
              'id': row.read<String>('id'),
              'partId': row.read<String>('part_id'),
              'currentBlockId': row.readNullable<String>('current_block_id'),
              'lastKnownBlockId': row.read<String>('last_known_block_id'),
              'relation': row.read<String>('relation'),
              'linkState': row.read<String>('link_state'),
              'currentSha256': row.readNullable<String>('current_sha256'),
              'currentBlockType': row.readNullable<String>(
                'current_block_type',
              ),
              'currentPlainText': row.readNullable<String>(
                'current_plain_text',
              ),
              'currentSortRank': row.readNullable<int>('current_sort_rank'),
            },
          )
          .toList(growable: false),
      'documentBlocks': pastDocumentBlocks
          .map(
            (row) => <String, Object?>{
              'id': row.read<String>('id'),
              'type': row.read<String>('block_type'),
              'text': row.read<String>('plain_text'),
              'checked': row.readNullable<bool>('is_checked'),
              'sortRank': row.read<int>('sort_rank'),
              'semanticHash': row.read<String>('semantic_hash'),
              'rowVersion': row.read<int>('row_version'),
            },
          )
          .toList(growable: false),
    },
    'settings': <String, Object?>{
      'localeMode': settings.read<String>('locale_mode'),
      'fontMode': settings.read<String>('font_mode'),
      'textScalePercent': settings.read<int>('text_scale_percent'),
      'density': settings.read<String>('density'),
      'defaultSoundEnabled': settings.read<bool>('default_sound_enabled'),
      'defaultVibrationEnabled': settings.read<bool>(
        'default_vibration_enabled',
      ),
      'defaultSnoozeMinutes': settings.read<int>('default_snooze_minutes'),
      'autoBackupEnabled': settings.read<bool>('auto_backup_enabled'),
      'autoBackupHourLocal': settings.read<int>('auto_backup_hour_local'),
      'autoBackupMinuteLocal': settings.read<int>('auto_backup_minute_local'),
      'backupEncryptionEnabled': settings.read<bool>(
        'backup_encryption_enabled',
      ),
      'helpSeenVersion': settings.read<int>('help_seen_version'),
      'updatedAtUtcMicros': settings.read<int>('updated_at_utc'),
      'rowVersion': settings.read<int>('row_version'),
    },
  };
}

Future<void> waitForReleaseAcceptanceHostSignal({
  String signalName = 'notification-observed.signal',
  String phase = 'notification evidence',
}) async {
  const timeout = Duration(minutes: 18);
  const interval = Duration(milliseconds: 250);
  final deadline = DateTime.now().add(timeout);
  final signal = await releaseAcceptanceEvidenceFile(signalName);
  while (DateTime.now().isBefore(deadline)) {
    if (await signal.exists()) return;
    await Future<void>.delayed(interval);
  }
  throw StateError(
    'Host $phase signal did not arrive within '
    '${timeout.inMinutes} minutes.',
  );
}

String assertReleaseAcceptanceCard(
  WidgetTester tester, {
  required String title,
}) {
  final cardFinder = find.byWidgetPredicate(
    (widget) => widget is TaskCard && widget.title == title,
  );
  expect(cardFinder, findsOneWidget);
  final card = tester.widget<TaskCard>(cardFinder);
  final label = card.schedule.displayLabel;
  expect(label, isNotNull);
  expect(card.schedule.reminderTimeLabel, isNotNull);
  expect(label, contains(card.schedule.reminderTimeLabel!));
  expect(label, contains(card.schedule.reminderSuffix));
  expect(
    find.descendant(of: cardFinder, matching: find.text(label!)),
    findsOneWidget,
  );
  return label;
}

Future<void> waitForNotificationRegistration(
  DangguiDatabase database,
  String taskId,
) async {
  const interval = Duration(milliseconds: 250);
  const timeout = Duration(seconds: 20);
  final attempts = (timeout.inMicroseconds / interval.inMicroseconds).ceil();
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    final row = await database
        .customSelect(
          'SELECT nr.platform, pj.status FROM notification_registrations nr '
          'JOIN reminders r ON r.id = nr.reminder_id '
          'JOIN platform_jobs pj ON pj.aggregate_id = r.id '
          'WHERE r.task_id = ? ORDER BY pj.created_at_utc DESC LIMIT 1',
          variables: <Variable<Object>>[Variable.withString(taskId)],
        )
        .getSingleOrNull();
    if (row != null &&
        row.read<String>('platform') == 'android' &&
        row.read<String>('status') == 'succeeded') {
      return;
    }
    await Future<void>.delayed(interval);
  }
  throw StateError(
    'Notification registration did not become durable within '
    '${timeout.inSeconds} seconds.',
  );
}
