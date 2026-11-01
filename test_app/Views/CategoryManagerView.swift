//
//  CategoryManagerView.swift
//  test_app
//

import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TaskCategory.sortOrder), SortDescriptor(\TaskCategory.createdAt)])
    private var categories: [TaskCategory]

    @State private var editing: TaskCategory?
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { c in
                        Button { editing = c } label: {
                            HStack(spacing: 14) {
                                Image(systemName: c.symbol)
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(c.tint.color, in: .circle)
                                Text(c.name)
                                Spacer()
                                Text("\(c.tasks.filter { $0.deletedAt == nil }.count)件")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { categories[$0] }.forEach(context.delete)
                    }
                    .onMove { from, to in
                        var reordered = categories
                        reordered.move(fromOffsets: from, toOffset: to)
                        for (i, c) in reordered.enumerated() { c.sortOrder = i }
                    }
                } footer: {
                    Text("カテゴリを削除してもタスクは残り、「未分類」になります。")
                }
            }
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView("カテゴリがありません", systemImage: "folder.badge.plus",
                                           description: Text("右上の + から追加できます。"))
                }
            }
            .navigationTitle("カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加", systemImage: "plus") { showNew = true }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("完了") { dismiss() }
                }
            }
            .sheet(isPresented: $showNew) { CategoryEditorSheet(category: nil) }
            .sheet(item: $editing) { CategoryEditorSheet(category: $0) }
        }
    }
}
