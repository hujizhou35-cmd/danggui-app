import 'package:drift/drift.dart';

import '../domain/models.dart';
import 'data_support.dart';
import 'database.dart';

/// Recreates the disposable search projection from authoritative user data.
///
/// Backup search rows are intentionally never trusted: they can be missing,
/// stale, or refer to entities that no longer exist. The rebuild is atomic and
/// derives every searchable field from tasks, notes, the past document, and
/// their current document blocks.
final class SearchProjectionRebuilder {
  const SearchProjectionRebuilder._();

  static Future<void> rebuild(DangguiDatabase database) {
    return database.transaction(() async {
      final blocks = await database
          .customSelect(
            'SELECT document_id, plain_text, updated_at_utc '
            'FROM document_blocks ORDER BY document_id, sort_rank, id',
          )
          .get();
      final bodyParts = <String, List<String>>{};
      final latestBlockUpdate = <String, int>{};
      for (final block in blocks) {
        final documentId = block.read<String>('document_id');
        final text = block.read<String>('plain_text');
        if (text.isNotEmpty) {
          bodyParts.putIfAbsent(documentId, () => <String>[]).add(text);
        }
        final updatedAt = block.read<int>('updated_at_utc');
        final current = latestBlockUpdate[documentId];
        if (current == null || updatedAt > current) {
          latestBlockUpdate[documentId] = updatedAt;
        }
      }

      final records = <_SearchProjection>[];
      final tasks = await database
          .customSelect(
            'SELECT t.id, t.document_id, t.title, t.plan_text, '
            't.due_local_date, t.updated_at_utc AS entity_updated_at_utc, '
            'd.updated_at_utc AS document_updated_at_utc '
            'FROM tasks t JOIN documents d ON d.id = t.document_id '
            'WHERE t.deleted_at_utc IS NULL AND t.status IN (?, ?) '
            'ORDER BY t.id',
            variables: <Variable<Object>>[
              Variable.withString(TaskStatus.active.name),
              Variable.withString(TaskStatus.completionPending.name),
            ],
          )
          .get();
      for (final task in tasks) {
        final documentId = task.read<String>('document_id');
        final documentBody = (bodyParts[documentId] ?? const <String>[]).join(
          '\n',
        );
        records.add(
          _SearchProjection(
            scope: SearchScope.task.name,
            entityId: task.read<String>('id'),
            documentId: documentId,
            title: task.read<String>('title'),
            body: '${task.read<String>('plan_text')}\n$documentBody',
            dateKey: task.readNullable<String>('due_local_date') ?? '',
            updatedAtUtc: _latest(<int>[
              task.read<int>('entity_updated_at_utc'),
              task.read<int>('document_updated_at_utc'),
              latestBlockUpdate[documentId] ?? 0,
            ]),
          ),
        );
      }

      final notes = await database
          .customSelect(
            'SELECT n.id, n.document_id, n.title, '
            'n.updated_at_utc AS entity_updated_at_utc, '
            'd.updated_at_utc AS document_updated_at_utc '
            'FROM notes n JOIN documents d ON d.id = n.document_id '
            'WHERE n.deleted_at_utc IS NULL ORDER BY n.id',
          )
          .get();
      for (final note in notes) {
        final documentId = note.read<String>('document_id');
        records.add(
          _SearchProjection(
            scope: SearchScope.note.name,
            entityId: note.read<String>('id'),
            documentId: documentId,
            title: note.read<String>('title'),
            body: (bodyParts[documentId] ?? const <String>[]).join('\n'),
            dateKey: '',
            updatedAtUtc: _latest(<int>[
              note.read<int>('entity_updated_at_utc'),
              note.read<int>('document_updated_at_utc'),
              latestBlockUpdate[documentId] ?? 0,
            ]),
          ),
        );
      }

      final pastDocument = await database
          .customSelect(
            "SELECT id, updated_at_utc FROM documents "
            "WHERE singleton_key = 'past.main' LIMIT 1",
          )
          .getSingleOrNull();
      if (pastDocument != null) {
        final documentId = pastDocument.read<String>('id');
        final latestEvent = await database
            .customSelect(
              'SELECT completion_local_date, updated_at_utc '
              'FROM past_events WHERE document_id = ? '
              'ORDER BY append_sequence DESC, id DESC LIMIT 1',
              variables: <Variable<Object>>[Variable.withString(documentId)],
            )
            .getSingleOrNull();
        final body = (bodyParts[documentId] ?? const <String>[]).join('\n');
        final dateKey =
            latestEvent?.read<String>('completion_local_date') ?? '';
        if (body.isNotEmpty || dateKey.isNotEmpty) {
          records.add(
            _SearchProjection(
              scope: SearchScope.past.name,
              entityId: 'past.main',
              documentId: documentId,
              title: '',
              body: body,
              dateKey: dateKey,
              updatedAtUtc: _latest(<int>[
                pastDocument.read<int>('updated_at_utc'),
                latestBlockUpdate[documentId] ?? 0,
                latestEvent?.read<int>('updated_at_utc') ?? 0,
              ]),
            ),
          );
        }
      }

      await database.customStatement('DELETE FROM search_records');
      await database.batch((batch) {
        for (final record in records) {
          batch.customStatement(
            'INSERT INTO search_records '
            '(scope, entity_id, document_id, title_norm, body_norm, '
            'date_key, updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              record.scope,
              record.entityId,
              record.documentId,
              normalizedSearchText(record.title),
              normalizedSearchText(record.body),
              record.dateKey,
              record.updatedAtUtc,
            ],
          );
        }
      });
    });
  }

  static int _latest(Iterable<int> values) {
    var latest = 0;
    for (final value in values) {
      if (value > latest) latest = value;
    }
    return latest;
  }
}

final class _SearchProjection {
  const _SearchProjection({
    required this.scope,
    required this.entityId,
    required this.documentId,
    required this.title,
    required this.body,
    required this.dateKey,
    required this.updatedAtUtc,
  });

  final String scope;
  final String entityId;
  final String? documentId;
  final String title;
  final String body;
  final String dateKey;
  final int updatedAtUtc;
}
