//
//  ArchiveView.swift
//  test_app
//

import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]

    @State private var confirmDeleteAll = false

    /// 述語付きの @Query はアーカイブ画面を開くと固まったため、メモリ上で絞り込む。
    private var tasks: [TaskItem] {
        allTasks
            .filter { $0.isArchived && $0.deletedAt == nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskRow(task: task, isInteractive: false)
                    .contextMenu {
                        Button("未完了に戻す", systemImage: "arrow.uturn.backward") {
                            withAnimation(.snappy) { task.unarchive() }
                        }
                        Button("削除", systemImage: "trash", role: .destructive) {
                            withAnimation { task.moveToTrash() }
                        }
                    } preview: {
                        TaskDetailPreview(task: task)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            withAnimation(.snappy) { task.unarchive() }
                        } label: {
                            Label("未完了に戻す", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation { task.moveToTrash() }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView(
                    "アーカイブは空です",
                    systemImage: "archivebox",
                    description: Text("完了したタスクは、翌日になると自動でここに入ります。")
                )
            }
        }
        .animation(.smooth, value: tasks.map(\.persistentModelID))
        .navigationTitle("アーカイブ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("すべて削除", systemImage: "trash", role: .destructive) {
                    confirmDeleteAll = true
                }
                .disabled(tasks.isEmpty)
            }
        }
        .confirmationDialog(
            "アーカイブ内の\(tasks.count)件をゴミ箱に移動しますか？",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) {
                withAnimation { tasks.forEach { $0.moveToTrash() } }
            }
        } message: {
            Text("ゴミ箱から復元できます。")
        }
    }
}
