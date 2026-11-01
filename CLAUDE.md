# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> このファイルは日本語版（Claude Code が読み込む本体）です。英語の参照用コピーは `CLAUDE.en.md` にあります。内容を変えるときは両方をそろえてください。

## プロジェクト概要

SwiftUI + SwiftData で作った、単一ターゲットの iOS 個人用タスク管理アプリ（UI は日本語）。オーナーは Swift を勉強中なので、**返答は日本語**で行う。コンセプトは **「とにかくシンプルでわかりやすく」**。操作部品が増える機能はオーナーが不要と判断した実績がある（カテゴリの長押しドラッグ並べ替えは、作ったあとに削除された）ため、機能を足すより画面を簡素に保つ方向で考える。

テストも lint も外部パッケージも無い。プロジェクトの開発言語は `ja`（`developmentRegion = ja`）。`en` に戻すと、「編集」「削除」や日付など iOS 標準の部品の文字が英語で出る。デプロイ先は iOS 26.5、Swift は 5 モード、`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（コードは基本すべて `@MainActor`）。

## ビルドと実行

`xcode-select` が CommandLineTools を指しているため、`DEVELOPER_DIR` を指定しないと `xcodebuild` や `simctl` が失敗する。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project test_app.xcodeproj -scheme test_app \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath <dir> build
xcrun simctl list devices available        # iOS 26.5 の端末を選ぶ（例: iPhone 17）
xcrun simctl install <udid> <dir>/Build/Products/Debug-iphonesimulator/test_app.app
xcrun simctl launch <udid> koki.test-app
```

Claude Code のサンドボックス内から実行する場合、`xcodebuild` と `simctl` はシミュレーターのデータフォルダに書き込むため、サンドボックスを無効にする必要がある。

- `test_app` フォルダは「ファイルシステム同期グループ」。新しい `.swift` ファイルは自動でビルド対象になり、`pbxproj` の編集は不要。ただし、Xcode を開いたまま外部からファイルを追加すると、Xcode が認識せず「Cannot find type 'TaskItem' in scope」が大量に出ることがある。何かファイルを開き直すか Xcode を再起動すれば直る。CLI のビルド結果を正とする。
- ホーム画面の名前は `INFOPLIST_KEY_CFBundleDisplayName`（オーナーが設定済み）。`PRODUCT_BUNDLE_IDENTIFIER`（`koki.test-app`）は**変更しない**。シミュレーターや実機のデータがこの ID に紐づいているため。
- 無料の Apple ID で署名した実機ビルドは7日で期限が切れる。通知はローカル通知のみで、有料アカウントは不要。ウィジェット用の App Group も、無料アカウントの実機署名で使えることを確認済み（2026-10-31）。

## UI 変更の確認方法

UI の自動操作はできない（`simctl` はタップできず、AppleScript / System Events は許可されていない。許可を求めないこと）。これまで使った方法は次の通り。

1. `test_appApp.swift` を一時的に書き換え、(a) `.modelContainer(PreviewData.container)` を使い、(b) ルートの画面を `UserDefaults.standard.string(forKey: "screen")` で切り替える。
2. `xcrun simctl launch <udid> koki.test-app -screen <名前>` で起動する。起動引数は UserDefaults に入るので、`-progressPeriod week` のように `@AppStorage` の値も指定できる。
3. `xcrun simctl io <udid> screenshot` で画面を撮って見る。
4. **終わったら必ず `test_appApp.swift` を元に戻して**、再ビルドして通ることを確認する。

データ層のロジックは、一時的な `print("PROBE …")` を入れて `simctl launch --console-pty` で確認できる。

## アーキテクチャ

永続化は SwiftData のみ（端末内の SQLite。サーバーは無い）。`test_appApp` が `ModelContainer(for: TaskItem.self)` を作る。`init()` で先に Application Support フォルダを作っている（無いと初回起動時に CoreData の「Failed to stat path」エラーが大量に出る）。あわせて、アプリを開いている間も通知をバナー表示するために `NotificationDelegate` を設定している。

モデル（`Models/`）:
- `TaskItem` — 1つの `@Model` で、別テーブルではなく状態フラグで管理する。`isDone`、`isArchived`（と `archivedAt`）、`deletedAt`（ソフト削除＝ゴミ箱）。**`isDeleted` という名前は使えない**（`PersistentModel` と衝突する）。アーカイブされておらず `deletedAt == nil` のものを「生きているタスク」と呼ぶ。
- `TaskCategory` — ユーザーが編集できる `@Model`（名前、SF Symbol、`CategoryColor`、`sortOrder`）。`TaskItem.taskCategory` との関係は `deleteRule: .nullify`。カテゴリを消してもタスクは残り「未分類」になる。標準の4つは初回に1度だけ作る（`@AppStorage("didSeedCategories")` で管理）。
- 期限: 新規タスクの期限は、初期値が今日。編集画面の「期限を指定」トグルで外せる（外すと `dueDate == nil`）。`hasDueTime == false` のとき `dueDate` はその日の 0:00、`true` のときは正確な時刻。`isOverdue` と `dueLabel` がこの違いを扱っているので、`dueDate` を直接比較せず、これらを使う。
- 繰り返し: 時計アプリのアラームと同じ曜日指定（`RepeatDays`、OptionSet。`TaskItem.repeatMask` にビットで保存。曜日は Calendar と同じ 1=日曜）。期限があるときだけ設定できる。**完了したら次の回を1つ作る**方式で、`TaskItem.toggle()` の中で `modelContext` に挿入する。次の期限は「期限の日と完了した日の遅いほう」より後で最初に当てはまる曜日（さぼった日の分は溜めない）。同じシリーズは `seriesID` でつなぐ。完了を取り消すと、そのとき作った次の回（未完了で、期限が一致するもの）を消す。
- `PreviewData.container` — サンプルデータ入りのメモリ上コンテナを1つだけ作り、すべての `#Preview` で使い回す（プレビューごとにコンテナを作ると、プレビューがクラッシュした）。

ビュー（`Views/` と、メイン一覧の `ContentView.swift`）:
- `ContentView` はフィルタなしの `@Query`（`allTasks`）を1つだけ持ち、すべてメモリ上で絞り込む。表示する一覧（生きているタスク、完了状態の絞り込み、カテゴリのチップ、検索。並びは未完了→期限→優先度）と、期間ごとの進捗（`stats(for:)`）の両方を、ここから導く。進捗は、期限が今日・今週・今月に入るタスクを数える。**アーカイブ済みは含み、ゴミ箱のものは除き、期限のないタスクは数えない。** `ProgressHeader` は `ProgressPeriod` ごとのページを持つ、スワイプ可能な `TabView`。選んだ期間は `@AppStorage("progressPeriod")` に保存される。
- 自動アーカイブ: 完了したタスク（繰り返しに限らない）は、完了した日が過ぎると `ContentView.archiveFinishedTasks()` が自動でアーカイブする（`tidyUp()` から。起動時・scenePhase の `.active`・日付変更時）。一覧に完了済みが溜まらないようにするため。`completedAt` が nil の古い完了済みもしまわれる。手動の「完了済みをアーカイブ」も残している。そのため、アーカイブの「未完了に戻す」（`unarchive()`）は未完了にも戻す（完了済みのままだと、すぐ自動アーカイブされて戻ってしまうため）。
- アーカイブ画面（`ArchiveView`）とゴミ箱画面（`TrashView`）は、ツールバーの「…」メニューから `navigationDestination(isPresented:)` で開く。スワイプやコンテキストメニューの操作は、モデルの `archive()` / `unarchive()` / `moveToTrash()` / `restore()` を呼ぶ。完全削除（`context.delete`）はゴミ箱からだけ行う。例外として、ゴミ箱に入れてから30日（`TaskItem.trashRetentionDays`）たったタスクは `ContentView.purgeOldTrash()` が自動で完全削除する。ゴミ箱の行には残り日数（`daysUntilPurge`）を出している。
- キーボード: `KeyboardDismisser`（`ContentView` の `.background`）が、ウインドウ全体に UIKit のタップ認識を1つ付け、文字の入力欄以外をタップしたら `endEditing` する。シートも同じウインドウなので編集画面にも効く。入力欄そのもののタップと、ボタンなどの操作は邪魔しない。
- `TaskEditorSheet` と `CategoryEditorSheet` は、新規作成と編集の両方に使う（`task` / `category` が nil なら新規）。タスク編集のカテゴリ選択は、Picker ではなくチップの並び（一覧の絞り込みと共通の `CategoryChip`）。半分の高さのシートでキーボードが出ると、カテゴリの欄が隠れたため。

通知（`Models/NotificationScheduler.swift`、画面は `NotificationSettingsView`）: 朝の通知は**内容が固定のローカル通知**。そのため、タスクや設定が変わるたび、またはアプリを開くたびに、`ContentView` が今後14日分を予約し直す（`.task(id: syncSignature)` と scenePhase の `.active`）。文面は予約した時点で作る（「今日のタスクは N件です（期限切れ M件）」）。その日が期限の未完了タスクに加え、その日より前に期限が切れた未完了タスクも数える。どちらも無い日は通知しない。自動の予約では許可ダイアログを出さない。出すのは、設定画面のトグルと「5分後にテスト通知を送る」ボタンだけ。

ウィジェット（`TodayWidget/`、ターゲット `TodayWidgetExtension`、bundle ID `koki.test-app.TodayWidget`）: 今日の進捗と残りのタスクを、ロック画面（丸形・長方形）とホーム画面（小・中）に出す。**ウィジェットは SwiftData を読まない。** アプリが期限つきタスクの写し（`Shared/TodaySnapshot.swift`）を App Group `group.koki.test-app` の UserDefaults に JSON で置き、ウィジェットはそれだけを読む（SwiftData の保存場所を移さずに済ませるため）。書き出しは `TodaySnapshot.update(from:)`（`Models/WidgetSync.swift`）で、通知と同じ `ContentView` の `.task(id: syncSignature)` と scenePhase の `.active` から呼ぶ。内容が変わったときだけ保存して `reloadAllTimelines()` する。タイムラインは「今」と今後7日分の 0:00。`Shared/` は両方のターゲットに入っている同期グループ。ウィジェットのターゲットには `SWIFT_DEFAULT_ACTOR_ISOLATION` を設定していない（`Shared/` の型は `nonisolated`）。エンタイトルメントはルートの `test_app.entitlements` / `TodayWidget.entitlements`、ウィジェットの Info.plist はルートの `TodayWidget-Info.plist`（同期フォルダに置くと Resources にコピーされて衝突するため）。

## ハマりどころ

- **`@Query(filter: #Predicate { $0.isArchived == true })` は使わない。** 遷移先の画面で、CPU 100% のままアプリが固まった。全件を取得してメモリ上で絞り込む（`ArchiveView`、`TrashView`、`ContentView`）。
- **`VersionedSchema` は使っていない。** プロパティを足すときは、必ずデフォルト値（`var isArchived: Bool = false`）か Optional にする。プロパティの削除や型変更をすると、そのデータが消える（カテゴリを enum からモデルにしたとき、古い `category` が失われた）。移行の確認は、新しいビルドを、前回のシミュレーターのデータの上に入れて行う。
- `List` の行の中にチップを置くと、長押しで行ごと持ち上がる。`List` の外に出すと、大見出しのレイアウトが崩れる。カテゴリの並べ替えは、今は `CategoryManagerView` の「編集」ボタン（`EditButton`）だけ。
- 進捗カード、完了状態の切り替え、チップの並びを `List` の中で平らに置くために、`.listRowInsets(.init())` と `.listRowBackground(Color.clear)` を使っている。
