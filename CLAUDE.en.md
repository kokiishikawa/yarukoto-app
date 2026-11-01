# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> English reference copy. The Japanese `CLAUDE.md` is the file Claude Code loads — keep the two in sync.

## Project

Single-target SwiftUI + SwiftData iOS app: a personal task manager (Japanese UI). The owner is learning Swift; reply in Japanese. The stated concept is **「とにかくシンプルでわかりやすく」** — the owner has rejected features that add UI complexity (e.g. long-press drag reordering of categories was built and then removed), so prefer fewer controls over more.

No tests, no linter, no package dependencies. The project's development language is `ja` (`developmentRegion = ja`); switching back to `en` makes iOS system components (Edit/Delete buttons, dates) show English. Deployment target is iOS 26.5, Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (everything is `@MainActor` by default).

## Build / run

`xcode-select` points at CommandLineTools, so `xcodebuild`/`simctl` fail unless you set `DEVELOPER_DIR`:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project test_app.xcodeproj -scheme test_app \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath <dir> build
xcrun simctl list devices available        # pick an iOS 26.5 device (e.g. iPhone 17)
xcrun simctl install <udid> <dir>/Build/Products/Debug-iphonesimulator/test_app.app
xcrun simctl launch <udid> koki.test-app
```

When running from Claude Code's sandbox, `xcodebuild`/`simctl` need the sandbox disabled to write to the simulator's data directory.

- The `test_app` folder is a file-system-synchronized group: new `.swift` files are picked up automatically, no `pbxproj` edit needed. A running Xcode may not notice files added externally ("Cannot find type 'TaskItem' in scope" everywhere) — opening any file or restarting Xcode fixes it; the CLI build is the source of truth.
- Home-screen name is `INFOPLIST_KEY_CFBundleDisplayName` (set by the owner). Never change `PRODUCT_BUNDLE_IDENTIFIER` (`koki.test-app`): the simulator/device store is keyed to it.
- Free Apple ID signing → device builds expire after 7 days. Notifications are local only (no paid account needed). The widget's App Group also signs fine on a device with the free account (confirmed 2026-10-31).

## Verifying UI changes

There is no UI automation (`simctl` cannot tap; AppleScript/System Events is not authorized — don't request it). Pattern used so far: temporarily edit `test_appApp.swift` to (a) use `.modelContainer(PreviewData.container)` and (b) switch the root view on `UserDefaults.standard.string(forKey: "screen")`, launch with `xcrun simctl launch <udid> koki.test-app -screen <name>` (launch args populate UserDefaults, so `-progressPeriod week` also works for `@AppStorage`), then `xcrun simctl io <udid> screenshot`. **Always revert `test_appApp.swift` afterwards** and rebuild. Data-layer logic can be checked the same way with a temporary `print("PROBE …")` and `launch --console-pty`.

## Architecture

Persistence is SwiftData only (on-device SQLite, no server). `test_appApp` creates `ModelContainer(for: TaskItem.self)` and first creates the Application Support directory in `init()` (otherwise first launch spams CoreData "Failed to stat path" errors). It also installs `NotificationDelegate` so banners show in the foreground.

Models (`Models/`):
- `TaskItem` — one `@Model` with state flags rather than separate tables: `isDone`, `isArchived` (+`archivedAt`), `deletedAt` (soft delete = trash; **do not name it `isDeleted`**, that collides with `PersistentModel`). A task is "live" when `!isArchived && deletedAt == nil`.
- `TaskCategory` — user-editable `@Model` (name, SF Symbol, `CategoryColor`, `sortOrder`). Relationship `TaskItem.taskCategory` with `deleteRule: .nullify`, so deleting a category leaves tasks as「未分類」. Four defaults are seeded once, guarded by `@AppStorage("didSeedCategories")`.
- Due dates: every new task defaults to today; the editor's 「期限を指定」 toggle removes it (`dueDate == nil`). `dueDate` is the day's 0:00 when `hasDueTime == false`, otherwise the exact time. `isOverdue`/`dueLabel` encode that; use them instead of comparing `dueDate` directly.
- Repeat: weekday sets like the Clock app's alarm repeat (`RepeatDays`, an OptionSet stored as bits in `TaskItem.repeatMask`; weekday numbering matches Calendar, 1 = Sunday). Only available when the task has a due date. **Completing a repeating task creates the next occurrence**, inserted into `modelContext` inside `TaskItem.toggle()`. The next due date is the first matching weekday after the later of the due day and the completion day (missed days don't pile up). Occurrences share a `seriesID`. Un-completing deletes the occurrence it created (undone, with the matching due date).
- `PreviewData.container` — one shared in-memory container with sample rows for every `#Preview` (creating a fresh container per preview crashed the preview process).

Views (`Views/`, plus `ContentView.swift` as the main list):
- `ContentView` runs one unfiltered `@Query` (`allTasks`) and derives everything in memory: the visible list (live tasks, status filter, category chip, search; sorted undone→due→priority), and per-period progress via `stats(for:)`. Progress counts tasks whose `dueDate` falls in today/this week/this month, **including archived, excluding trashed**, and ignores tasks with no due date. `ProgressHeader` is a swipeable `TabView` page per `ProgressPeriod`; the selected period persists in `@AppStorage("progressPeriod")`.
- Auto-archive: any completed task (not just repeating ones) is archived once its completion day has passed by `ContentView.archiveFinishedTasks()` (via `tidyUp()`: on launch, scene-active, and day change), so finished tasks don't pile up in the list. Old done tasks with `completedAt == nil` are archived too. The manual 「完了済みをアーカイブ」 button stays. Because of this, the archive's 「未完了に戻す」 (`unarchive()`) also marks the task undone; otherwise it would be auto-archived again right away.
- Archive and trash screens (`ArchiveView`, `TrashView`) are pushed via `navigationDestination(isPresented:)` from the toolbar overflow menu; swipe/context-menu actions call `archive()/unarchive()/moveToTrash()/restore()` on the model. Permanent delete (`context.delete`) happens only from the trash. The one exception: tasks that have been in the trash for 30 days (`TaskItem.trashRetentionDays`) are permanently deleted automatically by `ContentView.purgeOldTrash()`; trash rows show the days left (`daysUntilPurge`).
- Keyboard: `KeyboardDismisser` (a `.background` on `ContentView`) adds one UIKit tap recognizer to the window and calls `endEditing` when the tap is outside a text input. Sheets share the window, so it covers the editors too. It ignores taps on the text inputs themselves and doesn't block buttons.
- `TaskEditorSheet` / `CategoryEditorSheet` double as create and edit screens (`task`/`category == nil` means create). Category selection in the task editor is a chip row (`CategoryChip`, shared with the list filter), not a Picker, because a half-height sheet with the keyboard up hid the category section.

Notifications (`Models/NotificationScheduler.swift`, UI in `NotificationSettingsView`): morning reminders are **static local notifications**, so `ContentView` re-schedules the next 14 days (task `.task(id: syncSignature)` + scene-active) whenever tasks/settings change; text is built at scheduling time ("今日のタスクは N件です（期限切れ M件）"); it counts undone tasks due that day plus undone tasks overdue before that day, and days with neither get no notification. Automatic scheduling never prompts for permission — only the settings toggle and the 5-minute test button do.


Widget (`TodayWidget/`, target `TodayWidgetExtension`, bundle ID `koki.test-app.TodayWidget`): shows today's progress and remaining tasks on the Lock Screen (circular, rectangular) and Home Screen (small, medium). **The widget never reads SwiftData.** The app writes a snapshot of tasks with due dates (`Shared/TodaySnapshot.swift`) as JSON into the App Group `group.koki.test-app` UserDefaults, and the widget reads only that (so the SwiftData store didn't have to move). `TodaySnapshot.update(from:)` (`Models/WidgetSync.swift`) is called from the same `ContentView` `.task(id: syncSignature)` + scene-active hook as notifications; it saves and calls `reloadAllTimelines()` only when the content changed. The timeline is "now" plus each midnight for the next 7 days. `Shared/` is a synchronized group in both targets. The widget target does not set `SWIFT_DEFAULT_ACTOR_ISOLATION` (types in `Shared/` are `nonisolated`). Entitlements are `test_app.entitlements` / `TodayWidget.entitlements` at the repo root, and the widget's Info.plist is the root `TodayWidget-Info.plist` (inside a synchronized folder it would be copied as a resource and collide).

## Gotchas learned the hard way

- **Do not use `@Query(filter: #Predicate { $0.isArchived == true })`** in a pushed view: it hung the app at 100% CPU. Query everything and filter in memory (`ArchiveView`, `TrashView`, `ContentView`).
- There is no `VersionedSchema`. Adding a property is safe only with a default value (`var isArchived: Bool = false`) or as optional; removing/retyping a property silently drops that data (the old enum `category` was lost when categories became a model). Test migrations by installing the new build over the previous simulator store.
- Chips placed inside a `List` row lift as a whole row on long press; moving them outside the `List` broke the large-title layout. Category reordering now exists only via the 「編集」 button (`EditButton`) in `CategoryManagerView`.
- `.listRowInsets(.init())` + `.listRowBackground(Color.clear)` is how the progress card, status picker and chip row sit flat inside the `List`.
