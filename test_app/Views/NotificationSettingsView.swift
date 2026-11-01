//
//  NotificationSettingsView.swift
//  test_app
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var allTasks: [TaskItem]

    @AppStorage("morningNotifyEnabled") private var enabled = false
    @AppStorage("morningNotifyMinutes") private var minutes = 8 * 60

    @State private var denied = false
    @State private var testMessage: String?

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { enabled },
            set: { newValue in
                guard newValue else { enabled = false; return }
                Task {
                    let granted = await NotificationScheduler.requestAuthorization()
                    enabled = granted
                    denied = !granted
                }
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                      second: 0, of: .now) ?? .now
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes = (c.hour ?? 8) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("毎朝のお知らせ", isOn: toggleBinding)
                    if enabled {
                        DatePicker("時刻", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("その日が期限で未完了のタスクと、期限切れのタスクを、設定した時刻に知らせます。タスクがない日は通知しません。")
                }

                if denied {
                    Section {
                        Text("通知が許可されていません。設定アプリで、このアプリの通知をオンにしてください。")
                            .font(.subheadline)
                        Button("設定アプリを開く") {
                            if let url = URL(string: "app-settings:") { openURL(url) }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await sendTest() }
                    } label: {
                        Label("5分後にテスト通知を送る", systemImage: "bell.badge")
                    }
                } header: {
                    Text("テスト")
                } footer: {
                    if let testMessage { Text(testMessage) }
                }
            }
            .navigationTitle("通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .task { denied = await NotificationScheduler.authorizationStatus() == .denied }
        }
        .presentationDetents([.large])
    }

    private func sendTest() async {
        let ok = await NotificationScheduler.scheduleTest(tasks: allTasks)
        denied = !ok
        if ok {
            let time = Date.now.addingTimeInterval(300).formatted(.dateTime.hour().minute())
            testMessage = "\(time) に通知します。ホーム画面に戻ってお待ちください。"
        } else {
            testMessage = nil
        }
    }
}
