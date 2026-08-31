<p align="center">
  <img src="../assets/brand/danggui-readme-hero.png" width="100%" alt="小さな球が点の軌跡をたどり、芽へ向かう当归の手描きバナー" />
</p>

<h1 align="center">当归</h1>

<p align="center">
  <strong>小さな積み重ねを、自分で読める軌跡へ。</strong><br />
  計画、リマインダー、行動、過往、ノートを結ぶ、静かなローカルファーストのワークフロー。
</p>

<p align="center">
  <a href="../../README.md">简体中文</a> ·
  <a href="README.en.md">English</a> ·
  <strong>日本語</strong> ·
  <a href="README.ru.md">Русский</a>
</p>

<p align="center">
  <img alt="バージョン：v1.1.5 安定版" src="https://img.shields.io/badge/version-v1.1.5%20stable-6F8068?style=flat-square" />
  <img alt="プラットフォーム：Android と iOS ソース" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20source-6F8068?style=flat-square" />
  <img alt="データ：ローカルファースト、可搬" src="https://img.shields.io/badge/data-local--first%20%7C%20portable-81786F?style=flat-square" />
  <img alt="ライセンス：Apache 2.0" src="https://img.shields.io/badge/code-Apache--2.0-2E2925?style=flat-square" />
</p>

<p align="center">
  <a href="https://danggui.hujizhou35.workers.dev/ja"><strong>公式サイト</strong></a> ·
  <a href="https://danggui.hujizhou35.workers.dev/ja/download">アプリを入手</a> ·
  <a href="#プレビュー">プレビュー</a> ·
  <a href="#データとプライバシー">プライバシー</a> ·
  <a href="#参加する">参加する</a>
</p>

## やることを並べるだけではない

まだ起きていないことだけを見る道具もあれば、すでに起きたことだけを残す道具もあります。当归はその両端をつなぎます。計画を立て、必要なときにローカル通知を受け取り、完了した行動を「過往」に残し、ノートで考えを続けます。

計画はチェックした瞬間に消えず、記録は日記の中で眠り続ける必要もありません。毎日の小さな出来事が、読めて、持ち出せて、自分の手で理解できる生活の材料へ育っていきます。

| 計画 | 行動 | 振り返り | 自分を理解する |
| --- | --- | --- | --- |
| 日付、チェックリスト、通知で次の一歩を決める | 事項を進め、完了時に振り返る | 完了記録を編集可能な「過往」へ加える | Markdown + JSON を書き出し、保存先や分析方法を自分で選ぶ |

> 当归には AI を内蔵せず、データを AI サービスへ自動送信することもありません。アプリが行うのは、ローカルで記録を整理し、読みやすい形式で書き出すことだけです。外部 AI に渡すか、どの道具で何を分析するかは、常にユーザーが決めます。

## プレビュー

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/01-plan.png" width="880" alt="当归の起動、事項、通知のワークフロー" />
</p>
<p align="center"><sub>球と芽から始まり、思いつきを今日の一歩へ変えます。</sub></p>

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/02-reflect.png" width="880" alt="当归の完了と過往のワークフロー" />
</p>
<p align="center"><sub>完了は削除ではありません。行動は、編集できる「過往」へ積み重なります。</sub></p>

<p align="center">
  <img src="../assets/screenshots/v1.1.2/en/03-export.png" width="880" alt="当归のノートと可読エクスポートのワークフロー" />
</p>
<p align="center"><sub>ノートは思考を残し、可読エクスポートはデータの主導権を守ります。</sub></p>

暖かな紙色、セージグリーン、テラコッタを用い、控えめな動きと余白で記録の負担を軽くしています。画像はデザイン案ではなく、実際の v1.1.2 アプリから取得したものです。

## 一続きのパーソナルワークフロー

- **事項と通知：** 日付、計画、チェックリスト、1 件のローカル通知。通知時刻は事項カードに表示されます。
- **完了と「過往」：** 完了時に振り返り、記録を継続的に育つ、自由に編集できる「過往」へ追加します。
- **行動につながるノート：** フォルダー、ピン留め、リスト、チェック項目で整理し、内容を事項へ変換できます。
- **持ち出せるデータ：** Markdown + JSON の可読 ZIP を作成し、長期保存、移行、選んだ外部ツールでの分析に使えます。完全な復元には、任意で暗号化できる `.dgbak` バックアップを使用します。
- **オフラインでも完結：** アプリ内ヘルプと、簡体字中国語・英語・日本語・ロシア語 UI。システム追従と手動切り替えに対応します。

## データとプライバシー

当归のプライバシー方針は、確認できる製品上の境界です。

- アカウントは不要で、動作にアプリ用バックエンドを必要としません。
- 広告、利用分析、クラッシュテレメトリー、Firebase、AI、追跡 SDK を組み込みません。
- 本番用 Android マニフェストは `INTERNET` 権限を宣言しません。
- 内容はアプリのサンドボックスと、ユーザーが明示的に選んだローカル保存先に残ります。GitHub やその他のサービスへ自動送信しません。
- 可読エクスポートはローカルで生成します。可搬性のため意図的に未暗号化 ZIP としているので、機密データは慎重に扱ってください。暗号化保存には `.dgbak` バックアップを使用します。

検証可能な詳細は[可読エクスポート仕様](../portable-export-format.md)と[プラットフォーム・プライバシー監査](../qa/privacy-platform-audit.md)をご覧ください。

## ダウンロード

現在の入手方法、公開バージョンの状態、iPhone 版の準備状況は[公式サイトのダウンロードページ](https://danggui.hujizhou35.workers.dev/ja/download)をご確認ください。以下には検証用として、現在の Release、チェックサム、ソースビルド手順、バージョン情報を残しています。

| プラットフォーム | 推奨入口 | 現在の提供内容 |
| --- | --- | --- |
| Android 7.0 以降 | [v1.1.5 安定版](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.5) | 正式署名済み汎用 APK。通常は `danggui-android-universal-release.apk` を選択 |
| iOS | [ソースビルド手順](../architecture/ios-source-build.md) | 完全な Xcode ソースと未署名ビルド証跡。IPA/TestFlight は提供しない |

v1.1.5 は現在推奨される **安定版** です。Android には正式署名済み universal APK があり、iOS は完全なソースと未署名ビルド証拠のみで、IPA と TestFlight はありません。安定版という状態は検証範囲を広げません。`contract-proven`、`simulator-proven`、`device-unverified` は区別され、実機 iPhone の音、触覚、消音／集中モード、夜間ロック画面、再起動、プロセス終了後の配信は未検証です。導入前にバックアップを作成し、同じ Release の `SHA256SUMS` で照合してください。開発者向け証跡は `danggui-developer-assets-v1.1.5.zip` に収録します。詳細は[配布ガイド](../architecture/platform-delivery.md)と [v1.1.5 チェックリスト](../release/v1.1.5-release-checklist.md)を参照してください。

## バージョンの歩み

| バージョン | この一歩で加わったもの |
| --- | --- |
| [v1.0.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.0.0) | 事項、通知、過往、ノート、バックアップ、可読エクスポートのローカル基盤を確立。 |
| [v1.1.0](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.0) | エディターとリマインダーのライフサイクルを安定させ、球と芽の完全な起動体験を復元。 |
| [v1.1.2](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.2) | 1 分単位の通知選択と明確な保存フィードバックを追加し、「過往」をコンパクトにして重複する起動画面を解消。 |
| [v1.1.3](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.3) | 音付きリマインダーをネイティブアラームへ移行し、権限ガイド、長いページの高速スクロールバー、消えないフィードバックの修正を追加。 |
| [v1.1.4](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.4) | Android の直接アラーム経路、両プラットフォームの revision 取引、15 分の期限切れ語義、監査可能なスナップショットを強化。 |
| [v1.1.5](https://github.com/hujizhou35-cmd/danggui-app/releases/tag/v1.1.5) | 固定した参照資料で iOS 全機能を監査し、通知 ID、復旧、タイムゾーン、保護されたローカルデータを強化。2 系統の Simulator ゲートを追加。 |

全変更は [CHANGELOG](../../CHANGELOG.md) をご覧ください。

## 参加する

当归はさまざまな参加を歓迎します。

- [Issues](https://github.com/hujizhou35-cmd/danggui-app/issues) で再現可能な不具合を報告する、または焦点を絞った機能を提案する。
- [Discussions](https://github.com/hujizhou35-cmd/danggui-app/discussions) でワークフローを共有する、質問する、アイデアを話し合う。
- リポジトリを Fork し、自分のブランチで変更して Pull Request を送る。外部のコントリビューターにメインリポジトリへの直接書き込み権限は付与しません。
- 翻訳、アクセシビリティ、さまざまな Android 端末での通知動作を確認する。

最初に[コントリビューションガイド](../../CONTRIBUTING.md)と[セキュリティポリシー](../../SECURITY.md)をお読みください。Issue、Discussion、Pull Request に実際の事項、ノート、データベース、バックアップ、パスワード、証明書、個人情報を含めないでください。

## ライセンスとブランド

ソースコードは [Apache License 2.0](../../LICENSE) で提供します。第三者ソフトウェアと同梱フォントにはそれぞれのライセンスが適用されます（[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)）。「当归」の名称、アイコン、起動イラストなどのブランド資産は Apache-2.0 の対象外で、権利を留保します。変更版を配布する場合は、[TRADEMARKS.md](../../TRADEMARKS.md) に従ってこれらの資産を削除または置換してください。
