//
//  TrashView.swift
//  test_app
//

import SwiftUI
import SwiftData

/// 削除したタスクの一覧。復元するか、完全に削除できる。
struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var confirmEmpty = false

    private var tasks: [TaskItem] {
        allTasks
            .filter { $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            Section {
                ForEach(tasks) { task in
                    HStack(spacing: 8) {
                        TaskRow(task: task, isInteractive: false)
                            .overlay(alignment: .bottomTrailing) {
                                if let days = task.daysUntilPurge {
                                    Text("あと\(days)日")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        Spacer(minLength: 0)
                        Button("復元") {
                            withAnimation(.snappy) { task.restore() }
                        }
                        .buttonStyle(.borderless)
                        .font(.subheadline.weight(.semibold))
                    }
                    .contextMenu {
                        Button("復元", systemImage: "arrow.uturn.backward") {
                            withAnimation(.snappy) { task.restore() }
                        }
                        Button("完全に削除", systemImage: "trash.slash", role: .destructive) {
                            withAnimation { context.delete(task) }
                        }
                    } preview: {
                        TaskDetailPreview(task: task)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation { context.delete(task) }
                        } label: {
                            Label("完全に削除", systemImage: "trash.slash")
                        }
                    }
                }
            } footer: {
                if !tasks.isEmpty {
                    Text("「復元」で元の一覧に戻せます。ゴミ箱のタスクは30日後に自動で完全に削除されます。左にスワイプすると今すぐ完全に削除します。")
                }
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "ゴミ箱は空です",
                    systemImage: "trash",
                    description: Text("削除したタスクは30日間ここに残り、復元できます。")
                )
            }
        }
        .animation(.smooth, value: tasks.map(\.persistentModelID))
        .navigationTitle("ゴミ箱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("ゴミ箱を空にする", systemImage: "trash.slash", role: .destructive) {
                    confirmEmpty = true
                }
                .disabled(tasks.isEmpty)
            }
        }
        .confirmationDialog(
            "ゴミ箱の\(tasks.count)件を完全に削除しますか？",
            isPresented: $confirmEmpty,
            titleVisibility: .visible
        ) {
            Button("完全に削除", role: .destructive) {
                withAnimation { tasks.forEach(context.delete) }
            }
        } message: {
            Text("この操作は取り消せません。")
        }
    }
}
