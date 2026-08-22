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
  final counts = <String, int>{};
  for (final table in <String>[
    'tasks',
    'reminders',
    'notification_registrations',
    'platform_jobs',
    'documents',
    'document_blocks',
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
  };
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
