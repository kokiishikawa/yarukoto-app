//
//  CategoryChip.swift
//  test_app
//

import SwiftUI

/// カテゴリ選択用の丸いチップ。一覧の絞り込みとタスク編集で共通。
struct CategoryChip: View {
    let label: String
    let symbol: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Label(label, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? .white : color)
                .background(selected ? color : color.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
