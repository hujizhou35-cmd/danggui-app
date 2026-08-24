import '../domain/models.dart';

const _unset = Object();

final class TaskViewModel {
  const TaskViewModel({
    required this.id,
    required this.title,
    required this.status,
    required this.manualRank,
    this.dueDate,
    this.reminderAt,
    this.plan = '',
    this.body = '',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.reminderStatus,
    this.reminderPauseReason,
  });

  final String id;
  final String title;
  final TaskStatus status;
  final int manualRank;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final String plan;
  final String body;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ReminderStatus? reminderStatus;
  final ReminderPauseReason? reminderPauseReason;

  TaskViewModel copyWith({
    String? title,
    TaskStatus? status,
    int? manualRank,
    Object? dueDate = _unset,
    Object? reminderAt = _unset,
    String? plan,
    String? body,
    bool? soundEnabled,
    bool? vibrationEnabled,
    Object? reminderStatus = _unset,
    Object? reminderPauseReason = _unset,
  }) {
    return TaskViewModel(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      manualRank: manualRank ?? this.manualRank,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      reminderAt: identical(reminderAt, _unset)
          ? this.reminderAt
          : reminderAt as DateTime?,
      plan: plan ?? this.plan,
      body: body ?? this.body,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      reminderStatus: identical(reminderStatus, _unset)
          ? this.reminderStatus
          : reminderStatus as ReminderStatus?,
      reminderPauseReason: identical(reminderPauseReason, _unset)
          ? this.reminderPauseReason
          : reminderPauseReason as ReminderPauseReason?,
    );
  }
}

final class NoteViewModel {
  const NoteViewModel({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.folderId,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String? folderId;
  final bool pinned;
  final DateTime updatedAt;

  NoteViewModel copyWith({
    String? title,
    String? body,
    Object? folderId = _unset,
    bool? pinned,
    DateTime? updatedAt,
  }) {
    return NoteViewModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      folderId: identical(folderId, _unset)
          ? this.folderId
          : folderId as String?,
      pinned: pinned ?? this.pinned,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class FolderViewModel {
  const FolderViewModel({required this.id, required this.name});

  final String id;
  final String name;
}

final class PastBlockViewModel {
  const PastBlockViewModel({
    required this.id,
    required this.type,
    required this.text,
    this.isChecked,
  });

  final String id;
  final DocumentBlockType type;
  final String text;
  final bool? isChecked;
}

enum PastEditorSegmentKind { dateHeading, event, freeform }

final class PastEditorSegmentViewModel {
  const PastEditorSegmentViewModel({
    required this.id,
    required this.kind,
    required this.text,
    required this.separatorBefore,
    required this.sourceBlockIds,
    this.eventId,
    this.completionLocalDate,
  });

  final String id;
  final PastEditorSegmentKind kind;
  final String text;
  final String separatorBefore;
  final List<String> sourceBlockIds;
  final String? eventId;
  final String? completionLocalDate;
}

final class PastEditorDocumentViewModel {
  const PastEditorDocumentViewModel({
    required this.revision,
    required this.segments,
  });

  static const empty = PastEditorDocumentViewModel(
    revision: 0,
    segments: <PastEditorSegmentViewModel>[],
  );

  final int revision;
  final List<PastEditorSegmentViewModel> segments;

  String get text => segments
      .map((segment) => '${segment.separatorBefore}${segment.text}')
      .join();

  PastEditorDraft createDraft(String editedText) => PastEditorDraft(
    baseRevision: revision,
    baseText: text,
    baseSegments: segments,
    text: editedText,
  );
}

final class PastEditorDraft {
  const PastEditorDraft({
    required this.baseRevision,
    required this.baseText,
    required this.baseSegments,
    required this.text,
  });

  final int baseRevision;
  final String baseText;
  final List<PastEditorSegmentViewModel> baseSegments;
  final String text;
}

final class DangguiAppState {
  const DangguiAppState({
    this.tasks = const <TaskViewModel>[],
    this.notes = const <NoteViewModel>[],
    this.folders = const <FolderViewModel>[],
    this.pastBlocks = const <PastBlockViewModel>[],
    this.pastDocument = PastEditorDocumentViewModel.empty,
    this.settings = const AppSettingsModel(),
    this.searchQuery = '',
  });

  final List<TaskViewModel> tasks;
  final List<NoteViewModel> notes;
  final List<FolderViewModel> folders;
  final List<PastBlockViewModel> pastBlocks;
  final PastEditorDocumentViewModel pastDocument;
  final AppSettingsModel settings;
  final String searchQuery;

  DangguiAppState copyWith({
    List<TaskViewModel>? tasks,
    List<NoteViewModel>? notes,
    List<FolderViewModel>? folders,
    List<PastBlockViewModel>? pastBlocks,
    PastEditorDocumentViewModel? pastDocument,
    AppSettingsModel? settings,
    String? searchQuery,
  }) {
    return DangguiAppState(
      tasks: tasks ?? this.tasks,
      notes: notes ?? this.notes,
      folders: folders ?? this.folders,
      pastBlocks: pastBlocks ?? this.pastBlocks,
      pastDocument: pastDocument ?? this.pastDocument,
      settings: settings ?? this.settings,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
