//
//  TaskRow.swift
//  test_app
//

import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    /// false のときはチェックボタンを無効にする（アーカイブ画面用）。
    var isInteractive = true

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                withAnimation(.snappy) { task.toggle() }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? task.categoryColor : .secondary)
                    .symbolEffect(.bounce, value: task.isDone)
            }
            .buttonStyle(.plain)
            .disabled(!isInteractive)
            .sensoryFeedback(.success, trigger: task.isDone) { _, new in new }
            .accessibilityLabel(task.isDone ? "完了済み" : "未完了")

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(task.categoryName, systemImage: task.categorySymbol)
                        .foregroundStyle(task.categoryColor)

                    if let due = task.dueLabel {
                        Label(due, systemImage: "calendar")
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    if !task.repeatDays.isEmpty {
                        Label(task.repeatDays.label, systemImage: "repeat")
                            .foregroundStyle(.secondary)
                    }

                    if task.priority == .high && !task.isDone {
                        Image(systemName: "exclamationmark.2")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption.weight(.medium))
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 4)
        // 行の右端まで広げて、文字のない所を押しても反応するようにする
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
