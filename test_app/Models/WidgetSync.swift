//
//  WidgetSync.swift
//  test_app
//

import WidgetKit
import Foundation

extension TodaySnapshot {
    /// タスクの写しをウィジェットに渡す。内容が変わったときだけ書き込み、ウィジェットを更新する。
    /// 進捗の数え方は ContentView と同じ（アーカイブ済みを含み、ゴミ箱と期限なしは除く）。
    static func update(from tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let items = tasks.compactMap { task -> Item? in
            guard task.deletedAt == nil, let due = task.dueDate else { return nil }
            // 昨日までに期限が来て完了したものは、もう表示に使わない
            if task.isDone && due < today { return nil }
            return Item(title: task.title, dueDate: due, isDone: task.isDone)
        }
        let snapshot = TodaySnapshot(items: items)
        guard snapshot != load() else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
