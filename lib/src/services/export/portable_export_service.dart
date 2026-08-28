import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../application/app_store.dart';
import '../../core/app_version.dart';
import '../../data/database.dart';
import 'portable_export_models.dart';

export 'portable_export_models.dart';

const _appId = 'com.danggui.memo';
const _format = 'danggui-portable-export';
const _formatVersion = 1;
const _manifestPath = 'manifest.json';
const _dataPath = 'data.json';
const _maximumArchiveBytes = 256 * 1024 * 1024;
const _maximumEntryBytes = 128 * 1024 * 1024;
const _maximumManifestBytes = 512 * 1024;
const _pastRangePolicy =
    'The current Past document is included in full because free-form edits '
    'cannot be losslessly or honestly attributed to a date range. The source '
    'event ledger below is filtered to the requested range.';

final portableExportServiceProvider = Provider<PortableExportService>((ref) {
  return PortableExportService(
    readDatabase: () => ref.read(databaseProvider.future),
    readTemporaryDirectory: getTemporaryDirectory,
  );
});

typedef PortableExportReservationCreator = Future<void> Function(File file);

/// Creates local-readable, versioned exports without performing network I/O.
///
/// Output is always written below [readTemporaryDirectory]. A caller may then
/// hand the returned file to a platform share/save sheet; this service itself
/// never uploads or copies the archive outside temporary storage.
final class PortableExportService {
  PortableExportService({
    required this.readDatabase,
    required this.readTemporaryDirectory,
    DateTime Function()? nowUtc,
    String Function()? operationId,
    PortableExportReservationCreator? createReservation,
    this.maximumGeneratedEntryBytes = _maximumEntryBytes,
    this.maximumGeneratedUncompressedBytes = _maximumArchiveBytes,
  }) : nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       operationId = operationId ?? const Uuid().v4,
       createReservation =
           createReservation ?? _createExclusiveExportReservation {
    if (maximumGeneratedEntryBytes <= 0 ||
        maximumGeneratedUncompressedBytes <= 0 ||
        maximumGeneratedEntryBytes > maximumGeneratedUncompressedBytes) {
      throw ArgumentError(
        'Portable export generation limits must be positive and the per-entry '
        'limit cannot exceed the total uncompressed limit.',
      );
    }
  }

  final Future<DangguiDatabase> Function() readDatabase;
  final Future<Directory> Function() readTemporaryDirectory;
  final DateTime Function() nowUtc;
  final String Function() operationId;
  final PortableExportReservationCreator createReservation;
  final int maximumGeneratedEntryBytes;
  final int maximumGeneratedUncompressedBytes;

  Future<PortableExportResult> export(PortableExportRequest request) async {
    final createdAt = nowUtc().toUtc();
    final database = await readDatabase();
    final snapshot = await database.transaction(
      () => _readSnapshot(database, request),
    );
    final scope = request.toJson();
    final payload = <String, Object?>{
      'format': _format,
      'formatVersion': _formatVersion,
      'appId': _appId,
      'appVersion': appTechnicalVersion,
      'databaseSchemaVersion': database.schemaVersion,
      'createdAtUtc': createdAt.toIso8601String(),
      'datasetId': snapshot.datasetId,
      'scope': scope,
      'folders': snapshot.folders,
      'tasks': snapshot.tasks,
      'past': snapshot.past,
      'notes': snapshot.notes,
    };

    final payloadEntries = <String, Uint8List>{
      _dataPath: _utf8Bytes(_prettyCanonicalJson(payload)),
      'markdown/folders.md': _utf8Bytes(_renderFolders(snapshot, request)),
      'markdown/notes.md': _utf8Bytes(_renderNotes(snapshot, request)),
      'markdown/past.md': _utf8Bytes(_renderPast(snapshot, request)),
      'markdown/tasks.md': _utf8Bytes(_renderTasks(snapshot, request)),
    };
    var totalGeneratedBytes = 0;
    for (final entry in payloadEntries.entries) {
      if (entry.value.length > maximumGeneratedEntryBytes) {
        throw FileSystemException(
          'Portable export entry exceeds its generation limit.',
          entry.key,
        );
      }
      totalGeneratedBytes += entry.value.length;
      if (totalGeneratedBytes > maximumGeneratedUncompressedBytes) {
        throw const FileSystemException(
          'Portable export content exceeds its uncompressed generation limit.',
        );
      }
    }
    final fileMetadata = <Map<String, Object?>>[];
    for (final entry in payloadEntries.entries) {
      fileMetadata.add(<String, Object?>{
        'path': entry.key,
        'mediaType': entry.key.endsWith('.json')
            ? 'application/json; charset=utf-8'
            : 'text/markdown; charset=utf-8',
        'byteLength': entry.value.length,
        'sha256': await _sha256(entry.value),
      });
    }
    final contentSha256 = await _sha256(
      _utf8Bytes(
        _canonicalJson(<String, Object?>{
          for (final file in fileMetadata)
            file['path']! as String: file['sha256'],
        }),
      ),
    );
    final manifest = <String, Object?>{
      'format': _format,
      'manifestVersion': _formatVersion,
      'appId': _appId,
      'appVersion': appTechnicalVersion,
      'databaseSchemaVersion': database.schemaVersion,
      'createdAtUtc': createdAt.toIso8601String(),
      'datasetId': snapshot.datasetId,
      'scope': scope,
      'recordCounts': snapshot.recordCounts,
      'contentSha256': contentSha256,
      'files': fileMetadata,
    };
    final manifestBytes = _utf8Bytes(_prettyCanonicalJson(manifest));
    if (manifestBytes.length > _maximumManifestBytes) {
      throw const FileSystemException('Portable export manifest is too large.');
    }
    if (totalGeneratedBytes + manifestBytes.length >
        maximumGeneratedUncompressedBytes) {
      throw const FileSystemException(
        'Portable export content exceeds its uncompressed generation limit.',
      );
    }

    final archive = Archive()
      ..addFile(ArchiveFile.bytes(_manifestPath, manifestBytes));
    for (final entry in payloadEntries.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    final archiveBytes = Uint8List.fromList(
      ZipEncoder().encodeBytes(archive, level: 6),
    );
    if (archiveBytes.length > _maximumArchiveBytes) {
      throw const FileSystemException('Portable export archive is too large.');
    }

    final temporaryRoot = await readTemporaryDirectory();
    final exportDirectory = Directory(
      p.join(temporaryRoot.absolute.path, 'danggui-portable-exports'),
    );
    await exportDirectory.create(recursive: true);
    final id = _safeId(operationId());
    final stamp = _fileTimestamp(createdAt);
    final scopeName = switch (request.kind) {
      PortableExportScopeKind.full => 'full',
      PortableExportScopeKind.pastAll => 'past-all',
      PortableExportScopeKind.pastDateRange => 'past',
      PortableExportScopeKind.pastSelection => 'past-selection',
      PortableExportScopeKind.noteIds => 'notes',
      PortableExportScopeKind.noteFolder => 'folder-notes',
    };
    final allocation = await _reserveUniqueExportPath(
      exportDirectory: exportDirectory,
      baseName: 'danggui-$scopeName-$stamp-${id.substring(0, 8)}',
      createReservation: createReservation,
    );
    final output = allocation.output;
    final reservation = allocation.reservation;
    final partial = File('${output.path}.partial');
    try {
      if (await partial.exists()) await partial.delete();
      await partial.writeAsBytes(archiveBytes, flush: true);
      final verified = await PortableExportVerifier.verify(partial);
      if (verified.manifest['contentSha256'] != contentSha256) {
        throw const FileSystemException(
          'Portable export verification returned a different content hash.',
        );
      }
      if (await output.exists()) {
        throw const FileSystemException(
          'Portable export destination became occupied before publication.',
        );
      }
      await partial.rename(output.path);
      return PortableExportResult(
        file: output,
        manifest: Map<String, Object?>.unmodifiable(manifest),
        archiveSha256: verified.archiveSha256,
      );
    } on Object {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      if (await reservation.exists()) await reservation.delete();
    }
  }
}

Future<_ReservedExportPath> _reserveUniqueExportPath({
  required Directory exportDirectory,
  required String baseName,
  required PortableExportReservationCreator createReservation,
}) async {
  for (var attempt = 1; attempt <= 10000; attempt++) {
    final suffix = attempt == 1 ? '' : '-$attempt';
    final output = File(p.join(exportDirectory.path, '$baseName$suffix.zip'));
    final reservation = File('${output.path}.reservation');
    try {
      await createReservation(reservation);
    } on FileSystemException {
      if (await _pathIsOccupied(reservation.path) ||
          await _pathIsOccupied(output.path)) {
        continue;
      }
      rethrow;
    }
    if (await output.exists()) {
      await reservation.delete();
      continue;
    }
    return _ReservedExportPath(output: output, reservation: reservation);
  }
  throw const FileSystemException(
    'Could not reserve a unique portable export destination.',
  );
}

Future<void> _createExclusiveExportReservation(File file) async {
  await file.create(exclusive: true);
}

Future<bool> _pathIsOccupied(String path) async =>
    await FileSystemEntity.type(path, followLinks: false) !=
    FileSystemEntityType.notFound;

final class _ReservedExportPath {
  const _ReservedExportPath({required this.output, required this.reservation});

  final File output;
  final File reservation;
}

/// Defensive verifier for archives produced by [PortableExportService].
final class PortableExportVerifier {
  const PortableExportVerifier._();

  static Future<VerifiedPortableExport> verify(File file) async {
    if (!await file.exists()) {
      throw const FileSystemException('Portable export does not exist.');
    }
    final length = await file.length();
    if (length <= 0 || length > _maximumArchiveBytes) {
      throw const FormatException('Portable export size is invalid.');
    }
    final archiveBytes = await file.readAsBytes();
    late final Archive archive;
    late final ZipDecoder decoder;
    try {
      decoder = ZipDecoder();
      archive = decoder.decodeBytes(archiveBytes);
    } on Object {
      throw const FormatException('Portable export ZIP is damaged.');
    }
    const requiredEntries = <String>{
      _manifestPath,
      _dataPath,
      'markdown/folders.md',
      'markdown/notes.md',
      'markdown/past.md',
      'markdown/tasks.md',
    };
    final centralDirectoryNames = decoder.directory.fileHeaders
        .map((header) => header.filename)
        .toList(growable: false);
    if (centralDirectoryNames.length != requiredEntries.length ||
        centralDirectoryNames.toSet().length != centralDirectoryNames.length) {
      throw const FormatException(
        'Portable export has duplicate or unexpected entries.',
      );
    }
    final files = <String, ArchiveFile>{};
    var totalUncompressed = 0;
    for (final entry in archive.files) {
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          !_safeArchivePath(entry.name)) {
        throw const FormatException('Portable export has an unsafe entry.');
      }
      if (files.containsKey(entry.name)) {
        throw const FormatException('Portable export has duplicate entries.');
      }
      if (entry.size < 0 || entry.size > _maximumEntryBytes) {
        throw const FormatException('Portable export entry size is invalid.');
      }
      totalUncompressed += entry.size;
      if (totalUncompressed > _maximumArchiveBytes) {
        throw const FormatException(
          'Portable export expands beyond its limit.',
        );
      }
      final expectedCrc = entry.crc32;
      if (expectedCrc == null || getCrc32(entry.content) != expectedCrc) {
        throw const FormatException(
          'Portable export entry checksum is invalid.',
        );
      }
      files[entry.name] = entry;
    }
    if (files.keys.toSet().difference(requiredEntries).isNotEmpty ||
        requiredEntries.difference(files.keys.toSet()).isNotEmpty) {
      throw const FormatException('Portable export entries are incomplete.');
    }
    final manifestFile = files[_manifestPath]!;
    if (manifestFile.size <= 0 || manifestFile.size > _maximumManifestBytes) {
      throw const FormatException('Portable export manifest size is invalid.');
    }
    final manifest = _decodeJsonMap(manifestFile.content);
    _validateManifestIdentity(manifest);
    final describedFiles = manifest['files'];
    if (describedFiles is! List || describedFiles.length != 5) {
      throw const FormatException('Portable export file manifest is invalid.');
    }
    final calculatedHashes = <String, Object?>{};
    final seen = <String>{};
    for (final raw in describedFiles) {
      if (raw is! Map) {
        throw const FormatException('Portable export file record is invalid.');
      }
      final record = raw.cast<Object?, Object?>();
      final path = record['path'];
      final expectedLength = record['byteLength'];
      final expectedHash = record['sha256'];
      if (path is! String ||
          path == _manifestPath ||
          !requiredEntries.contains(path) ||
          !seen.add(path) ||
          expectedLength is! int ||
          expectedHash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
        throw const FormatException('Portable export file record is invalid.');
      }
      final entry = files[path]!;
      final bytes = Uint8List.fromList(entry.content);
      if (bytes.length != expectedLength ||
          await _sha256(bytes) != expectedHash) {
        throw FormatException('Portable export checksum failed for $path.');
      }
      calculatedHashes[path] = expectedHash;
    }
    if (seen.length != requiredEntries.length - 1) {
      throw const FormatException(
        'Portable export file records are incomplete.',
      );
    }
    final contentHash = await _sha256(
      _utf8Bytes(_canonicalJson(calculatedHashes)),
    );
    if (manifest['contentSha256'] != contentHash) {
      throw const FormatException('Portable export content checksum failed.');
    }
    final data = _decodeJsonMap(files[_dataPath]!.content);
    _validatePayloadMatchesManifest(data, manifest);
    return VerifiedPortableExport(
      manifest: Map<String, Object?>.unmodifiable(manifest),
      archiveSha256: await _sha256(archiveBytes),
      entryNames: List<String>.unmodifiable(files.keys),
    );
  }
}

final class _ExportSnapshot {
  const _ExportSnapshot({
    required this.datasetId,
    required this.folders,
    required this.tasks,
    required this.past,
    required this.notes,
    required this.recordCounts,
  });

  final String datasetId;
  final List<Map<String, Object?>> folders;
  final List<Map<String, Object?>> tasks;
  final Map<String, Object?> past;
  final List<Map<String, Object?>> notes;
  final Map<String, int> recordCounts;
}

Future<_ExportSnapshot> _readSnapshot(
  DangguiDatabase database,
  PortableExportRequest request,
) async {
  final metadata = await database
      .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
      .getSingle();
  final allFolders = await _rows(
    database,
    'SELECT * FROM folders ORDER BY sort_rank, normalized_name, id',
  );
  final allTasks = await _rows(
    database,
    'SELECT * FROM tasks ORDER BY manual_rank, id',
  );
  final allNotes = await _rows(
    database,
    'SELECT * FROM notes ORDER BY COALESCE(folder_id, \'\'), '
    'CASE WHEN pinned_at_utc IS NULL THEN 1 ELSE 0 END, '
    'pinned_at_utc DESC, updated_at_utc DESC, id',
  );
  final allDocuments = await _rows(
    database,
    'SELECT * FROM documents ORDER BY kind, id',
  );
  final allBlocks = await _rows(
    database,
    'SELECT * FROM document_blocks '
    'ORDER BY document_id, sort_rank, id',
  );
  final allReminders = await _rows(
    database,
    'SELECT * FROM reminders ORDER BY task_id, id',
  );
  final allEvents = await _rows(
    database,
    'SELECT * FROM past_events '
    'ORDER BY completion_local_date, append_sequence, id',
  );
  final allParts = await _rows(
    database,
    'SELECT * FROM past_event_parts ORDER BY event_id, source_order, id',
  );
  final allAnchors = await _rows(
    database,
    'SELECT * FROM past_anchor_links ORDER BY part_id, id',
  );

  final documentsById = <String, Map<String, Object?>>{
    for (final document in allDocuments) document['id']! as String: document,
  };
  final blocksByDocument = _groupRows(allBlocks, 'document_id');
  final remindersByTask = <String, Map<String, Object?>>{
    for (final reminder in allReminders)
      reminder['task_id']! as String: reminder,
  };

  final selectedTasks = request.kind == PortableExportScopeKind.full
      ? allTasks
      : const <Map<String, Object?>>[];
  late final List<Map<String, Object?>> selectedNotes;
  switch (request.kind) {
    case PortableExportScopeKind.full:
      selectedNotes = allNotes;
    case PortableExportScopeKind.pastAll ||
        PortableExportScopeKind.pastSelection:
      selectedNotes = const <Map<String, Object?>>[];
    case PortableExportScopeKind.noteIds:
      final ids = request.noteIds.toSet();
      selectedNotes = allNotes
          .where((note) => ids.contains(note['id']))
          .toList(growable: false);
    case PortableExportScopeKind.noteFolder:
      selectedNotes = allNotes
          .where((note) => note['folder_id'] == request.folderId)
          .toList(growable: false);
    case PortableExportScopeKind.pastDateRange:
      selectedNotes = const <Map<String, Object?>>[];
  }
  final relevantFolderIds = selectedNotes
      .map((note) => note['folder_id'])
      .whereType<String>()
      .toSet();
  final selectedFolders = request.kind == PortableExportScopeKind.full
      ? allFolders
      : allFolders
            .where(
              (folder) =>
                  folder['id'] == request.folderId ||
                  relevantFolderIds.contains(folder['id']),
            )
            .toList(growable: false);

  final tasks = <Map<String, Object?>>[
    for (final task in selectedTasks)
      <String, Object?>{
        'record': task,
        'document': _documentBundle(
          task['document_id']! as String,
          documentsById,
          blocksByDocument,
        ),
        'reminder': ?remindersByTask[task['id']],
      },
  ];
  final notes = <Map<String, Object?>>[
    for (final note in selectedNotes)
      <String, Object?>{
        'record': note,
        'document': _documentBundle(
          note['document_id']! as String,
          documentsById,
          blocksByDocument,
        ),
      },
  ];

  final pastDocument = allDocuments
      .where((document) => document['singleton_key'] == 'past.main')
      .single;
  final selectedEvents = switch (request.kind) {
    PortableExportScopeKind.full ||
    PortableExportScopeKind.pastAll => allEvents,
    PortableExportScopeKind.pastDateRange =>
      allEvents
          .where((event) {
            final date = event['completion_local_date']! as String;
            return date.compareTo(request.startLocalDate!) >= 0 &&
                date.compareTo(request.endLocalDate!) <= 0;
          })
          .toList(growable: false),
    PortableExportScopeKind.pastSelection ||
    PortableExportScopeKind.noteIds ||
    PortableExportScopeKind.noteFolder => const <Map<String, Object?>>[],
  };
  final partsByEvent = _groupRows(allParts, 'event_id');
  final anchorsByPart = _groupRows(allAnchors, 'part_id');
  final pastIncluded = switch (request.kind) {
    PortableExportScopeKind.full ||
    PortableExportScopeKind.pastAll ||
    PortableExportScopeKind.pastDateRange ||
    PortableExportScopeKind.pastSelection => true,
    PortableExportScopeKind.noteIds ||
    PortableExportScopeKind.noteFolder => false,
  };
  final includeCurrentDocument =
      pastIncluded && request.kind != PortableExportScopeKind.pastSelection;
  final events = <Map<String, Object?>>[
    for (final event in selectedEvents)
      <String, Object?>{
        'record': event,
        'parts': <Map<String, Object?>>[
          for (final part in partsByEvent[event['id']] ?? const [])
            <String, Object?>{
              'record': part,
              'anchors': anchorsByPart[part['id']] ?? const [],
            },
        ],
      },
  ];
  final currentBlocks = includeCurrentDocument
      ? blocksByDocument[pastDocument['id']] ?? const <Map<String, Object?>>[]
      : const <Map<String, Object?>>[];
  final past = <String, Object?>{
    'included': pastIncluded,
    if (includeCurrentDocument)
      'currentDocument': <String, Object?>{
        'record': pastDocument,
        'blocks': currentBlocks,
        'selectionPolicy': request.kind == PortableExportScopeKind.pastDateRange
            ? _pastRangePolicy
            : 'completeCurrentDocument',
      },
    if (request.kind == PortableExportScopeKind.pastSelection)
      'selection': <String, Object?>{
        'type': 'userSelectedFreeText',
        'text': request.selectedText,
        'sourceAttribution':
            'none; no source events, parts, or anchors are inferred',
      },
    'events': events,
  };
  final selectedParts = events.fold<int>(
    0,
    (total, event) => total + (event['parts']! as List).length,
  );
  final selectedAnchors = events.fold<int>(0, (total, event) {
    return total +
        (event['parts']! as List).fold<int>(
          0,
          (subtotal, part) =>
              subtotal + ((part as Map)['anchors']! as List).length,
        );
  });
  return _ExportSnapshot(
    datasetId: metadata.read<String>('dataset_id'),
    folders: selectedFolders,
    tasks: tasks,
    past: past,
    notes: notes,
    recordCounts: <String, int>{
      'folders': selectedFolders.length,
      'tasks': tasks.length,
      'taskBlocks': _countBundleBlocks(tasks),
      'taskReminders': tasks.where((task) => task['reminder'] != null).length,
      'notes': notes.length,
      'noteBlocks': _countBundleBlocks(notes),
      'pastCurrentBlocks': currentBlocks.length,
      'pastEvents': events.length,
      'pastEventParts': selectedParts,
      'pastAnchorLinks': selectedAnchors,
    },
  );
}

Future<List<Map<String, Object?>>> _rows(
  DangguiDatabase database,
  String sql,
) async {
  final result = await database.customSelect(sql).get();
  return <Map<String, Object?>>[
    for (final row in result) Map<String, Object?>.unmodifiable(row.data),
  ];
}

Map<String, List<Map<String, Object?>>> _groupRows(
  List<Map<String, Object?>> rows,
  String key,
) {
  final result = <String, List<Map<String, Object?>>>{};
  for (final row in rows) {
    result.putIfAbsent(row[key]! as String, () => []).add(row);
  }
  return result;
}

Map<String, Object?> _documentBundle(
  String documentId,
  Map<String, Map<String, Object?>> documentsById,
  Map<String, List<Map<String, Object?>>> blocksByDocument,
) {
  final document = documentsById[documentId];
  if (document == null) {
    throw StateError(
      'Document $documentId referenced by an entity is missing.',
    );
  }
  return <String, Object?>{
    'record': document,
    'blocks': blocksByDocument[documentId] ?? const <Map<String, Object?>>[],
  };
}

int _countBundleBlocks(List<Map<String, Object?>> bundles) {
  return bundles.fold<int>(0, (total, bundle) {
    final document = bundle['document']! as Map<String, Object?>;
    return total + (document['blocks']! as List).length;
  });
}

String _renderTasks(_ExportSnapshot snapshot, PortableExportRequest request) {
  final out = StringBuffer('# 当归事项导出\n\n');
  if (request.kind != PortableExportScopeKind.full) {
    return '$out本次导出范围不包含事项。\n';
  }
  if (snapshot.tasks.isEmpty) return '$out（无事项）\n';
  for (final bundle in snapshot.tasks) {
    final task = bundle['record']! as Map<String, Object?>;
    out
      ..writeln('## ${_oneLine(task['title'])}')
      ..writeln()
      ..writeln('- ID: `${task['id']}`')
      ..writeln('- 状态: `${task['status']}`')
      ..writeln('- 截止日期: ${task['due_local_date'] ?? '未设置'}')
      ..writeln('- 计划: ${_inline(task['plan_text'])}');
    final reminder = bundle['reminder'] as Map<String, Object?>?;
    if (reminder != null) {
      out.writeln(
        '- 提醒: ${reminder['scheduled_local_date_time']} '
        '(${reminder['scheduled_zone_id']}, ${reminder['status']})',
      );
    } else {
      out.writeln('- 提醒: 未设置');
    }
    out
      ..writeln()
      ..writeln('### 正文')
      ..writeln();
    final document = bundle['document']! as Map<String, Object?>;
    _writeBlocks(out, document['blocks']! as List);
    out.writeln();
  }
  return out.toString();
}

String _renderPast(_ExportSnapshot snapshot, PortableExportRequest request) {
  final out = StringBuffer('# 当归“过往”导出\n\n');
  final included = snapshot.past['included']! as bool;
  if (!included) return '$out本次导出范围不包含“过往”。\n';
  if (request.kind == PortableExportScopeKind.pastSelection) {
    final selection = snapshot.past['selection']! as Map<String, Object?>;
    out.writeAll(<Object?>[
      '> 以下内容是用户主动选中的“过往”自由文本。\n',
      '> 本导出不推断、不伪造任何来源事件、原始部件或锚点关系。\n\n',
      '## 所选文本\n\n',
      selection['text'],
      '\n',
    ]);
    return out.toString();
  }
  if (request.kind == PortableExportScopeKind.pastDateRange) {
    out
      ..writeln(
        '> 来源事件范围：${request.startLocalDate} 至 '
        '${request.endLocalDate}（含首尾）。',
      )
      ..writeln('> $_pastRangePolicy')
      ..writeln();
  }
  final current = snapshot.past['currentDocument']! as Map<String, Object?>;
  out
    ..writeln('## 当前可编辑正文（完整）')
    ..writeln();
  _writeBlocks(out, current['blocks']! as List);
  out
    ..writeln()
    ..writeln('## 不可变来源事件账本')
    ..writeln();
  final events = snapshot.past['events']! as List;
  if (events.isEmpty) {
    out.writeln('（选定范围内无来源事件）');
    return out.toString();
  }
  for (final rawBundle in events) {
    final bundle = rawBundle as Map<String, Object?>;
    final event = bundle['record']! as Map<String, Object?>;
    out
      ..writeln(
        '### ${event['completion_local_date']} · #${event['append_sequence']}',
      )
      ..writeln()
      ..writeln('- 事件 ID: `${event['id']}`')
      ..writeln('- 来源事项 ID: `${event['source_task_id']}`')
      ..writeln('- 锚点状态: `${event['anchor_state']}`')
      ..writeln('- 来源 SHA-256: `${event['source_sha256']}`')
      ..writeln()
      ..writeln('#### 原始来源快照')
      ..writeln()
      ..writeln(_fenced(event['source_snapshot_json']?.toString() ?? ''))
      ..writeln()
      ..writeln('#### 原始部件与当前锚点')
      ..writeln();
    for (final rawPart in bundle['parts']! as List) {
      final partBundle = rawPart as Map<String, Object?>;
      final part = partBundle['record']! as Map<String, Object?>;
      final anchors = partBundle['anchors']! as List;
      out.writeln(
        '- `${part['role']}`: ${_inline(part['original_plain_text'])} '
        '(原始 SHA-256 `${part['original_sha256']}`)',
      );
      for (final rawAnchor in anchors) {
        final anchor = rawAnchor as Map<String, Object?>;
        out.writeln(
          '  - 锚点 `${anchor['link_state']}` / `${anchor['relation']}`; '
          '当前块 `${anchor['current_block_id'] ?? '无'}`; '
          '最后块 `${anchor['last_known_block_id']}`',
        );
      }
    }
    out.writeln();
  }
  return out.toString();
}

String _renderNotes(_ExportSnapshot snapshot, PortableExportRequest request) {
  final out = StringBuffer('# 当归笔记导出\n\n');
  if (_isPastOnly(request.kind)) {
    return '$out本次导出范围不包含笔记。\n';
  }
  if (snapshot.notes.isEmpty) return '$out（无匹配笔记）\n';
  final foldersById = <String, Map<String, Object?>>{
    for (final folder in snapshot.folders) folder['id']! as String: folder,
  };
  for (final bundle in snapshot.notes) {
    final note = bundle['record']! as Map<String, Object?>;
    final folder = foldersById[note['folder_id']];
    out
      ..writeln('## ${_oneLine(note['title'], fallback: '无标题笔记')}')
      ..writeln()
      ..writeln('- ID: `${note['id']}`')
      ..writeln('- 文件夹: ${folder?['name'] ?? '未归类'}')
      ..writeln('- 置顶: ${note['pinned_at_utc'] == null ? '否' : '是'}')
      ..writeln('- 已删除: ${note['deleted_at_utc'] == null ? '否' : '是'}')
      ..writeln();
    final document = bundle['document']! as Map<String, Object?>;
    _writeBlocks(out, document['blocks']! as List);
    out.writeln();
  }
  return out.toString();
}

String _renderFolders(_ExportSnapshot snapshot, PortableExportRequest request) {
  final out = StringBuffer('# 当归笔记文件夹\n\n');
  if (_isPastOnly(request.kind)) {
    return '$out本次导出范围不包含文件夹。\n';
  }
  if (snapshot.folders.isEmpty) return '$out（无匹配文件夹）\n';
  for (final folder in snapshot.folders) {
    out.writeln(
      '- ${_inline(folder['name'])} '
      '(`id=${folder['id']}`, `sort=${folder['sort_rank']}`)',
    );
  }
  return out.toString();
}

bool _isPastOnly(PortableExportScopeKind kind) {
  return kind == PortableExportScopeKind.pastAll ||
      kind == PortableExportScopeKind.pastDateRange ||
      kind == PortableExportScopeKind.pastSelection;
}

void _writeBlocks(StringBuffer out, List<dynamic> rawBlocks) {
  if (rawBlocks.isEmpty) {
    out.writeln('（无正文）');
    return;
  }
  for (final raw in rawBlocks) {
    final block = raw as Map<String, Object?>;
    final text = block['plain_text']?.toString() ?? '';
    switch (block['block_type']) {
      case 'bullet':
        out.writeln('- ${text.replaceAll('\n', '\n  ')}');
      case 'numbered':
        out.writeln('1. ${text.replaceAll('\n', '\n   ')}');
      case 'checklist':
        out.writeln('- [${block['is_checked'] == 1 ? 'x' : ' '}] $text');
      case 'pastDate':
        out
          ..writeln('### ${_oneLine(text)}')
          ..writeln();
      default:
        out
          ..writeln(text)
          ..writeln();
    }
  }
}

String _oneLine(Object? value, {String fallback = '无标题'}) {
  final normalized = value
      ?.toString()
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}

String _inline(Object? value) {
  final normalized = value
      ?.toString()
      .replaceAll(RegExp(r'[\r\n]+'), ' / ')
      .trim();
  return normalized == null || normalized.isEmpty ? '未设置' : normalized;
}

String _fenced(String value) {
  var fence = '```';
  while (value.contains(fence)) {
    fence += '`';
  }
  return '$fence'
      'json\n$value\n$fence';
}

Uint8List _utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

Future<String> _sha256(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

String _prettyCanonicalJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(_canonical(value));
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonical).toList(growable: false);
  }
  return value;
}

Map<String, Object?> _decodeJsonMap(List<int> bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    return decoded.cast<String, Object?>();
  } on Object {
    throw const FormatException('Portable export manifest JSON is invalid.');
  }
}

void _validateManifestIdentity(Map<String, Object?> manifest) {
  if (manifest['format'] != _format ||
      manifest['manifestVersion'] != _formatVersion ||
      manifest['appId'] != _appId ||
      manifest['appVersion'] is! String ||
      manifest['databaseSchemaVersion'] is! int ||
      (manifest['databaseSchemaVersion']! as int) < 1 ||
      manifest['datasetId'] is! String ||
      (manifest['datasetId']! as String).isEmpty ||
      manifest['scope'] is! Map ||
      manifest['recordCounts'] is! Map ||
      manifest['createdAtUtc'] is! String ||
      manifest['contentSha256'] is! String ||
      !RegExp(r'^[0-9a-f]{64}$')
          .hasMatch(manifest['contentSha256']! as String)) {
    throw const FormatException('Portable export manifest is unsupported.');
  }
  final createdAt = DateTime.tryParse(manifest['createdAtUtc']! as String);
  if (createdAt == null || !createdAt.isUtc) {
    throw const FormatException('Portable export timestamp must be UTC.');
  }
  final scope = manifest['scope']! as Map;
  final kind = scope['kind'];
  if (kind is! String ||
      !PortableExportScopeKind.values.any((value) => value.name == kind)) {
    throw const FormatException('Portable export scope is unsupported.');
  }
}

void _validatePayloadMatchesManifest(
  Map<String, Object?> data,
  Map<String, Object?> manifest,
) {
  for (final field in const <String>[
    'format',
    'appId',
    'appVersion',
    'databaseSchemaVersion',
    'createdAtUtc',
    'datasetId',
  ]) {
    if (data[field] != manifest[field]) {
      throw FormatException('Portable export $field metadata is inconsistent.');
    }
  }
  if (data['formatVersion'] != manifest['manifestVersion'] ||
      _canonicalJson(data['scope']) != _canonicalJson(manifest['scope'])) {
    throw const FormatException(
      'Portable export scope metadata is inconsistent.',
    );
  }
  late final Map<String, int> calculatedCounts;
  try {
    final tasks = data['tasks']! as List;
    final notes = data['notes']! as List;
    final folders = data['folders']! as List;
    final past = data['past']! as Map;
    if (past['included'] is! bool) throw const FormatException();
    final currentDocument = past['currentDocument'] as Map?;
    final currentBlocks = currentDocument?['blocks'] as List? ?? const [];
    final events = past['events']! as List;
    int bundleBlockCount(List bundles) => bundles.fold<int>(0, (total, raw) {
      final bundle = raw as Map;
      final document = bundle['document']! as Map;
      return total + (document['blocks']! as List).length;
    });

    var partCount = 0;
    var anchorCount = 0;
    for (final rawEvent in events) {
      final event = rawEvent as Map;
      final parts = event['parts']! as List;
      partCount += parts.length;
      for (final rawPart in parts) {
        anchorCount += ((rawPart as Map)['anchors']! as List).length;
      }
    }
    calculatedCounts = <String, int>{
      'folders': folders.length,
      'tasks': tasks.length,
      'taskBlocks': bundleBlockCount(tasks),
      'taskReminders': tasks
          .where((raw) => (raw as Map).containsKey('reminder'))
          .length,
      'notes': notes.length,
      'noteBlocks': bundleBlockCount(notes),
      'pastCurrentBlocks': currentBlocks.length,
      'pastEvents': events.length,
      'pastEventParts': partCount,
      'pastAnchorLinks': anchorCount,
    };
  } on Object {
    throw const FormatException('Portable export data structure is invalid.');
  }
  if (_canonicalJson(calculatedCounts) !=
      _canonicalJson(manifest['recordCounts'])) {
    throw const FormatException(
      'Portable export record counts are inconsistent.',
    );
  }
}

bool _safeArchivePath(String value) {
  if (value.isEmpty || value.contains('\\') || value.startsWith('/')) {
    return false;
  }
  final segments = value.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

String _safeId(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (normalized.length >= 8) return normalized;
  return '${normalized}00000000'.substring(0, 8);
}

String _fileTimestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}T${two(utc.hour)}'
      '${two(utc.minute)}${two(utc.second)}Z';
}
