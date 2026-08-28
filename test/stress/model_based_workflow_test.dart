import 'dart:math';

import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/domain/repositories.dart';
import 'package:danggui/src/services/notifications/local_time_zone.dart';
import 'package:danggui/src/services/trash/trash_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _seed = 0xD4A65;
const _operationCount = 640;

// This model intentionally covers task/note persistence only. Reminder,
// outbox, Past, export, and backup contracts are exercised by dedicated tests.

void main() {
  test(
    '640 seeded task and note operations preserve the shadow model',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      final clock = _ModelClock(DateTime.utc(2026, 8, 28, 8));
      final ids = _ModelIds();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) async => database),
          appClockProvider.overrideWithValue(clock),
          appIdGeneratorProvider.overrideWithValue(ids),
          appLocalTimeZoneResolverProvider.overrideWithValue(
            const _FixedZoneResolver(),
          ),
        ],
      );
      final tasks = <String, _ExpectedTask>{};
      final notes = <String, _ExpectedNote>{};
      final random = Random(_seed);

      try {
        await container.read(appStoreProvider.future);
        final controller = container.read(appStoreProvider.notifier);
        final trash = TrashService(
          () async => database,
          clock: clock,
          ids: ids,
        );

        for (var step = 0; step < _operationCount; step++) {
          final choice = random.nextInt(10);
          if (choice <= 1 && tasks.length < 18 || tasks.isEmpty) {
            final title = _text('task', step);
            final id = await controller.createTask(
              title: title,
              plan: _text('plan', step),
              body: _text('body', step),
            );
            tasks[id] = _ExpectedTask(title, TaskStatus.active);
          } else if (choice == 2 && _visibleTasks(tasks).isNotEmpty) {
            final expected = _pick(random, _visibleTasks(tasks));
            final current = _task(container, expected.key);
            final title = _text('edited-task', step);
            await controller.updateTask(
              current.copyWith(
                title: title,
                plan: _text('edited-plan', step),
                body: _text('edited-body', step),
              ),
            );
            expected.value.title = title;
          } else if (choice == 3 && _visibleTasks(tasks).isNotEmpty) {
            final expected = _pick(random, _visibleTasks(tasks));
            final makeActive =
                expected.value.status == TaskStatus.completionPending;
            await controller.setTaskActive(expected.key, makeActive);
            expected.value.status = makeActive
                ? TaskStatus.active
                : TaskStatus.completionPending;
          } else if (choice == 4 && _visibleTasks(tasks).isNotEmpty) {
            final expected = _pick(random, _visibleTasks(tasks));
            expected.value.restoreStatus = expected.value.status;
            await controller.deleteTask(expected.key);
            expected.value.status = TaskStatus.trashed;
          } else if (choice == 5 && _trashedTasks(tasks).isNotEmpty) {
            final expected = _pick(random, _trashedTasks(tasks));
            await controller.restoreTask(expected.key);
            expected.value.status = expected.value.restoreStatus;
          } else if (choice == 6 && notes.length < 14 || notes.isEmpty) {
            final title = _text('note', step);
            final body = _text('note-body', step);
            final id = await controller.createNote(title: title, body: body);
            notes[id] = _ExpectedNote(title, body);
          } else if (choice == 7 && _visibleNotes(notes).isNotEmpty) {
            final expected = _pick(random, _visibleNotes(notes));
            final current = _note(container, expected.key);
            final title = _text('edited-note', step);
            final body = _text('edited-note-body', step);
            await controller.updateNote(
              current.copyWith(
                title: title,
                body: body,
                pinned: !current.pinned,
              ),
            );
            expected.value
              ..title = title
              ..body = body
              ..pinned = !current.pinned;
          } else if (choice == 8 && _visibleNotes(notes).isNotEmpty) {
            final expected = _pick(random, _visibleNotes(notes));
            await controller.deleteNote(expected.key);
            expected.value.deleted = true;
          } else if (_trashedNotes(notes).isNotEmpty) {
            final expected = _pick(random, _trashedNotes(notes));
            final item = (await trash.loadItems()).singleWhere(
              (candidate) => candidate.entityId == expected.key,
            );
            await trash.restore(item.id);
            await controller.refresh();
            expected.value.deleted = false;
          } else {
            final visibleIds = container
                .read(appStoreProvider)
                .requireValue
                .tasks
                .map((task) => task.id)
                .toList();
            if (visibleIds.length > 1) {
              visibleIds.shuffle(random);
              await controller.reorderTasks(visibleIds);
              expect(
                container
                    .read(appStoreProvider)
                    .requireValue
                    .tasks
                    .map((task) => task.id),
                visibleIds,
              );
            }
          }

          if ((step + 1) % 32 == 0) {
            await _assertModel(database, container, tasks, notes);
          }
        }

        await _assertModel(database, container, tasks, notes);
        expect(await database.quickCheck(), const <String>['ok']);
        expect(await database.foreignKeyCheck(), isEmpty);
      } finally {
        container.dispose();
        await database.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _assertModel(
  DangguiDatabase database,
  ProviderContainer container,
  Map<String, _ExpectedTask> expectedTasks,
  Map<String, _ExpectedNote> expectedNotes,
) async {
  final taskRows = await database
      .customSelect('SELECT id, title, status FROM tasks ORDER BY id')
      .get();
  expect(taskRows, hasLength(expectedTasks.length));
  for (final row in taskRows) {
    final expected = expectedTasks[row.read<String>('id')];
    expect(expected, isNotNull);
    expect(row.read<String>('title'), expected!.title);
    expect(row.read<String>('status'), expected.status.name);
  }

  final noteRows = await database
      .customSelect(
        'SELECT id, title, pinned_at_utc, deleted_at_utc '
        'FROM notes ORDER BY id',
      )
      .get();
  expect(noteRows, hasLength(expectedNotes.length));
  for (final row in noteRows) {
    final expected = expectedNotes[row.read<String>('id')];
    expect(expected, isNotNull);
    expect(row.read<String>('title'), expected!.title);
    expect(row.readNullable<int>('pinned_at_utc') != null, expected.pinned);
    expect(row.readNullable<int>('deleted_at_utc') != null, expected.deleted);
  }

  final state = container.read(appStoreProvider).requireValue;
  expect(
    state.tasks.map((task) => task.id).toSet(),
    _visibleTasks(expectedTasks).map((entry) => entry.key).toSet(),
  );
  expect(
    state.notes.map((note) => note.id).toSet(),
    _visibleNotes(expectedNotes).map((entry) => entry.key).toSet(),
  );
  for (final note in state.notes) {
    final expected = expectedNotes[note.id]!;
    expect(note.title, expected.title);
    expect(note.body, expected.body);
    expect(note.pinned, expected.pinned);
  }

  final searchRows = await database
      .customSelect(
        'SELECT scope, entity_id FROM search_records '
        "WHERE scope IN ('task', 'note')",
      )
      .get();
  final expectedSearch = <String>{
    for (final task in _visibleTasks(expectedTasks)) 'task:${task.key}',
    for (final note in _visibleNotes(expectedNotes)) 'note:${note.key}',
  };
  expect(
    searchRows
        .map(
          (row) =>
              '${row.read<String>('scope')}:${row.read<String>('entity_id')}',
        )
        .toSet(),
    expectedSearch,
  );
}

TaskViewModel _task(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .tasks
    .singleWhere((task) => task.id == id);

NoteViewModel _note(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .notes
    .singleWhere((note) => note.id == id);

List<MapEntry<String, _ExpectedTask>> _visibleTasks(
  Map<String, _ExpectedTask> tasks,
) => tasks.entries
    .where((entry) => entry.value.status != TaskStatus.trashed)
    .toList(growable: false);

List<MapEntry<String, _ExpectedTask>> _trashedTasks(
  Map<String, _ExpectedTask> tasks,
) => tasks.entries
    .where((entry) => entry.value.status == TaskStatus.trashed)
    .toList(growable: false);

List<MapEntry<String, _ExpectedNote>> _visibleNotes(
  Map<String, _ExpectedNote> notes,
) => notes.entries
    .where((entry) => !entry.value.deleted)
    .toList(growable: false);

List<MapEntry<String, _ExpectedNote>> _trashedNotes(
  Map<String, _ExpectedNote> notes,
) =>
    notes.entries.where((entry) => entry.value.deleted).toList(growable: false);

MapEntry<String, T> _pick<T>(Random random, List<MapEntry<String, T>> values) =>
    values[random.nextInt(values.length)];

String _text(String prefix, int step) =>
    '$prefix-$step 中文 English 日本語 Русский 👩🏽‍💻 e\u0301';

final class _ExpectedTask {
  _ExpectedTask(this.title, this.status) : restoreStatus = status;

  String title;
  TaskStatus status;
  TaskStatus restoreStatus;
}

final class _ExpectedNote {
  _ExpectedNote(this.title, this.body);

  String title;
  String body;
  bool pinned = false;
  bool deleted = false;
}

final class _ModelClock implements Clock {
  _ModelClock(this._current);

  DateTime _current;

  @override
  DateTime nowUtc() {
    final value = _current;
    _current = _current.add(const Duration(seconds: 1));
    return value;
  }
}

final class _ModelIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'model-${++_next}';
}

final class _FixedZoneResolver implements LocalTimeZoneResolver {
  const _FixedZoneResolver();

  @override
  Future<String> currentIdentifier(DateTime localInstant) async =>
      'Asia/Shanghai';
}
