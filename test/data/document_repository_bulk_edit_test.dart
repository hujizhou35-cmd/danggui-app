import 'package:danggui/src/data/data_support.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/repositories/core_repositories.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _blockCount = 3600;
const _changedIndex = 1200;
const _unchangedAnchorIndex = 2400;

void main() {
  test('3600-block edit writes only the changed row and reconciles anchors in bulk', () async {
    final database = DangguiDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    final pastRow = await database
        .customSelect(
          "SELECT id FROM documents WHERE singleton_key = 'past.main'",
        )
        .getSingle();
    final pastId = pastRow.read<String>('id');
    final changedOriginalHash = await _blockHash('past text $_changedIndex');
    final unchangedHash = await _blockHash('past text $_unchangedAnchorIndex');
    final now = DateTime.utc(2026, 8, 22).microsecondsSinceEpoch;

    await database.batch((batch) {
      for (var index = 0; index < _blockCount; index++) {
        final hash = switch (index) {
          _changedIndex => changedOriginalHash,
          _unchangedAnchorIndex => unchangedHash,
          _ => index.toRadixString(16).padLeft(64, '0'),
        };
        batch.customStatement(
          'INSERT INTO document_blocks '
          '(id, document_id, parent_block_id, sort_rank, block_type, '
          'plain_text, payload_json, attributes_json, is_checked, '
          'semantic_hash, created_at_utc, updated_at_utc, row_version) '
          "VALUES (?, ?, NULL, ?, 'pastEntry', ?, '{}', '{}', NULL, ?, ?, ?, 1)",
          <Object?>[
            'block-$index',
            pastId,
            index * 1024,
            'past text $index',
            hash,
            now,
            now,
          ],
        );
      }
      batch.customStatement(
        'UPDATE documents SET revision = 1, semantic_hash = ?, '
        'updated_at_utc = ? WHERE id = ?',
        <Object?>['d'.padLeft(64, '0'), now, pastId],
      );
      _addAnchoredEvent(
        batch,
        eventId: 'event-changed',
        documentId: pastId,
        partId: 'part-changed',
        anchorId: 'anchor-changed',
        blockId: 'block-$_changedIndex',
        hash: changedOriginalHash,
        sequence: 1,
        now: now,
      );
      _addAnchoredEvent(
        batch,
        eventId: 'event-unchanged',
        documentId: pastId,
        partId: 'part-unchanged',
        anchorId: 'anchor-unchanged',
        blockId: 'block-$_unchangedAnchorIndex',
        hash: unchangedHash,
        sequence: 2,
        now: now,
      );
    });

    final repository = DriftDocumentRepository(database);
    final blocks = await repository.getBlocks(DocumentId(pastId));
    final changed = <DocumentBlockModel>[
      for (var index = 0; index < blocks.length; index++)
        if (index == _changedIndex)
          DocumentBlockModel(
            id: blocks[index].id,
            documentId: blocks[index].documentId,
            parentBlockId: blocks[index].parentBlockId,
            sortRank: blocks[index].sortRank,
            blockType: blocks[index].blockType,
            plainText: '${blocks[index].plainText} edited',
            payloadJson: blocks[index].payloadJson,
            attributesJson: blocks[index].attributesJson,
            isChecked: blocks[index].isChecked,
          )
        else
          blocks[index],
    ];

    final watch = Stopwatch()..start();
    final revision = await repository.replaceBlocks(
      DocumentId(pastId),
      changed,
      expectedRevision: 1,
    );
    watch.stop();

    expect(revision, 2);
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 10)),
      reason: 'A one-block edit must not perform 3600 SQLite row updates.',
    );
    final writtenRows = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM document_blocks '
          'WHERE document_id = ? AND row_version > 1',
          variables: <Variable<Object>>[Variable.withString(pastId)],
        )
        .getSingle();
    expect(writtenRows.read<int>('total'), 1);
    expect(
      await database.select(database.documentRevisions).get(),
      hasLength(1),
    );

    final changedBlock = await database
        .customSelect(
          "SELECT semantic_hash FROM document_blocks WHERE id = 'block-$_changedIndex'",
        )
        .getSingle();
    final anchors = await database
        .customSelect(
          'SELECT id, current_sha256 FROM past_anchor_links ORDER BY id',
        )
        .get();
    expect(
      anchors
          .singleWhere((row) => row.read<String>('id') == 'anchor-changed')
          .read<String>('current_sha256'),
      changedBlock.read<String>('semantic_hash'),
    );
    expect(
      anchors
          .singleWhere((row) => row.read<String>('id') == 'anchor-unchanged')
          .read<String>('current_sha256'),
      unchangedHash,
    );
    final events = await database
        .customSelect(
          'SELECT id, anchor_state, row_version FROM past_events ORDER BY id',
        )
        .get();
    final changedEvent = events.singleWhere(
      (row) => row.read<String>('id') == 'event-changed',
    );
    final unchangedEvent = events.singleWhere(
      (row) => row.read<String>('id') == 'event-unchanged',
    );
    expect(changedEvent.read<String>('anchor_state'), 'modified');
    expect(changedEvent.read<int>('row_version'), 2);
    expect(unchangedEvent.read<String>('anchor_state'), 'attached');
    expect(unchangedEvent.read<int>('row_version'), 1);
    expect(await database.quickCheck(), const <String>['ok']);
    expect(await database.foreignKeyCheck(), isEmpty);
  }, timeout: const Timeout(Duration(seconds: 45)));
}

Future<String> _blockHash(String text) => sha256Hex(<String, Object?>{
  'type': DocumentBlockType.pastEntry.name,
  'text': text,
  'payload': '{}',
  'attributes': '{}',
  'checked': null,
});

void _addAnchoredEvent(
  Batch batch, {
  required String eventId,
  required String documentId,
  required String partId,
  required String anchorId,
  required String blockId,
  required String hash,
  required int sequence,
  required int now,
}) {
  batch.customStatement(
    'INSERT INTO past_events '
    '(id, document_id, source_task_id, append_sequence, completed_at_utc, '
    'completion_local_date, completion_zone_id, source_snapshot_version, '
    'source_snapshot_json, source_sha256, anchor_state, created_at_utc, '
    'updated_at_utc, row_version) '
    "VALUES (?, ?, ?, ?, ?, '2026-08-22', 'Asia/Shanghai', 1, '{}', ?, "
    "'attached', ?, ?, 1)",
    <Object?>[
      eventId,
      documentId,
      'source-$eventId',
      sequence,
      now,
      hash,
      now,
      now,
    ],
  );
  batch.customStatement(
    'INSERT INTO past_event_parts '
    '(id, event_id, role, source_order, original_payload_json, '
    'original_plain_text, original_sha256) '
    "VALUES (?, ?, 'title', 0, '{}', ?, ?)",
    <Object?>[partId, eventId, blockId, hash],
  );
  batch.customStatement(
    'INSERT INTO past_anchor_links '
    '(id, part_id, current_block_id, last_known_block_id, relation, '
    'link_state, current_sha256, updated_at_utc) '
    "VALUES (?, ?, ?, ?, 'original', 'linked', ?, ?)",
    <Object?>[anchorId, partId, blockId, blockId, hash, now],
  );
}
