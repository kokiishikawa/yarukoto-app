//
//  TaskItem.swift
//  test_app
//

import SwiftUI
import SwiftData

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case low, medium, high

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        }
    }

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

@Model
final class TaskItem {
    var title: String
    var note: String
    var isDone: Bool
    var priority: Priority
    var taskCategory: TaskCategory?
    var dueDate: Date?
    /// false のときは日付だけの期限（dueDate はその日の 0:00）。
    var hasDueTime: Bool = false
    var createdAt: Date
    var completedAt: Date?
    var isArchived: Bool = false
    /// nil 以外ならゴミ箱の中（ソフト削除）。
    var deletedAt: Date?
    var archivedAt: Date?
    /// 繰り返す曜日（`RepeatDays` のビット）。0 なら繰り返さない。
    var repeatMask: Int = 0
    /// 同じ繰り返しから作られたタスクに共通の印。最初に次の回を作るときに付ける。
    var seriesID: UUID?
    /// 完了して次の回を作ったときの、その回の期限。完了を取り消したとき、消す回を探すのに使う。
    var nextOccurrenceDueDate: Date?

    init(
        title: String,
        note: String = "",
        priority: Priority = .medium,
        category: TaskCategory? = nil,
        dueDate: Date? = nil,
        hasDueTime: Bool = false
    ) {
        self.title = title
        self.note = note
        self.isDone = false
        self.priority = priority
        self.taskCategory = category
        self.dueDate = dueDate
        self.hasDueTime = hasDueTime
        self.createdAt = .now
    }

    var categoryName: String { taskCategory?.name ?? "未分類" }
    var categorySymbol: String { taskCategory?.symbol ?? "tray.fill" }
    var categoryColor: Color { taskCategory?.tint.color ?? .gray }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return hasDueTime ? dueDate < .now : dueDate < Calendar.current.startOfDay(for: .now)
    }

    /// 「今日」「明日 18:00」「11月5日」のような期限の表示。
    var dueLabel: String? {
        guard let dueDate else { return nil }
        let cal = Calendar.current
        let day = if cal.isDateInToday(dueDate) {
            "今日"
        } else if cal.isDateInTomorrow(dueDate) {
            "明日"
        } else if cal.isDateInYesterday(dueDate) {
            "昨日"
        } else {
            dueDate.formatted(.dateTime.month().day())
        }
        return hasDueTime ? "\(day) \(dueDate.formatted(.dateTime.hour().minute()))" : day
    }

    /// ゴミ箱に入れてから完全に削除するまでの日数。
    static let trashRetentionDays = 30

    /// ゴミ箱に入れてから完全に削除されるまでの残り日数。ゴミ箱に無ければ nil。
    var daysUntilPurge: Int? {
        guard let deletedAt else { return nil }
        let cal = Calendar.current
        let from = cal.startOfDay(for: deletedAt)
        let to = cal.startOfDay(for: .now)
        let elapsed = cal.dateComponents([.day], from: from, to: to).day ?? 0
        return max(Self.trashRetentionDays - elapsed, 0)
    }

    func moveToTrash() { deletedAt = .now }

    func restore() { deletedAt = nil }

    func archive() {
        isArchived = true
        archivedAt = .now
    }

    /// アーカイブから一覧へ戻す。完了済みのままだと、翌日に自動でしまう処理ですぐアーカイブへ
    /// 戻ってしまうので、未完了に戻す（繰り返しなら、そのとき作った次の回も消える）。
    func unarchive() {
        isArchived = false
        archivedAt = nil
        if isDone { toggle() }
    }

    var repeatDays: RepeatDays {
        get { RepeatDays(rawValue: repeatMask) }
        set { repeatMask = newValue.rawValue }
    }

    /// 繰り返すタスクの次の回の期限。期限の日と完了した日の遅いほうより後で、最初に当てはまる曜日。
    /// 時刻つきなら同じ時刻にする。
    func nextDueDate(completedAt: Date, calendar: Calendar = .current) -> Date? {
        guard let dueDate,
              let day = repeatDays.nextDay(after: max(dueDate, completedAt), calendar: calendar)
        else { return nil }
        guard hasDueTime else { return day }
        let time = calendar.dateComponents([.hour, .minute], from: dueDate)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day)
    }

    func toggle() {
        let previousCompletion = completedAt
        isDone.toggle()
        completedAt = isDone ? .now : nil
        if isDone {
            addNextOccurrence()
        } else {
            removeNextOccurrence(previousCompletion: previousCompletion)
        }
    }

    /// 繰り返すタスクを完了したら、次の回を1つ作る。
    private func addNextOccurrence() {
        guard let modelContext, let completedAt,
              let next = nextDueDate(completedAt: completedAt)
        else { return }
        if seriesID == nil { seriesID = UUID() }
        let copy = TaskItem(
            title: title,
            note: note,
            priority: priority,
            category: taskCategory,
            dueDate: next,
            hasDueTime: hasDueTime
        )
        copy.repeatMask = repeatMask
        copy.seriesID = seriesID
        modelContext.insert(copy)
        nextOccurrenceDueDate = next
    }

    /// 完了を取り消したら、そのとき作った次の回（まだ完了していないもの）を消す。
    /// 次の回の期限は、作ったときに覚えておいたものを使う。完了したあとで期限や曜日を編集しても見つけられるようにするため。
    private func removeNextOccurrence(previousCompletion: Date?) {
        defer { nextOccurrenceDueDate = nil }
        // この仕組みを入れる前に完了したタスクは期限を覚えていないので、計算し直す
        let remembered = nextOccurrenceDueDate
            ?? previousCompletion.flatMap { nextDueDate(completedAt: $0) }
        guard let modelContext, let seriesID, let next = remembered,
              let all = try? modelContext.fetch(FetchDescriptor<TaskItem>())
        else { return }
        let spawned = all.first {
            $0 !== self && $0.seriesID == seriesID && !$0.isDone && $0.deletedAt == nil && $0.dueDate == next
        }
        if let spawned { modelContext.delete(spawned) }
    }
}
