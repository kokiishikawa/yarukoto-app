//
//  TaskCategory.swift
//  test_app
//

import SwiftUI
import SwiftData

enum CategoryColor: String, Codable, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        case .brown: .brown
        case .gray: .gray
        }
    }
}

@Model
final class TaskCategory {
    var name: String
    var symbol: String
    var tint: CategoryColor
    var sortOrder: Int
    var createdAt: Date

    /// カテゴリを削除してもタスクは残り、未分類になる。
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.taskCategory)
    var tasks: [TaskItem] = []

    init(name: String, symbol: String, tint: CategoryColor, sortOrder: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    static let symbols = [
        "tag.fill", "person.fill", "briefcase.fill", "book.fill", "heart.fill",
        "house.fill", "cart.fill", "fork.knife", "figure.run", "dumbbell.fill",
        "airplane", "car.fill", "gamecontroller.fill", "music.note", "paintbrush.fill",
        "laptopcomputer", "creditcard.fill", "gift.fill", "pawprint.fill", "leaf.fill",
    ]

    /// 初回起動時に作成する標準カテゴリ。
    @MainActor
    static func seedDefaults(in context: ModelContext) {
        let defaults: [(String, String, CategoryColor)] = [
            ("個人", "person.fill", .indigo),
            ("仕事", "briefcase.fill", .blue),
            ("勉強", "book.fill", .purple),
            ("健康", "heart.fill", .pink),
        ]
        for (i, d) in defaults.enumerated() {
            context.insert(TaskCategory(name: d.0, symbol: d.1, tint: d.2, sortOrder: i))
        }
    }
}
