import 'models.dart';

abstract interface class Clock {
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

abstract interface class IdGenerator {
  String next();
}

abstract interface class TaskRepository {
  Stream<List<TaskModel>> watchOpenTasks();

  Future<TaskModel?> getTask(TaskId id);

  Future<TaskModel> createTask(TaskDraft draft);

  Future<TaskModel> updateTask(
    TaskId id,
    TaskUpdate update, {
    required int expectedVersion,
  });

  Future<ReminderModel?> getReminder(TaskId taskId);

  Future<void> closeTask(
    TaskId id, {
    required String localDate,
    required String localTime,
    required String zoneId,
  });

  Future<void> reopenTask(TaskId id);

  Future<ReminderModel> setReminder(ReminderDraft draft);

  Future<void> removeReminder(TaskId taskId);

  Future<void> moveTaskToTrash(TaskId id);

  Future<void> restoreTask(TaskId id);

  Future<int> purgeExpiredTrash();
}

abstract interface class NoteRepository {
  Stream<List<NoteModel>> watchNotes();

  Future<NoteModel> createNote(NoteDraft draft);

  Future<NoteModel> updateNote(
    NoteId id,
    NoteUpdate update, {
    required int expectedVersion,
  });

  Future<FolderModel> createFolder(String name);

  Future<void> deleteFolder(FolderId id);

  Future<void> moveNoteToTrash(NoteId id);

  Future<void> restoreNote(NoteId id);
}

abstract interface class DocumentRepository {
  Future<List<DocumentBlockModel>> getBlocks(DocumentId documentId);

  Stream<List<DocumentBlockModel>> watchBlocks(DocumentId documentId);

  /// Replaces the ordered block set atomically and advances the document
  /// revision. Callers must pass the last observed revision.
  Future<int> replaceBlocks(
    DocumentId documentId,
    List<DocumentBlockModel> blocks, {
    required int expectedRevision,
    Map<String, List<String>> replacements = const {},
  });
}

abstract interface class PastRepository {
  Future<PastEventModel> addClosedTaskToPast(TaskId id);

  Stream<List<DocumentBlockModel>> watchPastBlocks();
}

abstract interface class SettingsRepository {
  Stream<AppSettingsModel> watchSettings();

  Future<AppSettingsModel> getSettings();

  Future<AppSettingsModel> saveSettings(
    AppSettingsModel settings, {
    required int expectedVersion,
  });
}

abstract interface class SearchRepository {
  Future<List<SearchHit>> search(String query, {SearchScope? scope});
}

abstract interface class PlatformJobRepository {
  Future<List<PlatformJobModel>> getPending({int limit = 50});

  Future<void> markSucceeded(String id);

  Future<void> markFailed(String id, {required String errorCode});
}

abstract interface class TrashRepository {
  Stream<List<TrashItemModel>> watchTrash();

  Future<void> restore(TrashId id);

  Future<int> purgeExpired();
}
