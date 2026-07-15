import SwiftUI

struct DateStamp: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let date: Date
    let calendar: Calendar

    @ScaledMetric(relativeTo: .largeTitle) private var regularDiameter: CGFloat = 92
    @ScaledMetric(relativeTo: .largeTitle) private var compactDiameter: CGFloat = 72
    @ScaledMetric(relativeTo: .largeTitle) private var regularDateNumberSize: CGFloat = 34
    @ScaledMetric(relativeTo: .largeTitle) private var compactDateNumberSize: CGFloat = 27

    private let locale = Locale(identifier: "zh_Hans_CN")

    init(date: Date, calendar: Calendar = .current) {
        self.date = date
        self.calendar = calendar
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(GuozaiColor.mangoSoft)

            Circle()
                .stroke(GuozaiColor.mango, lineWidth: 2)

            Circle()
                .inset(by: 7)
                .stroke(GuozaiColor.paper, lineWidth: 4)

            VStack(spacing: 0) {
                Text(dayText)
                    .font(
                        .system(
                            size: horizontalSizeClass == .compact ? compactDateNumberSize : regularDateNumberSize,
                            weight: .bold,
                            design: .rounded
                        )
                        .monospacedDigit()
                    )
                    .foregroundStyle(GuozaiColor.oceanDeep)

                Text("\(monthText) · \(weekdayText)")
                    .guozaiTextStyle(.supporting)
                    .foregroundStyle(GuozaiColor.oceanDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(GuozaiSpacing.medium)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(fullDateText))
    }

    private var diameter: CGFloat {
        horizontalSizeClass == .compact ? compactDiameter : regularDiameter
    }

    private var dayText: String {
        String(calendar.component(.day, from: date))
    }

    private var monthText: String {
        date.formatted(.dateTime.month(.abbreviated).locale(locale))
    }

    private var weekdayText: String {
        date.formatted(.dateTime.weekday(.short).locale(locale))
    }

    private var fullDateText: String {
        date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .weekday(.wide)
                .locale(locale)
        )
    }
}
