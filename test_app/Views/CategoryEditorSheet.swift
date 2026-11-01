//
//  CategoryEditorSheet.swift
//  test_app
//

import SwiftUI
import SwiftData

/// カテゴリの新規作成・編集シート。`category` が nil なら新規作成。
struct CategoryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [TaskCategory]

    let category: TaskCategory?
    var onSave: ((TaskCategory) -> Void)?

    @State private var name = ""
    @State private var symbol = TaskCategory.symbols[0]
    @State private var tint: CategoryColor = .blue

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(tint.color, in: .circle)
                        TextField("カテゴリ名", text: $name)
                    }
                }

                Section("カラー") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CategoryColor.allCases) { c in
                            Button { tint = c } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if tint == c {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("アイコン") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TaskCategory.symbols, id: \.self) { s in
                            Button { symbol = s } label: {
                                Image(systemName: s)
                                    .font(.title3)
                                    .foregroundStyle(symbol == s ? .white : tint.color)
                                    .frame(width: 44, height: 44)
                                    .background(symbol == s ? tint.color : tint.color.opacity(0.12),
                                                in: .circle)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "新しいカテゴリ" : "カテゴリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard let category else { return }
        name = category.name
        symbol = category.symbol
        tint = category.tint
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            category.name = trimmed
            category.symbol = symbol
            category.tint = tint
            onSave?(category)
        } else {
            let next = (existing.map(\.sortOrder).max() ?? -1) + 1
            let new = TaskCategory(name: trimmed, symbol: symbol, tint: tint, sortOrder: next)
            context.insert(new)
            onSave?(new)
        }
        dismiss()
    }
}
