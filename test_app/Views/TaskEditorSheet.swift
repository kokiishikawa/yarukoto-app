//
//  TaskEditorSheet.swift
//  test_app
//

import SwiftUI
import SwiftData

/// 新規作成と編集の両方に使うシート。`task` が nil なら新規作成。
struct TaskEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TaskCategory.sortOrder), SortDescriptor(\TaskCategory.createdAt)])
    private var categories: [TaskCategory]

    let task: TaskItem?
    /// 新規作成時の初期カテゴリ（一覧で絞り込み中のカテゴリなど）。
    var defaultCategory: TaskCategory?

    @State private var title = ""
    @State private var note = ""
    @State private var priority: Priority = .medium
    @State private var category: TaskCategory?
    @State private var showNewCategory = false
    @State private var hasDue = true
    @State private var dueDate = Date.now
    @State private var hasTime = false
    @State private var repeatDays: RepeatDays = []
    @State private var loaded = false

    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)
                        .focused($titleFocused)
                    TextField("メモ", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("カテゴリ") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryChip(label: "未分類", symbol: "tray.fill", color: .gray,
                                         selected: category == nil) { category = nil }
                            ForEach(categories) { c in
                                CategoryChip(label: c.name, symbol: c.symbol, color: c.tint.color,
                                             selected: category?.persistentModelID == c.persistentModelID) {
                                    category = c
                                }
                            }
                            CategoryChip(label: "追加", symbol: "plus", color: .secondary,
                                         selected: false) { showNewCategory = true }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(.init())
                }

                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("期限を指定", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("日付", selection: $dueDate, displayedComponents: .date)
                        Toggle("時刻を指定", isOn: $hasTime.animation())
                        if hasTime {
                            DatePicker("時刻", selection: $dueDate, displayedComponents: .hourAndMinute)
                        }
                        NavigationLink {
                            RepeatPickerView(days: $repeatDays)
                        } label: {
                            LabeledContent("繰り返し", value: repeatDays.label)
                        }
                    }
                } footer: {
                    if hasDue && !repeatDays.isEmpty {
                        Text("完了にすると、次の回のタスクが自動で作られます。")
                    }
                }
            }
            .navigationTitle(task == nil ? "新しいタスク" : "タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // 繰り返しの画面から戻ったときにも呼ばれるので、読み込むのは最初の1回だけ
            .onAppear {
                guard !loaded else { return }
                loaded = true
                load()
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showNewCategory) {
            CategoryEditorSheet(category: nil) { category = $0 }
        }
    }

    private func load() {
        guard let task else {
            category = defaultCategory
            titleFocused = true
            return
        }
        title = task.title
        note = task.note
        priority = task.priority
        category = task.taskCategory
        if let due = task.dueDate {
            dueDate = due
            hasTime = task.hasDueTime
            repeatDays = task.repeatDays
        } else {
            hasDue = false
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        // 期限なしなら nil。日付だけならその日の 0:00。
        let due: Date? = if !hasDue { nil }
            else if hasTime { dueDate }
            else { Calendar.current.startOfDay(for: dueDate) }
        let dueHasTime = hasDue && hasTime
        // 繰り返しは期限があるときだけ
        let repeats: RepeatDays = hasDue ? repeatDays : []
        if let task {
            task.title = trimmed
            task.note = note
            task.priority = priority
            task.taskCategory = category
            task.dueDate = due
            task.hasDueTime = dueHasTime
            task.repeatDays = repeats
        } else {
            let new = TaskItem(
                title: trimmed, note: note,
                priority: priority, category: category,
                dueDate: due, hasDueTime: dueHasTime
            )
            new.repeatDays = repeats
            context.insert(new)
        }
        dismiss()
    }
}
