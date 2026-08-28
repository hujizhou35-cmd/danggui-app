import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Persists the device alarm generation without adding a backup field/table.
///
/// v1.1.5 replacement restores mark their already-required successful
/// `restore_runs` audit row. Portable snapshots remove that private marker,
/// so a different device can never inherit the source device's generation.
/// Databases without a v1.1.5 marker (including every v1.1.4 database) use a
/// stable generation derived from their existing dataset identity.
final class DeviceAlarmGenerationStore {
  const DeviceAlarmGenerationStore(this.database);

  static const markerKey = 'alarmGeneration';

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
    r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final DangguiDatabase database;

  /// Reads the generation that must accompany native alarm actions.
  ///
  /// Only a successful replacement audit whose valid UUID marker exactly
  /// matches its row ID is accepted. Older or malformed rows cannot become a
  /// device generation and fall back to the stable v1.1.4-compatible value.
  Future<String> readCurrent() async {
    final rows = await database
        .customSelect(
          'SELECT id, summary_json FROM restore_runs '
          'WHERE mode = ? AND status = ? AND summary_json IS NOT NULL '
          'ORDER BY rowid DESC',
          variables: <Variable<Object>>[
            Variable.withString('replace'),
            Variable.withString('succeeded'),
          ],
        )
        .get();
    for (final row in rows) {
      final id = row.read<String>('id');
      final marker = _readMarker(row.read<String>('summary_json'));
      if (marker != null &&
          _uuidPattern.hasMatch(id) &&
          _uuidPattern.hasMatch(marker) &&
          marker.toLowerCase() == id.toLowerCase()) {
        return marker.toLowerCase();
      }
    }

    final metadata = await database
        .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
        .getSingleOrNull();
    final datasetId = metadata?.read<String>('dataset_id');
    if (datasetId == null || datasetId.isEmpty) {
      throw StateError('Device alarm generation is unavailable.');
    }
    return 'legacy:$datasetId';
  }

  /// Creates the successful replacement audit and rotates the generation.
  ///
  /// Existing markers are removed in the same transaction. The new marker is
  /// durable in the prepared candidate before that candidate is swapped into
  /// the canonical live path.
  Future<String> createForReplacement({
    required String operationId,
    required String sourceName,
    required String sourceSha256,
    required int sourceSchemaVersion,
    required bool encrypted,
    required String safetyCopyName,
    required int completedAtUtc,
  }) async {
    if (!_uuidPattern.hasMatch(operationId)) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Expected a valid UUID.',
      );
    }
    final canonicalOperationId = operationId.toLowerCase();
    await database.transaction(() async {
      await _stripMarkers();
      await database.customStatement(
        'INSERT INTO restore_runs '
        '(id, source_name, source_sha256, mode, source_schema_version, '
        'pre_restore_backup_run_id, status, summary_json, started_at_utc, '
        'completed_at_utc, error_code) '
        'VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, NULL)',
        <Object?>[
          canonicalOperationId,
          sourceName,
          sourceSha256,
          'replace',
          sourceSchemaVersion,
          'succeeded',
          jsonEncode(<String, Object?>{
            'encrypted': encrypted,
            'safetyCopy': safetyCopyName,
            markerKey: canonicalOperationId,
          }),
          completedAtUtc,
          completedAtUtc,
        ],
      );
    });
    return canonicalOperationId;
  }

  /// Removes the device-private marker from a disposable portable snapshot.
  ///
  /// The normal backup path invokes this inside its snapshot transaction. The
  /// restore audit itself remains portable; only its device identity is scrubbed.
  Future<void> stripFromPortableSnapshot() => _stripMarkers();

  Future<void> _stripMarkers() async {
    final rows = await database
        .customSelect(
          'SELECT id, summary_json FROM restore_runs '
          'WHERE summary_json IS NOT NULL',
        )
        .get();
    for (final row in rows) {
      final summary = _readSummary(row.read<String>('summary_json'));
      if (summary == null) {
        // A portable copy must never guess whether malformed internal audit
        // JSON contains a device-only alarm generation. Failing closed leaves
        // the live database untouched and prevents that opaque value from
        // crossing devices inside a .dgbak package.
        throw const FormatException(
          'Restore audit summary cannot be safely made portable.',
        );
      }
      if (!summary.containsKey(markerKey)) continue;
      summary.remove(markerKey);
      await database.customStatement(
        'UPDATE restore_runs SET summary_json = ? WHERE id = ?',
        <Object?>[jsonEncode(summary), row.read<String>('id')],
      );
    }
  }

  static String? _readMarker(String value) {
    final marker = _readSummary(value)?[markerKey];
    return marker is String ? marker : null;
  }

  static Map<String, Object?>? _readSummary(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } on FormatException {
      return null;
    }
  }
}
