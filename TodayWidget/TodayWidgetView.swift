//
//  TodayWidgetView.swift
//  TodayWidget
//

import WidgetKit
import SwiftUI

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var summary: (done: Int, total: Int, remaining: [TodaySnapshot.Item]) {
        entry.snapshot.summary(on: entry.date)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: system
        }
    }

    // MARK: ロック画面

    /// 進捗のリングと「3/5」。
    private var circular: some View {
        let s = summary
        return Gauge(value: Double(s.done), in: 0...Double(max(s.total, 1))) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            if s.total == 0 {
                Image(systemName: "checkmark")
            } else {
                Text("\(s.done)/\(s.total)")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    /// 「今日 3/5 完了」と、残りのタスクを2件まで。
    private var rectangular: some View {
        let s = summary
        return VStack(alignment: .leading, spacing: 1) {
            Text(s.total == 0 ? "今日のタスク" : "今日 \(s.done)/\(s.total) 完了")
                .font(.headline)
                .widgetAccentable()
            if s.remaining.isEmpty {
                Text(s.total == 0 ? "期限のタスクはありません" : "すべて完了！")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(s.remaining.prefix(2).enumerated()), id: \.offset) { _, item in
                    Text("・\(item.title)")
                }
                if s.remaining.count > 2 {
                    Text("ほか\(s.remaining.count - 2)件")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: ホーム画面

    private var system: some View {
        let s = summary
        let limit = family == .systemSmall ? 3 : 4
        let start = Calendar.current.startOfDay(for: entry.date)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日のタスク")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(s.done)/\(s.total)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.tint)
            }
            ProgressView(value: Double(s.done), total: Double(max(s.total, 1)))

            if s.remaining.isEmpty {
                Spacer(minLength: 0)
                Label(
                    s.total == 0 ? "期限のタスクはありません" : "すべて完了！",
                    systemImage: "checkmark.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(s.remaining.prefix(limit).enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            // 期限切れは赤
                            .foregroundStyle(item.dueDate < start ? .red : .primary)
                    }
                }
                if s.remaining.count > limit {
                    Text("ほか\(s.remaining.count - limit)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview(as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}

#Preview(as: .accessoryCircular) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
}

#Preview(as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry(date: .now, snapshot: .sample)
    TodayEntry(date: .now, snapshot: TodaySnapshot())
}
