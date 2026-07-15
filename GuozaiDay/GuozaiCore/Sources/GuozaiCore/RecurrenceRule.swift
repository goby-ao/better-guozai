import Foundation

public struct RecurrenceRule: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case daily
        case weekdays
        case weekends
        case custom
    }

    public struct Pause: Codable, Hashable, Sendable {
        public let start: LocalDay
        public let end: LocalDay

        public init(start: LocalDay, end: LocalDay) {
            self.start = start
            self.end = end
        }

        public func contains(_ day: LocalDay) -> Bool {
            start <= day && day <= end
        }
    }

    public let kind: Kind
    public let start: LocalDay
    public let end: LocalDay?
    public let weekdays: Set<Int>
    public let pauses: [Pause]

    public init(
        kind: Kind,
        start: LocalDay,
        end: LocalDay? = nil,
        weekdays: Set<Int> = [],
        pauses: [Pause] = []
    ) {
        self.kind = kind
        self.start = start
        self.end = end
        self.weekdays = weekdays
        self.pauses = pauses
    }

    public func applies(
        to day: LocalDay,
        calendar: Calendar = .guozaiGregorian
    ) -> Bool {
        guard day >= start else { return false }
        if let end, day > end { return false }
        guard !pauses.contains(where: { $0.contains(day) }) else { return false }
        guard let date = day.date(calendar: calendar) else { return false }

        let weekday = calendar.component(.weekday, from: date)
        switch kind {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        case .custom:
            return weekdays.contains(weekday)
        }
    }

    public func upcomingDays(
        from firstDay: LocalDay,
        limit: Int,
        searchHorizonDays: Int = 366,
        calendar: Calendar = .guozaiGregorian
    ) -> [LocalDay] {
        guard
            limit > 0,
            searchHorizonDays >= 0,
            let firstDate = firstDay.date(calendar: calendar)
        else { return [] }

        var result: [LocalDay] = []
        for offset in 0...searchHorizonDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDate) else {
                continue
            }
            let day = LocalDay(date: date, calendar: calendar)
            if let end, day > end { break }
            if applies(to: day, calendar: calendar) {
                result.append(day)
                if result.count == limit { break }
            }
        }
        return result
    }
}
