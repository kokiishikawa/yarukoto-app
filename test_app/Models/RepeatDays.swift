//
//  RepeatDays.swift
//  test_app
//

import Foundation

/// 時計アプリのアラームと同じ「繰り返し」。曜日の組み合わせをビットで持つ。
/// 曜日の番号は Calendar と同じ（1 = 日曜 … 7 = 土曜）。
struct RepeatDays: OptionSet, Hashable {
    let rawValue: Int

    static func day(_ weekday: Int) -> RepeatDays { RepeatDays(rawValue: 1 << (weekday - 1)) }

    static let everyDay = RepeatDays(rawValue: 0b111_1111)
    static let weekdays: RepeatDays = [day(2), day(3), day(4), day(5), day(6)]
    static let weekend: RepeatDays = [day(1), day(7)]

    /// 日曜始まりの曜日名。
    static let names = ["日", "月", "火", "水", "木", "金", "土"]

    /// 「しない」「毎日」「平日」「週末」「月 水 金」のような表示。
    var label: String {
        switch self {
        case []: "しない"
        case .everyDay: "毎日"
        case .weekdays: "平日"
        case .weekend: "週末"
        default: (1...7).filter { contains(.day($0)) }.map { Self.names[$0 - 1] }.joined(separator: " ")
        }
    }

    /// `date` の翌日以降で、最初に当てはまる曜日の 0:00。繰り返さないなら nil。
    func nextDay(after date: Date, calendar: Calendar = .current) -> Date? {
        guard !isEmpty else { return nil }
        let start = calendar.startOfDay(for: date)
        return (1...7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .first { contains(.day(calendar.component(.weekday, from: $0))) }
    }
}
