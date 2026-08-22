import 'dart:io';

/// The intentionally small set of export scopes supported by the portable
/// export format. Values are serialized by name, so additions must remain
/// backwards compatible.
enum PortableExportScopeKind {
  full,
  pastAll,
  pastDateRange,
  pastSelection,
  noteIds,
  noteFolder,
}

/// A validated, immutable request for a local-readable export.
final class PortableExportRequest {
  PortableExportRequest._({
    required this.kind,
    this.startLocalDate,
    this.endLocalDate,
    this.noteIds = const <String>[],
    this.folderId,
    this.selectedText,
  });

  factory PortableExportRequest.full() =>
      PortableExportRequest._(kind: PortableExportScopeKind.full);

  factory PortableExportRequest.pastAll() =>
      PortableExportRequest._(kind: PortableExportScopeKind.pastAll);

  factory PortableExportRequest.pastDateRange({
    required String startLocalDate,
    required String endLocalDate,
  }) {
    final start = _validatedIsoDate(startLocalDate, 'startLocalDate');
    final end = _validatedIsoDate(endLocalDate, 'endLocalDate');
    if (start.compareTo(end) > 0) {
      throw ArgumentError.value(
        '$startLocalDate..$endLocalDate',
        'dateRange',
        'The start date must not be after the end date.',
      );
    }
    return PortableExportRequest._(
      kind: PortableExportScopeKind.pastDateRange,
      startLocalDate: start,
      endLocalDate: end,
    );
  }

  factory PortableExportRequest.notesByIds(Iterable<String> noteIds) {
    final ids = noteIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final sorted = ids.toSet().toList(growable: false)..sort();
    if (sorted.isEmpty) {
      throw ArgumentError.value(
        noteIds,
        'noteIds',
        'At least one non-empty note id is required.',
      );
    }
    return PortableExportRequest._(
      kind: PortableExportScopeKind.noteIds,
      noteIds: List<String>.unmodifiable(sorted),
    );
  }

  factory PortableExportRequest.pastSelection(String selectedText) {
    if (selectedText.trim().isEmpty) {
      throw ArgumentError.value(
        selectedText,
        'selectedText',
        'Selected Past text must not be blank.',
      );
    }
    return PortableExportRequest._(
      kind: PortableExportScopeKind.pastSelection,
      selectedText: selectedText,
    );
  }

  factory PortableExportRequest.notesInFolder(String folderId) {
    final normalized = folderId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        folderId,
        'folderId',
        'A non-empty folder id is required.',
      );
    }
    return PortableExportRequest._(
      kind: PortableExportScopeKind.noteFolder,
      folderId: normalized,
    );
  }

  final PortableExportScopeKind kind;
  final String? startLocalDate;
  final String? endLocalDate;
  final List<String> noteIds;
  final String? folderId;
  final String? selectedText;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    if (startLocalDate != null) 'startLocalDate': startLocalDate,
    if (endLocalDate != null) 'endLocalDate': endLocalDate,
    if (noteIds.isNotEmpty) 'noteIds': noteIds,
    if (folderId != null) 'folderId': folderId,
    if (kind == PortableExportScopeKind.pastSelection)
      'selectionType': 'userSelectedFreeText',
    if (kind == PortableExportScopeKind.pastDateRange)
      'pastCurrentDocumentPolicy': 'fullDocumentIncludedBecauseFreeFormEditsCannotBeLosslesslyAttributed',
  };
}

/// The completed archive and the exact metadata used to construct it.
final class PortableExportResult {
  const PortableExportResult({
    required this.file,
    required this.manifest,
    required this.archiveSha256,
  });

  final File file;
  final Map<String, Object?> manifest;
  final String archiveSha256;
}

/// Result of independently checking a generated portable export.
final class VerifiedPortableExport {
  const VerifiedPortableExport({
    required this.manifest,
    required this.archiveSha256,
    required this.entryNames,
  });

  final Map<String, Object?> manifest;
  final String archiveSha256;
  final List<String> entryNames;
}

String _validatedIsoDate(String value, String argumentName) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, argumentName, 'Expected YYYY-MM-DD.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(value, argumentName, 'Date does not exist.');
  }
  return value;
}
