<p align="center">
  <img src="../assets/brand/danggui-app-icon-source.png" width="152" alt="Danggui app icon" />
</p>

<h1 align="center">当归</h1>

<p align="center"><strong>Local records · No uploads · No AI</strong></p>

<p align="center">
  <a href="../../README.md">简体中文</a> ·
  <strong>English</strong> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ru.md">Русский</a>
</p>

> [!IMPORTANT]
> Danggui [v1.1.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) is publicly available as a **Pre-release**. Android receives formally signed install packages. iOS receives a deterministic source archive and unsigned build evidence only—no IPA or TestFlight distribution. Physical-device release acceptance is not yet complete, so this is not a stable release.

## A quiet, local-first place for plans and memories

Danggui combines tasks, a continuously growing history document, and independent notes without accounts, uploads, AI, analytics, ads, or profiling.

- Tasks with dates, plans, checklists, and one local reminder shown directly on each card.
- Completed tasks can be appended to an editable long-form history.
- Notes with one-level folders, pinning, lists, checkboxes, and task conversion.
- Transactional SQLite storage, migrations, integrity checks, optionally encrypted `.dgbak` backups, merge/replace restore, and readable Markdown + JSON exports.
- Detailed offline Help plus Simplified Chinese, English, Japanese, and Russian UI, with system-following and manual language selection.
- v1.1.0 keeps Tasks, Notes, and Past editable, defaults new tasks to today, exposes reminder lifecycle controls, and restores the complete branded one-second launch composition.

## Preview

<p align="center">
  <img src="../assets/screenshots/danggui-ui-overview-v1.png" width="920" alt="Overview of Danggui's 13 core screens" />
</p>

## Distribution

| Platform | Delivery |
| --- | --- |
| Android | Formally signed universal and split APKs plus AAB from the [v1.1.0 Pre-release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) |
| iOS | Deterministic `danggui-ios-source-v1.1.0.zip`, Xcode project, and unsigned `Runner.app` build evidence; no IPA or TestFlight distribution |

Most Android users should download `danggui-android-universal-release.apk`; split APKs are for users who know their device ABI, and the AAB is for store or managed distribution. The Pre-release also includes `SHA256SUMS` and the signing certificate SHA-256 fingerprint, both of which should be checked before installation. See the [platform delivery guide](../architecture/platform-delivery.md), [iOS source build guide](../architecture/ios-source-build.md), and [v1.1.0 release checklist](../release/v1.1.0-release-checklist.md).

## Pre-release acceptance status

Automated acceptance has exercised same-version, same-signature overlay installation on Android API 24 and API 36. It verifies 37 retention assertions across six data domains, SQLite `quick_check` and foreign-key integrity, AlarmManager scheduling, a real system notification, and the real notification-permission flow on API 36.

Acceptance is still outstanding for physical Android devices across OEM variants, lock-screen delivery, sound, vibration, and snooze, plus final sign-off of an overlay upgrade from the official v1.0.0 package. v1.1.0 therefore remains a Pre-release rather than a stable release.

## Privacy and license

The app does not require an account or runtime backend. It contains no advertising, analytics, Firebase, AI, or user-tracking SDK. User content stays in the app sandbox and user-selected local backups; Android packages do not request `INTERNET`. Source code is licensed under [Apache-2.0](../../LICENSE). Third-party software and the bundled font retain their own licenses; see [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). The Danggui name, icon, launch artwork, and other brand assets are not covered by Apache-2.0 and remain reserved; see [TRADEMARKS.md](../../TRADEMARKS.md).
