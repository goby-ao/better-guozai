import Foundation

public struct LocalDay: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(key: String) {
        let bytes = Array(key.utf8)
        guard
            bytes.count == 10,
            bytes[4] == Character("-").asciiValue,
            bytes[7] == Character("-").asciiValue,
            let year = Self.number(in: bytes[0..<4]),
            let month = Self.number(in: bytes[5..<7]),
            let day = Self.number(in: bytes[8..<10]),
            year > 0
        else {
            return nil
        }

        let value = LocalDay(year: year, month: month, day: day)
        let calendar = Calendar.guozaiStableGregorian
        guard
            let date = value.date(calendar: calendar),
            LocalDay(date: date, calendar: calendar) == value
        else {
            return nil
        }
        self = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let value = LocalDay(key: key) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid local day key: \(key)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }

    public init(date: Date, calendar: Calendar = .guozaiGregorian) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    public var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func date(calendar: Calendar = .guozaiGregorian) -> Date? {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ))
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func number(in bytes: ArraySlice<UInt8>) -> Int? {
        var result = 0
        for byte in bytes {
            guard (48...57).contains(byte) else { return nil }
            result = result * 10 + Int(byte - 48)
        }
        return result
    }
}

public extension Calendar {
    static var guozaiGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return calendar
    }

    static var guozaiStableGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
