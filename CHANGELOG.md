# Changelog

All notable changes to Danggui are documented here. The project follows
[Semantic Versioning](https://semver.org/) for public releases.

## 1.0.0 - release candidate (2026-08-22)

This entry describes the v1.0.0 release candidate. It does not assert that a
GitHub Release exists or that its final CI/signing gates have passed. The status
is changed to a dated release only after the signed artifacts and checksums are
published.

### Added

- Local-first Tasks with dates, plans, checklists, single reminders, snooze
  actions, reorder, completion review, reopen, archive to Past, and 30-day
  Recently Deleted recovery.
- One continuous editable Past document with native text selection, conversion
  back to a task, undo/redo, provenance-aware block history, and scoped ZIP
  exports.
- Notes with folders, pinning, lists and checklists, selection-to-task,
  multi-select move/export/delete, and portable exports.
- Offline Help and full Simplified Chinese, English, Japanese, and Russian UI.
- `.dgbak` backup inspection, optional on-device encryption, safe
  replace restore, conflict-aware merge restore, best-effort daily backups, and
  readable Markdown + JSON portable exports.
- Branded Android and iOS launch surfaces, launcher icons, GitHub press assets,
  deterministic Golden screenshots, and accessibility targets of at least
  44 dp for primary controls.
- Android APK/AAB and unsigned iOS CI build definitions with source and final
  artifact privacy gates.

### Privacy

- No accounts, advertisements, analytics, Firebase, AI calls, or application
  backend.
- Android does not request `INTERNET`, exact-alarm, or full-screen intent
  permissions and excludes app data from system cloud backup/device transfer.
- iOS has no push, CloudKit, background-network, or network capability; the app
  marks its private support directory as excluded from system backup on a
  best-effort basis.

### Known platform limits

- iOS is delivered as complete source plus unsigned build evidence; this
  release does not include an IPA or TestFlight distribution.
- Daily backups reconcile when the app starts or returns to the foreground;
  mobile operating systems do not guarantee an exact closed-app execution time.
- Local reminder delivery is intentionally inexact and can be delayed by OS or
  manufacturer power-management policies.
- Danggui is intentionally single-device and has no synchronization service.
