<p align="center">
  <img src="../assets/brand/danggui-app-icon-source.png" width="152" alt="当帰アプリアイコン" />
</p>

<h1 align="center">当归</h1>

<p align="center"><strong>ローカル記録・アップロードなし・AI 不使用</strong></p>

<p align="center">
  <a href="../../README.md">简体中文</a> ·
  <a href="README.en.md">English</a> ·
  <strong>日本語</strong> ·
  <a href="README.ru.md">Русский</a>
</p>

> [!IMPORTANT]
> 当归 [v1.1.2](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.2) は独立した **Pre-release（公開プレリリース）**として提供します。Android では正式署名済みインストールパッケージを提供します。iOS は決定的なソース ZIP と未署名ビルドの証跡のみで、IPA/TestFlight は提供しません。実機でのリリース受け入れ試験は未完了のため、安定版ではありません。既存の v1.1.0 とその添付ファイルは引き続き保持します。

## 静かでローカルファーストな記録アプリ

当归は、タスク、完了後の長期記録、独立したノートを一つの流れにまとめます。アカウント、アップロード、AI、広告、分析、ユーザープロファイリングは使用しません。

- 日付、計画、チェックリスト、カード上に表示される 1 件のローカル通知を持つタスク。
- 完了したタスクを、編集可能な一つの長い「過去」文書へ追加。
- 1 階層フォルダー、ピン留め、リスト、チェック項目、タスク変換に対応するノート。
- SQLite トランザクション、移行、整合性検査、任意暗号化の `.dgbak` バックアップ、マージ/置換復元、Markdown + JSON の可読エクスポート。
- 詳細なオフラインヘルプと、簡体字中国語・英語・日本語・ロシア語 UI。システム追従と手動切り替えに対応。
- v1.1.2 では通知を 1 分単位で設定でき、保存結果を明示し、「過去」の各イベントを 1 行で表示します。ネイティブ側は紙色だけを表示し、完全な Flutter 起動画面を唯一のブランド画面として 1.2 秒以上表示します。

## プレビュー

<p align="center">
  <img src="../assets/screenshots/danggui-ui-overview-v1.png" width="920" alt="当归の主要 13 画面" />
</p>

## 配布

| プラットフォーム | 提供内容 |
| --- | --- |
| Android | [v1.1.2 Pre-release](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.2) から、正式署名済みの汎用/ABI 別 APK と AAB を提供 |
| iOS | 決定的な `danggui-ios-source-v1.1.2.zip`、Xcode プロジェクト、および未署名 `Runner.app` のビルド証跡。IPA/TestFlight は提供しない |

一般の Android ユーザーは `danggui-android-universal-release.apk` をダウンロードしてください。ABI 別 APK は端末の ABI が分かるユーザー向け、AAB はストアまたは管理配布向けです。Pre-release には `SHA256SUMS` と署名証明書の SHA-256 フィンガープリントも添付されているため、インストール前に両方を照合してください。詳細は[プラットフォーム配布ガイド](../architecture/platform-delivery.md)、[iOS ソースビルド手順](../architecture/ios-source-build.md)、[v1.1.2 リリースチェックリスト](../release/v1.1.2-release-checklist.md)をご覧ください。

## Pre-release の受け入れ試験状況

自動受け入れ試験では、Android API 24 と API 36 で同一バージョン・同一署名による上書きインストールを実行済みです。6 つのデータ領域にまたがる 37 項目の保持、SQLite の `quick_check` と外部キー整合性、AlarmManager のスケジュール、実際のシステム通知、および API 36 の実際の通知権限フローを検証しています。

実機での OEM ごとの挙動、ロック画面通知、音、バイブレーション、スヌーズ、および公開済み v1.1.0 からの上書き更新の最終署名は未完了です。そのため v1.1.2 は Pre-release のままであり、安定版ではありません。

アプリはアカウントを要求せず、広告・分析・Firebase・AI・追跡 SDK を含みません。ユーザーデータはアプリのサンドボックスとユーザーが選択したローカルバックアップ先に保存され、Android は `INTERNET` 権限を要求しません。ソースコードは [Apache-2.0](../../LICENSE) で提供します。第三者ソフトウェアと同梱フォントには各ライセンスが適用されます（[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)）。名称、アイコン、起動画面などのブランド資産は Apache-2.0 の対象外で、権利を留保します（[ブランド説明](../../TRADEMARKS.md)）。
