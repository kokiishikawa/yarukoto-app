//
//  TodayWidget.swift
//  TodayWidget
//

import WidgetKit
import SwiftUI

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: context.isPreview ? .sample : .load()))
    }

    /// 今と、この先1週間の毎日 0:00 の分を作る。日付が変わると「今日」の中身が切り替わる。
    /// タスクが変わったときは、アプリがウィジェットを更新する。
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = TodaySnapshot.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = ([Date.now] + midnights).map { TodayEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日のタスク")
        .description("今日の進捗と、残っているタスクを表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall, .systemMedium])
    }
}

@main
struct TodayWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

extension TodaySnapshot {
    /// プレビューとウィジェット追加画面の見本。
    static var sample: TodaySnapshot {
        let now = Date.now
        return TodaySnapshot(items: [
            Item(title: "請求書を送る", dueDate: now.addingTimeInterval(-60 * 60 * 24), isDone: false),
            Item(title: "企画書を仕上げる", dueDate: now, isDone: false),
            Item(title: "Swift の本を読む", dueDate: now, isDone: false),
            Item(title: "牛乳を買う", dueDate: now, isDone: true),
        ])
    }
}
