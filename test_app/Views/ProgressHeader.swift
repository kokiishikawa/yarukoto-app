//
//  ProgressHeader.swift
//  test_app
//

import SwiftUI

/// 進捗を集計する期間。期限（dueDate）がその期間に入るタスクが対象。
enum ProgressPeriod: String, CaseIterable, Identifiable {
    case today, week, month

    var id: Self { self }

    var label: String {
        switch self {
        case .today: "今日"
        case .week: "今週"
        case .month: "今月"
        }
    }

    var title: String { "\(label)の進捗" }

    func contains(_ date: Date?, calendar: Calendar = .current) -> Bool {
        guard let date else { return false }
        let component: Calendar.Component = switch self {
        case .today: .day
        case .week: .weekOfYear
        case .month: .month
        }
        return calendar.isDate(date, equalTo: .now, toGranularity: component)
    }
}

/// 進捗カード。左右にスワイプして今日・今週・今月を切り替える。
struct ProgressHeader: View {
    @Binding var period: ProgressPeriod
    let stats: (ProgressPeriod) -> (done: Int, total: Int)

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $period) {
                ForEach(ProgressPeriod.allCases) { p in
                    let s = stats(p)
                    ProgressPage(period: p, done: s.done, total: s.total)
                        .tag(p)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 96)

            // スワイプできることを示すインジケータ。タップでも切り替えられる。
            HStack(spacing: 6) {
                ForEach(ProgressPeriod.allCases) { p in
                    Button {
                        withAnimation(.smooth) { period = p }
                    } label: {
                        Text(p.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundStyle(period == p ? Color.accentColor : Color.secondary)
                            .background(period == p ? Color.accentColor.opacity(0.16) : .clear,
                                        in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: 24))
        .sensoryFeedback(.selection, trigger: period)
    }
}

private struct ProgressPage: View {
    let period: ProgressPeriod
    let done: Int
    let total: Int

    private var progress: Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }

    private var message: String {
        if total == 0 { return "\(period.label)が期限のタスクはありません" }
        switch progress {
        case 1: return "すべて完了！お疲れさまでした 🎉"
        case 0.5...: return "いい調子です。あと少し！"
        default: return "ひとつずつ進めましょう"
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.tint.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(width: 76, height: 76)
            .padding(5) // 線の太さ分の余白。無いとスワイプ枠でリングの端が切れる

            VStack(alignment: .leading, spacing: 4) {
                Text(period.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(done) / \(total) 完了")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .animation(.smooth, value: progress)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var period = ProgressPeriod.today
    ProgressHeader(period: $period) { p in
        switch p {
        case .today: (2, 3)
        case .week: (5, 9)
        case .month: (12, 20)
        }
    }
    .padding()
}
