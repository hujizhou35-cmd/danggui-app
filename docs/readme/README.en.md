<p align="center">
  <img src="../assets/brand/danggui-readme-hero.png" width="100%" alt="Hand-drawn Danggui banner with a small ball following a dotted path toward a sprout" />
</p>

<h1 align="center">当归</h1>

<p align="center">
  <strong>Small steps become a life you can read.</strong><br />
  A quiet, local-first workflow for plans, reminders, actions, history, and notes.
</p>

<p align="center">
  <a href="../../README.md">简体中文</a> ·
  <strong>English</strong> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <img alt="Version: v1.1.5 stable release" src="https://img.shields.io/badge/version-v1.1.5%20stable-6F8068?style=flat-square" />
  <img alt="Platforms: Android and iOS source" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20source-6F8068?style=flat-square" />
  <img alt="Data: local-first and portable" src="https://img.shields.io/badge/data-local--first%20%7C%20portable-81786F?style=flat-square" />
  <img alt="License: Apache 2.0" src="https://img.shields.io/badge/code-Apache--2.0-2E2925?style=flat-square" />
</p>

<p align="center">
  <a href="https://danggui.hujizhou35.workers.dev/en"><strong>Official website</strong></a> ·
  <a href="https://danggui.hujizhou35.workers.dev/en/download">Get the app</a> ·
  <a href="#preview">Preview</a> ·
  <a href="#your-data-stays-yours">Privacy</a> ·
  <a href="#contributing">Contributing</a>
</p>

## More than a list of things to do

Some tools look only at what has not happened yet. Others preserve only what already has. Danggui connects both ends: make a plan, receive a local reminder when it matters, keep a trace when the work is done, and continue thinking in your notes.

Plans do not vanish when you check them off, and records do not have to sleep in a journal forever. Small daily actions gradually become a personal record you can read, carry with you, and understand on your own terms.

| Plan | Act | Reflect | Understand |
| --- | --- | --- | --- |
| Set the next step with dates, checklists, and reminders | Work through a task, complete it, and review | Append completed work to an editable Past | Export Markdown + JSON for the archive or analysis you choose |

> Danggui has no built-in AI and never uploads your data to an AI service automatically. It organizes and exports readable data locally. Whether to share an export with an external AI, which tool to use, and what to analyze are always your decisions.

## Preview

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/01-plan.png" width="880" alt="Danggui launch, tasks, and reminders workflow" />
</p>
<p align="center"><sub>Begin with the ball and sprout, then turn an idea into a step you can take today.</sub></p>

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/02-reflect.png" width="880" alt="Danggui completion and Past workflow" />
</p>
<p align="center"><sub>Completion is not deletion: actions settle into an editable Past.</sub></p>

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/03-export.png" width="880" alt="Danggui notes and portable export workflow" />
</p>
<p align="center"><sub>Notes preserve the thinking; readable exports keep the data truly yours.</sub></p>

Danggui uses warm paper, sage green, and terracotta red, with restrained motion and generous space to make recording feel lighter. These images come from the real v1.1.2 app rather than a design mockup.

## One continuous personal workflow

- **Tasks and reminders:** dates, plans, checklists, and one local reminder, with its time visible on the task card.
- **Completion and Past:** review work as you complete it, then append it to a continuously growing, freely editable Past.
- **Notes that can become action:** organize notes with folders, pinning, lists, and checkboxes, or turn content into a task.
- **Data you can take with you:** create a readable Markdown + JSON ZIP for long-term archiving, migration, or analysis in an external tool you select. Use an optionally encrypted `.dgbak` backup for full restoration.
- **Complete while offline:** built-in Help and a UI in Simplified Chinese, English, Japanese, and Russian, with system-following or manual language selection.

## Your data stays yours

Danggui's privacy position is a product boundary you can inspect:

- No account is required, and the app needs no application backend to run.
- No advertising, analytics, crash telemetry, Firebase, AI, or user-tracking SDK is integrated.
- The production Android manifest does not declare the `INTERNET` permission.
- Content remains in the app sandbox and local backup destinations you explicitly choose. The app does not upload it to GitHub or another service.
- Readable exports are generated locally. They are deliberately unencrypted ZIP files for portability, so protect sensitive exports; use an encrypted `.dgbak` backup when you need encrypted storage.

See the [portable export specification](../portable-export-format.md) and [platform privacy audit](../qa/privacy-platform-audit.md) for the verifiable details.

## Download

Use the [official download page](https://danggui.hujizhou35.workers.dev/en/download) for current ways to get Danggui, public release status, and iPhone availability. The current Release, checksums, source-build guidance, and version details remain below for verification.

| Platform | Recommended entry | Current delivery |
| --- | --- | --- |
| Android 7.0+ | [v1.1.5 Stable Release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.5) | Formally signed universal APK; most users want `danggui-android-universal-release.apk` |
| iOS | [Source build guide](../architecture/ios-source-build.md) | Complete Xcode source and unsigned build evidence; no IPA or TestFlight distribution |

v1.1.5 is the current recommended **Stable Release**. Android includes a formally signed universal APK; iOS remains complete source and unsigned-build evidence only, with no IPA or TestFlight build. Stable status does not expand the evidence boundary: `contract-proven`, `simulator-proven`, and `device-unverified` remain distinct, and physical-iPhone sound, haptics, silent/Focus modes, overnight lock-screen delivery, reboot, and process termination are still unverified. Back up existing data and verify files against `SHA256SUMS` from the same Release. Split APKs, the AAB, iOS evidence, and signing records are grouped in `danggui-developer-assets-v1.1.5.zip`. See the [delivery guide](../architecture/platform-delivery.md) and [v1.1.5 checklist](../release/v1.1.5-release-checklist.md).

## Version journey

| Version | What this step added |
| --- | --- |
| [v1.0.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.0.0) | Established the local foundation for tasks, reminders, Past, notes, backups, and readable exports. |
| [v1.1.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) | Strengthened editor and reminder lifecycle reliability and restored the complete ball-and-sprout launch experience. |
| [v1.1.2](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.2) | Added minute-by-minute reminder selection and explicit save feedback, compacted Past, and removed the duplicate launch composition. |
| [v1.1.3](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.3) | Upgraded sound reminders to native alarms, added in-app permission guidance and long-page fast scrollbars, and fixed feedback that stayed visible indefinitely. |
| [v1.1.4](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.4) | Hardened Android's direct ringing path, aligned revision transactions and the 15-minute expiry contract, and added auditable alarm snapshots and diagnostics. |
| [v1.1.5](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.5) | Audited the full iOS feature chain against fixed references, hardened reminder identity, recovery, time zones, and protected local data, and added dual-runtime Simulator gates. |

See the full [CHANGELOG](../../CHANGELOG.md).

## Contributing

There are several ways to help Danggui grow:

- Report a reproducible problem or propose a focused feature in [Issues](https://github.com/hujizhou35-cmd/danggui-app/issues).
- Share a workflow, ask a question, or explore an idea in [Discussions](https://github.com/hujizhou35-cmd/danggui-app/discussions).
- Fork the repository, make changes on your own branch, and open a Pull Request. Outside contributors do not receive direct write access to the main repository.
- Help review translations, accessibility, and reminder behavior on different Android devices.

Read the [contribution guide](../../CONTRIBUTING.md) and [security policy](../../SECURITY.md) first. Never include real tasks, notes, databases, backups, passwords, certificates, or personal information in an Issue, Discussion, or Pull Request.

## License and brand

Source code is licensed under [Apache License 2.0](../../LICENSE). Third-party software and the bundled font retain their own licenses; see [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). The Danggui name, icon, launch artwork, and other brand assets are not covered by Apache-2.0 and remain reserved. Distributors of modified builds must remove or replace those assets as described in [TRADEMARKS.md](../../TRADEMARKS.md).
