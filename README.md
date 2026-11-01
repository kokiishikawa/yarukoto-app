# やることりすと

SwiftUI と SwiftData で作った、iPhone 向けの個人用タスク管理アプリです。
コンセプトは **「とにかくシンプルでわかりやすく」**。データはすべて端末の中に保存され、サーバーやアカウント登録は必要ありません。

## 主な機能

- **タスク管理**：タイトル・メモ・カテゴリ・優先度（低／中／高）・期限（日付だけ／時刻つき／なし）
- **進捗の表示**：今日・今週・今月に期限があるタスクの達成率を、左右にスワイプして切り替えて表示
- **絞り込みと検索**：すべて／未完了／完了、カテゴリ、キーワードで絞り込み
- **カテゴリ**：名前・アイコン・色を自由に作成・編集・並べ替え。削除してもタスクは「未分類」として残る
- **繰り返し**：時計アプリのアラームと同じく、曜日を選んで繰り返す（例：平日だけの筋トレ）。完了すると次の回が自動で作られる
- **アーカイブ**：完了したタスクは、翌日になると自動でアーカイブへ移動。「未完了に戻す」で一覧に戻せる
- **ゴミ箱**：削除したタスクは30日間ゴミ箱に残り、復元できる。30日たつと自動で完全に削除
- **朝の通知**：設定した時刻に、その日が期限のタスクと期限切れのタスクをお知らせ（ローカル通知）
- **ウィジェット**：今日の進捗と残りのタスクを、ロック画面（丸形・長方形）とホーム画面（小・中）に表示

## 動作環境

| 項目 | 内容 |
|---|---|
| 対応 OS | iOS 26.5 以降 |
| 開発環境 | Xcode 26.6 |
| 言語 | Swift 5（言語モード） |
| 使用フレームワーク | SwiftUI、SwiftData、WidgetKit、UserNotifications |
| 外部ライブラリ | なし |

## ビルドと実行

### Xcode から

1. `test_app.xcodeproj` を開く
2. スキーム `test_app` を選ぶ（ウィジェットも一緒にビルドされる）
3. シミュレーターか実機を選んで実行

実機で動かすときは、ターゲット `test_app` と `TodayWidgetExtension` の **Signing & Capabilities** で、自分のチームを選んでください。

### コマンドラインから

`xcode-select` が CommandLineTools を指している環境では、`DEVELOPER_DIR` を指定してください。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project test_app.xcodeproj -scheme test_app \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build build

xcrun simctl list devices available        # iOS 26.5 の端末を選ぶ
xcrun simctl install <udid> build/Build/Products/Debug-iphonesimulator/test_app.app
xcrun simctl launch <udid> koki.test-app
```

## 実機での注意

- **無料の Apple ID** でも実機にインストールできます。ただし署名の期限は **7日** で、切れたら Xcode から入れ直してください（データは残ります）。
- 通知はローカル通知、ウィジェットのデータ共有は App Group（`group.koki.test-app`）を使っており、どちらも無料アカウントで動作を確認済みです。
- Bundle ID（`koki.test-app`）は変更しないでください。端末に保存されたデータがこの ID に結びついています。

## フォルダ構成

```
.
├── test_app/                 アプリ本体
│   ├── test_appApp.swift     起動処理（データの保存先と通知の設定）
│   ├── ContentView.swift     メインのタスク一覧
│   ├── Models/               データと処理（タスク、カテゴリ、繰り返し、通知、ウィジェット連携）
│   └── Views/                各画面と部品（編集、アーカイブ、ゴミ箱、カテゴリ、通知設定 など）
├── TodayWidget/              ウィジェット（今日のタスク）
├── Shared/                   アプリとウィジェットの両方で使うコード
├── test_app.entitlements     アプリの権限（App Group）
├── TodayWidget.entitlements  ウィジェットの権限（App Group）
├── TodayWidget-Info.plist    ウィジェットの設定
└── CLAUDE.md                 設計の詳細と開発時の注意（英語版は CLAUDE.en.md）
```

設計の詳しい説明（データの持ち方、ハマりどころ、UI の確認方法など）は [CLAUDE.md](CLAUDE.md) にまとめています。
