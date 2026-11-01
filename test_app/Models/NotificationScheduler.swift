//
//  NotificationScheduler.swift
//  test_app
//

import UserNotifications
import Foundation

/// アプリを開いている間も通知をバナーで見せる。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// 朝のお知らせと、テスト通知の予約。端末内だけで完結するローカル通知。
@MainActor
enum NotificationScheduler {
    static let morningPrefix = "morning-"
    static let testID = "test-notification"
    /// 何日先まで予約するか。タスクが増減するたびに予約し直す。
    static let daysAhead = 14

    // MARK: 許可

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 許可済みなら true。未確認なら許可ダイアログを出す。
    static func requestAuthorization() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    // MARK: 通知の中身

    /// その日が期限の未完了タスクと、その日より前に期限が切れた未完了タスクから、通知の文面を作る。
    /// どちらも無ければ nil。
    static func summary(for day: Date, tasks: [TaskItem], calendar: Calendar = .current)
        -> (title: String, body: String)?
    {
        let startOfDay = calendar.startOfDay(for: day)
        let due = tasks
            .filter { task in
                guard task.deletedAt == nil, !task.isDone, let d = task.dueDate else { return false }
                return d < startOfDay || calendar.isDate(d, inSameDayAs: day)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        guard !due.isEmpty else { return nil }

        let overdue = due.filter { $0.dueDate! < startOfDay }.count
        let today = due.count - overdue
        let title = switch (today, overdue) {
        case (_, 0): "今日のタスクは\(today)件です"
        case (0, _): "期限切れのタスクが\(overdue)件あります"
        default: "今日のタスクは\(today)件です（期限切れ\(overdue)件）"
        }

        // 期限が古い順なので、期限切れのタスクが先に並ぶ
        let names = due.prefix(3).map(\.title).joined(separator: "、")
        let rest = due.count > 3 ? " ほか\(due.count - 3)件" : ""
        return (title, names + rest)
    }

    /// 朝の通知のリクエストを、今から `daysAhead` 日分作る。タスクが無い日は作らない。
    static func morningRequests(
        tasks: [TaskItem], minutes: Int, now: Date = .now, calendar: Calendar = .current
    ) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                           second: 0, of: day),
                  fire > now,
                  let text = summary(for: day, tasks: tasks, calendar: calendar)
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default

            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let id = morningPrefix + "\(parts.year!)-\(parts.month!)-\(parts.day!)"
            requests.append(UNNotificationRequest(
                identifier: id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            ))
        }
        return requests
    }

    // MARK: 予約

    /// 朝の通知を予約し直す。オフ・未許可のときは予約を消すだけ。
    static func rescheduleMorning(tasks: [TaskItem], enabled: Bool, minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(morningPrefix) }
        )
        guard enabled, await requestAuthorizationIfAlreadyDecided() else { return }

        for request in morningRequests(tasks: tasks, minutes: minutes) {
            try? await center.add(request)
        }
    }

    /// 自動の予約では許可ダイアログを出さない。許可済みのときだけ true。
    private static func requestAuthorizationIfAlreadyDecided() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// 5分後にテスト通知を送る。許可が無ければ false。
    static func scheduleTest(tasks: [TaskItem], after seconds: TimeInterval = 300) async -> Bool {
        guard await requestAuthorization() else { return false }

        let text = summary(for: .now, tasks: tasks)
            ?? ("今日のタスクはありません", "今日が期限の未完了タスクも、期限切れのタスクもありません。")
        let content = UNMutableNotificationContent()
        content.title = "【テスト】" + text.title
        content.body = text.body
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [testID])
        let request = UNNotificationRequest(
            identifier: testID, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        return (try? await center.add(request)) != nil
    }
}
