//
//  TaskDetailPreview.swift
//  test_app
//

import SwiftUI

/// タスクを長押ししたときに出る詳細。メモは省略せず全文を表示する。
struct TaskDetailPreview: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(task.title)
                .font(.title3.bold())
                .strikethrough(task.isDone)

            if task.note.isEmpty {
                Text("メモはありません")
                    .foregroundStyle(.tertiary)
            } else {
                Text(task.note)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                row("カテゴリ", systemImage: task.categorySymbol, tint: task.categoryColor) {
                    Text(task.categoryName)
                }
                row("期限", systemImage: "calendar", tint: task.isOverdue ? .red : .secondary) {
                    Text(task.dueLabel ?? "なし")
                        .foregroundStyle(task.isOverdue ? .red : .primary)
                }
                if !task.repeatDays.isEmpty {
                    row("繰り返し", systemImage: "repeat", tint: .secondary) {
                        Text(task.repeatDays.label)
                    }
                }
                row("優先度", systemImage: "flag.fill", tint: task.priority.color) {
                    Text(task.priority.label)
                }
                row("状態", systemImage: task.isDone ? "checkmark.circle.fill" : "circle", tint: .secondary) {
                    Text(task.isDone ? "完了" : "未完了")
                }
                row("作成", systemImage: "clock", tint: .secondary) {
                    Text(task.createdAt.formatted(.dateTime.year().month().day()))
                }
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
    }

    private func row<Value: View>(
        _ title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(spacing: 10) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(tint)
                .frame(width: 96, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
    }
}
