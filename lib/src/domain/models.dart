/// Stable string values are persisted in SQLite. Never persist enum indexes.
enum TaskStatus { active, completionPending, archived, trashed }

enum ReminderStatus { scheduled, paused, permissionDenied, expired, cancelled }

enum ReminderPauseReason { taskClosed, permissionDenied, restoreReview, user }

enum DocumentKind { taskBody, past, note }

enum DocumentBlockType {
  paragraph,
  bullet,
  numbered,
  checklist,
  pastDate,
  pastEntry,
}

enum PastAnchorState { attached, modified, detached, orphaned }

enum PastPartRole { time, title, body, checklist, dueDate, plan }

enum AnchorRelation { original, split, merged, replacement }

enum AnchorLinkState { linked, deleted, orphaned }

enum LocaleMode { system, zhHans, en, ja, ru }

enum FontMode { sans, serif }

enum DisplayDensity { loose, compact }

enum PlatformJobKind {
  scheduleReminder,
  cancelReminder,
  refreshReminderLocale,
  runBackup,
}

enum PlatformJobStatus { pending, running, succeeded, failed }

enum SearchScope { task, past, note }

enum TrashEntityType { task, note }

sealed class EntityId {
  const EntityId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      runtimeType == other.runtimeType &&
      other is EntityId &&
      value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class TaskId extends EntityId {
  const TaskId(super.value);
}

final class NoteId extends EntityId {
  const NoteId(super.value);
}

final class FolderId extends EntityId {
  const FolderId(super.value);
}

final class DocumentId extends EntityId {
  const DocumentId(super.value);
}

final class ReminderId extends EntityId {
  const ReminderId(super.value);
}

final class PastEventId extends EntityId {
  const PastEventId(super.value);
}

final class TrashId extends EntityId {
  const TrashId(super.value);
}

final class TaskDraft {
  const TaskDraft({required this.title, this.dueLocalDate, this.planText = ''});

  final String title;
  final String? dueLocalDate;
  final String planText;
}

final class TaskUpdate {
  const TaskUpdate({
    required this.title,
    required this.planText,
    this.dueLocalDate,
  });

  final String title;
  final String? dueLocalDate;
  final String planText;
}

final class TaskModel {
  const TaskModel({
    required this.id,
    required this.documentId,
    required this.title,
    required this.status,
    required this.manualRank,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
    this.dueLocalDate,
    this.planText = '',
    this.closedAtUtc,
    this.closedLocalDate,
    this.closedLocalTime,
    this.closedZoneId,
    this.archivedAtUtc,
    this.deletedAtUtc,
  });

  final TaskId id;
  final DocumentId documentId;
  final String title;
  final String? dueLocalDate;
  final String planText;
  final TaskStatus status;
  final int manualRank;
  final DateTime? closedAtUtc;
  final String? closedLocalDate;
  final String? closedLocalTime;
  final String? closedZoneId;
  final DateTime? archivedAtUtc;
  final DateTime? deletedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int rowVersion;
}

final class ReminderDraft {
  const ReminderDraft({
    required this.taskId,
    required this.scheduledLocalDateTime,
    required this.scheduledZoneId,
    required this.scheduledAtUtc,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  final TaskId taskId;
  final String scheduledLocalDateTime;
  final String scheduledZoneId;
  final DateTime scheduledAtUtc;
  final bool soundEnabled;
  final bool vibrationEnabled;
}

final class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.taskId,
    required this.scheduledLocalDateTime,
    required this.scheduledZoneId,
    required this.scheduledAtUtc,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.status,
    required this.scheduleRevision,
    this.pauseReason,
    this.snoozedUntilUtc,
  });

  final ReminderId id;
  final TaskId taskId;
  final String scheduledLocalDateTime;
  final String scheduledZoneId;
  final DateTime scheduledAtUtc;
  final DateTime? snoozedUntilUtc;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ReminderStatus status;
  final ReminderPauseReason? pauseReason;
  final int scheduleRevision;
}

final class DocumentBlockModel {
  const DocumentBlockModel({
    required this.id,
    required this.documentId,
    required this.sortRank,
    required this.blockType,
    required this.plainText,
    this.parentBlockId,
    this.payloadJson = '{}',
    this.attributesJson = '{}',
    this.isChecked,
  });

  final String id;
  final DocumentId documentId;
  final String? parentBlockId;
  final int sortRank;
  final DocumentBlockType blockType;
  final String plainText;
  final String payloadJson;
  final String attributesJson;
  final bool? isChecked;
}

final class NoteDraft {
  const NoteDraft({this.title = '', this.body = '', this.folderId});

  final String title;
  final String body;
  final FolderId? folderId;
}

final class NoteUpdate {
  const NoteUpdate({required this.title, this.folderId});

  final String title;
  final FolderId? folderId;
}

final class NoteModel {
  const NoteModel({
    required this.id,
    required this.documentId,
    required this.title,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
    this.folderId,
    this.pinnedAtUtc,
    this.deletedAtUtc,
  });

  final NoteId id;
  final DocumentId documentId;
  final FolderId? folderId;
  final String title;
  final DateTime? pinnedAtUtc;
  final DateTime? deletedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int rowVersion;
}

final class FolderModel {
  const FolderModel({
    required this.id,
    required this.name,
    required this.sortRank,
  });

  final FolderId id;
  final String name;
  final int sortRank;
}

final class PastEventModel {
  const PastEventModel({
    required this.id,
    required this.sourceTaskId,
    required this.appendSequence,
    required this.completedAtUtc,
    required this.completionLocalDate,
    required this.completionZoneId,
    required this.anchorState,
  });

  final PastEventId id;
  final TaskId sourceTaskId;
  final int appendSequence;
  final DateTime completedAtUtc;
  final String completionLocalDate;
  final String completionZoneId;
  final PastAnchorState anchorState;
}

final class AppSettingsModel {
  const AppSettingsModel({
    this.localeMode = LocaleMode.system,
    this.fontMode = FontMode.sans,
    this.textScalePercent = 100,
    this.density = DisplayDensity.loose,
    this.defaultSoundEnabled = true,
    this.defaultVibrationEnabled = true,
    this.defaultSnoozeMinutes = 10,
    this.autoBackupEnabled = true,
    this.autoBackupHourLocal = 2,
    this.autoBackupMinuteLocal = 0,
    this.backupEncryptionEnabled = false,
    this.helpSeenVersion = 0,
    this.rowVersion = 1,
  });

  final LocaleMode localeMode;
  final FontMode fontMode;
  final int textScalePercent;
  final DisplayDensity density;
  final bool defaultSoundEnabled;
  final bool defaultVibrationEnabled;
  final int defaultSnoozeMinutes;
  final bool autoBackupEnabled;
  final int autoBackupHourLocal;
  final int autoBackupMinuteLocal;
  final bool backupEncryptionEnabled;
  final int helpSeenVersion;
  final int rowVersion;
}

final class SearchHit {
  const SearchHit({
    required this.scope,
    required this.entityId,
    required this.title,
    required this.body,
  });

  final SearchScope scope;
  final String entityId;
  final String title;
  final String body;
}

final class PlatformJobModel {
  const PlatformJobModel({
    required this.id,
    required this.kind,
    required this.aggregateId,
    required this.aggregateRevision,
    required this.payloadJson,
    required this.status,
    required this.attempts,
  });

  final String id;
  final PlatformJobKind kind;
  final String aggregateId;
  final int aggregateRevision;
  final String payloadJson;
  final PlatformJobStatus status;
  final int attempts;
}

final class TrashItemModel {
  const TrashItemModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.displayTitle,
    required this.deletedAtUtc,
    required this.purgeAfterUtc,
  });

  final TrashId id;
  final TrashEntityType entityType;
  final String entityId;
  final String displayTitle;
  final DateTime deletedAtUtc;
  final DateTime purgeAfterUtc;
}

sealed class DangguiDataException implements Exception {
  const DangguiDataException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ValidationException extends DangguiDataException {
  const ValidationException(super.message);
}

final class NotFoundException extends DangguiDataException {
  const NotFoundException(super.message);
}

final class StateConflictException extends DangguiDataException {
  const StateConflictException(super.message);
}
