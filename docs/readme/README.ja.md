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
> 当归は v1.0.0 の初回リリース準備段階です。Android パッケージは、署名・権限・チェックサム・すべてのリリースゲートに合格した後にのみ公開します。Releases ページに v1.0.0 がまだない場合、現在の提供物はソースコードであり、CI のデバッグ版は公式リリースではありません。iOS は完全なソースと未署名ビルドの証跡のみで、IPA/TestFlight は提供しません。

## 静かでローカルファーストな記録アプリ

当归は、タスク、完了後の長期記録、独立したノートを一つの流れにまとめます。アカウント、アップロード、AI、広告、分析、ユーザープロファイリングは使用しません。

- 日付、計画、チェックリスト、カード上に表示される 1 件のローカル通知を持つタスク。
- 完了したタスクを、編集可能な一つの長い「過去」文書へ追加。
- 1 階層フォルダー、ピン留め、リスト、チェック項目、タスク変換に対応するノート。
- SQLite トランザクション、移行、整合性検査、任意暗号化の `.dgbak` バックアップ、マージ/置換復元、Markdown + JSON の可読エクスポート。
- 詳細なオフラインヘルプと、簡体字中国語・英語・日本語・ロシア語 UI。システム追従と手動切り替えに対応。

## プレビュー

<p align="center">
  <img src="../assets/screenshots/danggui-ui-overview-v1.png" width="920" alt="当归の主要 13 画面" />
</p>

## 配布

| プラットフォーム | 提供内容 |
| --- | --- |
| Android | 全リリースゲート合格後、[GitHub Releases](https://github.com/hujizhou35-cmd/danggui-app/releases) に署名済みの汎用/ABI 別 APK と AAB を公開 |
| iOS | 完全なソース、Xcode プロジェクト、および未署名 `Runner.app` のビルド証跡。v1.0.0 では IPA/TestFlight を提供しない |

公式 Android リリースには `SHA256SUMS` と署名証明書の SHA-256 フィンガープリントを添付します。通常はファイル名に `universal-release.apk` を含む APK を選択してください。詳細は[プラットフォーム配布ガイド](../architecture/platform-delivery.md)と [v1.0.0 リリースチェックリスト](../release/v1.0.0-release-checklist.md)をご覧ください。

アプリはアカウントを要求せず、広告・分析・Firebase・AI・追跡 SDK を含みません。ユーザーデータはアプリのサンドボックスとユーザーが選択したローカルバックアップ先に保存され、Android は `INTERNET` 権限を要求しません。ソースコードは [Apache-2.0](../../LICENSE) で提供します。第三者ソフトウェアと同梱フォントには各ライセンスが適用されます（[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)）。名称、アイコン、起動画面などのブランド資産は Apache-2.0 の対象外で、権利を留保します（[ブランド説明](../../TRADEMARKS.md)）。
