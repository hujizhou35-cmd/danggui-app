# 当归 User Guide

当归 is a local-first task, Past, and notes app. Your content stays on this device by default. No account, upload, advertising, analytics, or AI is required.

## Tasks and reminders

1. Open Tasks and tap +. Enter a non-empty title; the date is optional.
2. Save immediately or choose More settings to add a plan, reminder, text, lists, and check items.
3. Open a card to edit it. Changes are autosaved before either the top or system Back action leaves the editor.
4. To add a reminder, choose its date, hour, and minute. The reminder may be earlier than the task date. Allow notification permission when asked.
5. If permission is denied, the reminder remains visible but cannot alert. Re-enable notifications in system settings later.
6. A reminder appears on the card: same-day time, cross-day date and time, or reminder date/time when the task has no date.

Turn a card switch off to mark it pending. Choose Add to Past to append it to the Past document, Delete to move it to Recently Deleted, or Undo to reverse an accidental action. Closing a task pauses its reminder; reopening only reschedules a future reminder. Past alerts are never fired late.

Use Search for titles, plans, text, and dates. In manual order, press and drag cards; date order places undated tasks after dated tasks.

## The Past document

Past is one continuously growing editable document. Completed tasks are appended by completion date. Edit it like normal text, use lists/check items, and use Undo/Redo. Automatic snapshots are made in the background and before destructive changes.

To convert text into a task, select it, open the platform selection menu, and choose Convert to task. For multiple lines, the first non-empty line becomes the title and the rest becomes the body. Review the prefilled panel and optionally choose a date. The original text always remains.

Search locates visible text. Export can include everything, a date range, or the exact selection. A portable ZIP contains readable Markdown, structured JSON, a manifest, and checksums; `.dgbak` is the separate complete restore format.

## Notes and folders

Tap + in Notes, enter a title and body, and use the toolbar for bullets, numbers, check items, Undo, and Redo. The menu can pin, export, convert selected text to a task, or delete the note.

Long-press a note to enter multi-select. Select more notes, then move them to a one-level folder, export a Markdown + JSON ZIP, or move them to Recently Deleted. With exactly one note selected, you can also create a prefilled task without removing the note.

Folders are one level deep. Deleting a folder never deletes its notes; they move to Unfiled. Pinned notes appear first.

## Appearance and language

In Settings, choose System, Simplified Chinese, English, Japanese, or Russian. The interface changes immediately; user-written content is never translated. You can also change typeface, text size, card density, sound, vibration, and the default 10/30/60-minute snooze.

## Backup, restore, and deletion

Daily backup is best-effort when the app starts or returns to the foreground. It keeps the latest 30 verified `.dgbak` files inside app support storage and catches up a missed day on the next run; mobile systems cannot guarantee work while the app is fully closed. Uninstalling or clearing app data may remove those internal copies. Create a manual backup to open the system share sheet and save an extra copy to Files, a computer, or another local destination. Optional encryption is off by default; its daily-backup password stays in device secure storage, is never uploaded, and cannot be recovered.

Export all data creates a readable Markdown + JSON ZIP for portability. It is not a restore backup.

Restore first performs a read-only inspection and shows creation time, versions, encryption, record counts, and a checksum summary. Choose Merge or Overwrite; Overwrite requires an extra warning. Before either operation, the app makes a verified safety copy of current data. Merge keeps current content and copies conflicts instead of silently overwriting them. Future reminders are registered again; expired reminders are not fired.

Deleted tasks and notes remain in Recently Deleted for 30 days. Past text uses Undo/Redo and snapshots rather than the trash.

## Privacy and troubleshooting

当归 requests notification access only for local alerts. File access is granted by the system only when you explicitly import, save, or share a file. It has no Internet permission. If an alert fails, check notification permission, battery restrictions, task state, and whether the time has passed. If backup fails, check free space and retry a manual copy. If startup self-check fails, keep app data and backups, tap Retry, and report the version and steps—do not uninstall before securing the data.
