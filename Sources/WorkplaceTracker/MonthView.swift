import SwiftUI
import WorkplaceCore

/// Header, progress bar, one status line and the Mon–Fri grid of the month.
struct MonthView: View {
    let month: MonthSummary

    private var tint: Color { month.pace.color ?? .accentColor }

    private var status: String {
        guard month.pace != .done else { return "Target reached" }
        let days = month.workdaysLeft == 1 ? "workday" : "workdays"
        return "\(month.remaining) to go · \(month.workdaysLeft) \(days) left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Date().formatted(.dateTime.month(.wide).locale(english)))
                    .font(.headline)
                Spacer()
                Text("\(month.done) / \(month.target)")
                    .font(.headline.monospacedDigit())
            }
            HStack(spacing: 3) {
                ForEach(0..<month.target, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < month.done ? tint : Color.secondary.opacity(0.25))
                        .frame(height: 6)
                }
            }
            Text(status)
                .font(.callout)
                .foregroundStyle(month.pace.color ?? .secondary)

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    ForEach(Array("MTWTF".enumerated()), id: \.offset) { _, letter in
                        Text(String(letter)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach(month.weeks.indices, id: \.self) { week in
                    GridRow {
                        ForEach(0..<5, id: \.self) { weekday in
                            DayCell(day: month.weeks[week][weekday])
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }
}

/// Office: filled. Home: outlined. No data or future: just the number. Today: ringed.
private struct DayCell: View {
    let day: CalendarDay?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        let isOffice = day?.status == .office
        Text(day.map { "\($0.day)" } ?? "")
            .font(.caption.monospacedDigit())
            .foregroundStyle(isOffice ? Color.white : day?.status == .home ? Color.primary : Color.secondary.opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(shape.fill(isOffice ? Color.accentColor : .clear))
            .overlay(shape.strokeBorder(Color.secondary.opacity(day?.status == .home ? 0.6 : 0), lineWidth: 1))
            .overlay(shape.inset(by: -2).strokeBorder(Color.primary.opacity(day?.isToday == true ? 0.8 : 0), lineWidth: 1.5))
    }
}
