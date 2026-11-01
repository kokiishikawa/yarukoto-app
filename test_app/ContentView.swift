//
//  ContentView.swift
//  test_app
//

import SwiftUI
import SwiftData

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case active = "未完了"
    case done = "完了"

    var id: Self { self }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: [SortDescriptor(\TaskItem.createdAt, order: .reverse)])
    private var allTasks: [TaskItem]
    @Query(sort: [SortDescriptor(\TaskCategory.sortOrder), SortDescriptor(\TaskCategory.createdAt)])
    private var categories: [TaskCategory]

    @AppStorage("didSeedCategories") private var didSeedCategories = false
    @AppStorage("morningNotifyEnabled") private var notifyEnabled = false
    @AppStorage("morningNotifyMinutes") private var notifyMinutes = 8 * 60
    @AppStorage("progressPeriod") private var period: ProgressPeriod = .today

    @State private var filter: TaskFilter = .all
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var editorTarget: EditorTarget?
    @State private var showCategoryManager = false
    @State private var showArchive = false
    @State private var showTrash = false
    @State private var showNotificationSettings = false
    /// 今日の日付。日付が変わったら更新して一覧を作り直し、「今日」「明日」や期限切れの表示、進捗を新しい日付に合わせる。
    @State private var today = Calendar.current.startOfDay(for: .now)

    private enum EditorTarget: Identifiable {
        case new
        case edit(TaskItem)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let t): String(describing: t.persistentModelID)
            }
        }
    }

    /// 一覧に出すのはアーカイブしていないタスクだけ。
    private var tasks: [TaskItem] {
        allTasks.filter { !$0.isArchived && $0.deletedAt == nil }
    }

    /// 進捗はアーカイブ済みも含め、期限が指定の期間に入るタスクで集計する。
    private func stats(for period: ProgressPeriod) -> (done: Int, total: Int) {
        let scoped = allTasks.filter { $0.deletedAt == nil && period.contains($0.dueDate) }
        return (scoped.filter(\.isDone).count, scoped.count)
    }

    private struct SyncSignature: Hashable {
        var enabled: Bool
        var minutes: Int
        var tasks: [TaskKey]
    }

    private struct TaskKey: Hashable {
        var title: String
        var due: Date?
        var isDone: Bool
        var isTrashed: Bool
    }

    /// 通知とウィジェットの更新に使う中身。これが変わったら予約し直し、ウィジェットに渡し直す。
    private var syncSignature: SyncSignature {
        SyncSignature(
            enabled: notifyEnabled,
            minutes: notifyMinutes,
            tasks: allTasks.map {
                TaskKey(title: $0.title, due: $0.dueDate, isDone: $0.isDone, isTrashed: $0.deletedAt != nil)
            }
        )
    }

    private func syncOutside() async {
        TodaySnapshot.update(from: allTasks)
        await NotificationScheduler.rescheduleMorning(
            tasks: allTasks, enabled: notifyEnabled, minutes: notifyMinutes
        )
    }

    /// 起動時・アプリに戻ったとき・日付が変わったときの片付け。
    private func tidyUp() {
        let now = Calendar.current.startOfDay(for: .now)
        if now != today { today = now }
        archiveFinishedTasks()
        purgeOldTrash()
    }

    /// ゴミ箱に入れてから30日たったタスクは、完全に削除する。
    /// ゴミ箱の画面の「あと◯日」と同じく日付単位で数え、残りが0日になった日に消す。
    private func purgeOldTrash() {
        for task in allTasks where task.daysUntilPurge == 0 {
            context.delete(task)
        }
    }

    /// 完了したタスクは、完了した日が過ぎたらアーカイブへしまう。
    /// 一覧に完了済みが溜まらないようにするため。進捗はアーカイブ済みも数えるので変わらない。
    private func archiveFinishedTasks() {
        let today = Calendar.current.startOfDay(for: .now)
        for task in tasks where task.isDone && (task.completedAt ?? .distantPast) < today {
            task.archive()
        }
    }

    private var selectedCategory: TaskCategory? {
        categories.first { $0.persistentModelID == selectedCategoryID }
    }

    private var visibleTasks: [TaskItem] {
        tasks
            .filter { task in
                switch filter {
                case .all: true
                case .active: !task.isDone
                case .done: task.isDone
                }
            }
            .filter { selectedCategoryID == nil || $0.taskCategory?.persistentModelID == selectedCategoryID }
            .filter {
                searchText.isEmpty
                    || $0.title.localizedStandardContains(searchText)
                    || $0.note.localizedStandardContains(searchText)
            }
            .sorted { Self.order($0, $1) }
    }

    /// 未完了を先に、その中では期限が近い順→優先度が高い順。
    private static func order(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.isDone != b.isDone { return !a.isDone }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
        return a.createdAt > b.createdAt
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressHeader(period: $period, stats: stats(for:))
                        .listRowInsets(.init())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("フィルタ", selection: $filter) {
                        ForEach(TaskFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)

                    categoryChips
                        .listRowInsets(.init())
                        .listRowBackground(Color.clear)
                }

                Section {
                    if visibleTasks.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(visibleTasks) { task in
                        TaskRow(task: task)
                            .onTapGesture { editorTarget = .edit(task) }
                            .contextMenu {
                                Button("編集", systemImage: "pencil") { editorTarget = .edit(task) }
                                Button(
                                    task.isDone ? "未完了に戻す" : "完了にする",
                                    systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark"
                                ) {
                                    withAnimation(.snappy) { task.toggle() }
                                }
                                if task.isDone {
                                    Button("アーカイブ", systemImage: "archivebox") {
                                        withAnimation(.snappy) { task.archive() }
                                    }
                                }
                                Button("削除", systemImage: "trash", role: .destructive) {
                                    withAnimation { task.moveToTrash() }
                                }
                            } preview: {
                                TaskDetailPreview(task: task)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation(.snappy) { task.toggle() }
                                } label: {
                                    Label(
                                        task.isDone ? "未完了に戻す" : "完了",
                                        systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark"
                                    )
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                if task.isDone {
                                    Button {
                                        withAnimation(.snappy) { task.archive() }
                                    } label: {
                                        Label("アーカイブ", systemImage: "archivebox")
                                    }
                                    .tint(.orange)
                                }
                                Button(role: .destructive) {
                                    withAnimation { task.moveToTrash() }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    // 完了済みが見えているときだけ、翌日に自動でしまうことを伝える
                    if visibleTasks.contains(where: \.isDone) {
                        Text("完了したタスクは、翌日になると自動でアーカイブへ移動します。")
                    }
                }
            }
            .listStyle(.insetGrouped)
            // 日付が変わったら一覧を作り直す。行の表示（TaskRow）は、タスクが変わらないと描き直されないため
            .id(today)
            .animation(.smooth, value: visibleTasks.map(\.persistentModelID))
            .navigationTitle("タスク")
            .searchable(text: $searchText, prompt: "タスクを検索")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("追加", systemImage: "plus") { editorTarget = .new }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("完了済みをアーカイブ", systemImage: "archivebox") {
                        withAnimation {
                            tasks.filter(\.isDone).forEach { $0.archive() }
                        }
                    }
                    .disabled(!tasks.contains(where: \.isDone))
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("アーカイブを見る", systemImage: "tray.full") { showArchive = true }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("ゴミ箱を見る", systemImage: "trash") { showTrash = true }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("通知の設定", systemImage: "bell") { showNotificationSettings = true }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("カテゴリを管理", systemImage: "folder") { showCategoryManager = true }
                }
            }
            .navigationDestination(isPresented: $showArchive) { ArchiveView() }
            .navigationDestination(isPresented: $showTrash) { TrashView() }
            .sheet(item: $editorTarget) { target in
                switch target {
                case .new: TaskEditorSheet(task: nil, defaultCategory: selectedCategory)
                case .edit(let task): TaskEditorSheet(task: task)
                }
            }
            .sheet(isPresented: $showCategoryManager) { CategoryManagerView() }
            .sheet(isPresented: $showNotificationSettings) { NotificationSettingsView() }
            // 朝の通知とウィジェットは、タスクや設定が変わるたび・アプリを開くたびに更新する
            .task(id: syncSignature) { await syncOutside() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                tidyUp()
                Task { await syncOutside() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                tidyUp()
            }
            .task {
                tidyUp()
                // 初回のみ標準カテゴリを作成（ユーザーが全部消しても再作成しない）
                guard !didSeedCategories else { return }
                if categories.isEmpty { TaskCategory.seedDefaults(in: context) }
                didSeedCategories = true
            }
            .onChange(of: categories.map(\.persistentModelID)) { _, ids in
                if let id = selectedCategoryID, !ids.contains(id) { selectedCategoryID = nil }
            }
        }
        .background(KeyboardDismisser())
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    label: "すべて",
                    symbol: "square.grid.2x2",
                    color: .accentColor,
                    selected: selectedCategoryID == nil
                ) {
                    selectedCategoryID = nil
                }
                ForEach(categories) { c in
                    let isSelected = selectedCategoryID == c.persistentModelID
                    chip(
                        label: c.name,
                        symbol: c.symbol,
                        color: c.tint.color,
                        selected: isSelected
                    ) {
                        selectedCategoryID = isSelected ? nil : c.persistentModelID
                    }
                }
                chip(label: "追加", symbol: "plus", color: .secondary, selected: false) {
                    showCategoryManager = true
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled()
    }

    private func chip(
        label: String,
        symbol: String,
        color: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        CategoryChip(label: label, symbol: symbol, color: color, selected: selected, action: action)
    }

    @ViewBuilder
    private var emptyState: some View {
        if tasks.isEmpty {
            ContentUnavailableView {
                Label("タスクがありません", systemImage: "checklist")
            } description: {
                Text("右上の + から最初のタスクを追加しましょう。")
            } actions: {
                Button("タスクを追加") { editorTarget = .new }
                    .buttonStyle(.borderedProminent)
            }
        } else if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView("該当するタスクはありません", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
