//
//  TodaySnapshot.swift
//  test_app / TodayWidget
//
//  アプリとウィジェットの両方でビルドされる。
//

import Foundation

/// アプリからウィジェットへ渡す、期限つきタスクの写し。
/// ウィジェットは SwiftData を直接読まず、App Group の UserDefaults に置いたこの JSON だけを読む。
nonisolated struct TodaySnapshot: Codable, Equatable {
    nonisolated struct Item: Codable, Equatable {
        var title: String
        var dueDate: Date
        var isDone: Bool
    }

    var items: [Item] = []

    static let appGroupID = "group.koki.test-app"
    private static let key = "todaySnapshot"

    static func load() -> TodaySnapshot {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(TodaySnapshot.self, from: data)
        else { return TodaySnapshot() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroupID)?.set(data, forKey: Self.key)
    }

    /// その日の進捗（期限がその日のタスク）と、残り（その日が期限か期限切れの未完了。期限が古い順）。
    func summary(on day: Date, calendar: Calendar = .current)
        -> (done: Int, total: Int, remaining: [Item])
    {
        let start = calendar.startOfDay(for: day)
        let todays = items.filter { calendar.isDate($0.dueDate, inSameDayAs: day) }
        let remaining = items
            .filter { !$0.isDone && ($0.dueDate < start || calendar.isDate($0.dueDate, inSameDayAs: day)) }
            .sorted { $0.dueDate < $1.dueDate }
        return (todays.filter(\.isDone).count, todays.count, remaining)
    }
}
