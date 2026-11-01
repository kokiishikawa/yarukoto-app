//
//  RepeatPickerView.swift
//  test_app
//

import SwiftUI

/// 時計アプリのアラームと同じ、曜日にチェックを付ける画面。
struct RepeatPickerView: View {
    @Binding var days: RepeatDays

    var body: some View {
        List {
            ForEach(1...7, id: \.self) { weekday in
                let day = RepeatDays.day(weekday)
                Button {
                    if days.contains(day) { days.remove(day) } else { days.insert(day) }
                } label: {
                    HStack {
                        Text("\(RepeatDays.names[weekday - 1])曜日ごと")
                        Spacer()
                        if days.contains(day) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(.rect)
                }
                // 時計アプリと同じく、文字は黒・チェックだけ色つき
                .tint(.primary)
                .accessibilityAddTraits(days.contains(day) ? .isSelected : [])
            }
        }
        .navigationTitle("繰り返し")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @Previewable @State var days = RepeatDays.weekdays
    NavigationStack { RepeatPickerView(days: $days) }
}
