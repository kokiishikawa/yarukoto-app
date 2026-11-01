//
//  test_appApp.swift
//  test_app
//
//  Created by koki on 2026/10/30.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct test_appApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // 初回起動時は Application Support が存在せず、SwiftData が CoreData エラーを出力するため先に作成する
        try? FileManager.default.createDirectory(
            at: .applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TaskItem.self)
    }
}
