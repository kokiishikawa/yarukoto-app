//
//  PreviewData.swift
//  test_app
//

import SwiftData
import Foundation

/// プレビュー専用のサンプルデータ。コンテナは1つだけ作って使い回す。
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: TaskItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        TaskCategory.seedDefaults(in: context)
        let cats = (try? context.fetch(FetchDescriptor<TaskCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let personal = cats[0], work = cats[1], study = cats[2], health = cats[3]

        let now = Date.now
        let done = TaskItem(title: "牛乳を買う", category: personal, dueDate: now)
        done.toggle()
        let archived = TaskItem(title: "先週のレポート提出", category: work, dueDate: now)
        archived.toggle()
        archived.archive()
        let trashed = TaskItem(title: "古いメモの整理", category: personal)
        trashed.moveToTrash()
        let workout = TaskItem(title: "筋トレ", category: health, dueDate: Calendar.current.startOfDay(for: now))
        workout.repeatDays = .weekdays
        let samples = [
            TaskItem(
                title: "企画書を仕上げる",
                note: "金曜までに共有",
                priority: .high,
                category: work,
                dueDate: now.addingTimeInterval(60 * 60 * 5),
                hasDueTime: true
            ),
            TaskItem(title: "Swift の本を読む", category: study, dueDate: now.addingTimeInterval(60 * 60 * 30)),
            TaskItem(title: "ジョギング 30分", priority: .low, category: health),
            TaskItem(
                title: "請求書を送る",
                priority: .high,
                category: work,
                dueDate: now.addingTimeInterval(-60 * 60 * 2)
            ),
            workout,
            done,
            archived,
            trashed,
        ]
        samples.forEach(context.insert)
        return container
    }()
}
