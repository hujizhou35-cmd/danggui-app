import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:danggui/src/services/notifications/local_time_zone.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;
  late _SteppingClock clock;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    clock = _SteppingClock(DateTime.utc(2026, 10, 25, 0, 59, 58));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        appClockProvider.overrideWithValue(clock),
        appIdGeneratorProvider.overrideWithValue(_SequenceIds()),
        appLocalTimeZoneResolverProvider.overrideWithValue(
          const _FixedTimeZoneResolver('Europe/Berlin'),
        ),
      ],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('one task mutation uses one injected instant and stable identifiers', () async {
    final taskId = await controller.createTask(title: 'deterministic task');

    expect(taskId, 'contract-id-1');
    expect(
      clock.reads,
      1,
      reason: 'a transaction must not straddle clock reads',
    );
    final task = await database
        .customSelect(
          'SELECT document_id, created_at_utc, updated_at_utc FROM tasks WHERE id = ?',
          variables: [
            // Avoid importing Drift's full expression surface just for the seam.
            // customSelect binds the same stable ID returned by the controller.
            Variable.withString(taskId),
          ],
        )
        .getSingle();
    final document = await database
        .customSelect(
          'SELECT created_at_utc, updated_at_utc FROM documents WHERE id = ?',
          variables: [Variable.withString(task.read<String>('document_id'))],
        )
        .getSingle();
    final expected = DateTime.utc(
      2026,
      10,
      25,
      0,
      59,
      58,
    ).microsecondsSinceEpoch;

    expect(task.read<String>('document_id'), 'contract-id-2');
    expect(task.read<int>('created_at_utc'), expected);
    expect(task.read<int>('updated_at_utc'), expected);
    expect(document.read<int>('created_at_utc'), expected);
    expect(document.read<int>('updated_at_utc'), expected);
  });

  test(
    'trash retention derives exactly thirty days from the injected clock',
    () async {
      final taskId = await controller.createTask(title: 'retention task');
      clock.value = DateTime.utc(2026, 11, 1, 12);

      await controller.deleteTask(taskId);

      final marker = await database
          .customSelect(
            'SELECT deleted_at_utc, purge_after_utc FROM trash_entries '
            'WHERE entity_id = ?',
            variables: [Variable.withString(taskId)],
          )
          .getSingle();
      final deletedAt = clock.value.microsecondsSinceEpoch;
      expect(marker.read<int>('deleted_at_utc'), deletedAt);
      expect(
        marker.read<int>('purge_after_utc'),
        deletedAt + const Duration(days: 30).inMicroseconds,
      );
    },
  );

  test('reminder persists the injected canonical IANA zone', () async {
    final taskId = await controller.createTask(
      title: 'DST reminder',
      reminderAt: DateTime.utc(2026, 10, 25, 1, 30),
    );

    final reminder = await database
        .customSelect(
          'SELECT scheduled_zone_id FROM reminders WHERE task_id = ?',
          variables: [Variable.withString(taskId)],
        )
        .getSingle();
    expect(reminder.read<String>('scheduled_zone_id'), 'Europe/Berlin');
  });

  test(
    'completion stores canonical zone and its fall-DST local fields',
    () async {
      final taskId = await controller.createTask(title: 'DST completion');

      await controller.setTaskActive(taskId, false);

      final task = await database
          .customSelect(
            'SELECT closed_local_date, closed_local_time, closed_zone_id '
            'FROM tasks WHERE id = ?',
            variables: [Variable.withString(taskId)],
          )
          .getSingle();
      expect(task.read<String>('closed_zone_id'), 'Europe/Berlin');
      expect(task.read<String>('closed_local_date'), '2026-10-25');
      expect(task.read<String>('closed_local_time'), '02:59');
    },
  );

  test('Past preserves completion zone and wall time across restart', () async {
    final taskId = await controller.createTask(title: 'restart completion');
    await controller.setTaskActive(taskId, false);

    container.dispose();
    clock = _SteppingClock(DateTime.utc(2026, 10, 26, 12));
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        appClockProvider.overrideWithValue(clock),
        appIdGeneratorProvider.overrideWithValue(_SequenceIds()),
        appLocalTimeZoneResolverProvider.overrideWithValue(
          const _FixedTimeZoneResolver('America/Los_Angeles'),
        ),
      ],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);

    await controller.addTaskToPast(taskId);

    final event = await database.select(database.pastEvents).getSingle();
    expect(event.completionZoneId, 'Europe/Berlin');
    expect(event.completionLocalDate, '2026-10-25');
    final timePart = await database
        .customSelect(
          'SELECT b.plain_text FROM past_event_parts p '
          'JOIN past_anchor_links l ON l.part_id = p.id '
          'JOIN document_blocks b ON b.id = l.current_block_id '
          'WHERE p.event_id = ? AND p.role = ?',
          variables: [
            Variable.withString(event.id),
            Variable.withString('time'),
          ],
        )
        .getSingle();
    expect(timePart.read<String>('plain_text'), '02:59');
  });
}

final class _SteppingClock implements Clock {
  _SteppingClock(this.value);

  DateTime value;
  int reads = 0;

  @override
  DateTime nowUtc() {
    reads += 1;
    return value.toUtc();
  }
}

final class _SequenceIds implements IdGenerator {
  int _next = 0;

  @override
  String next() => 'contract-id-${++_next}';
}

final class _FixedTimeZoneResolver implements LocalTimeZoneResolver {
  const _FixedTimeZoneResolver(this.identifier);

  final String identifier;

  @override
  Future<String> currentIdentifier(DateTime localInstant) async => identifier;
}
