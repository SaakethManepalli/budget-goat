import Foundation

public enum MonthBoundary {
    public static func start(of date: Date, calendar: Calendar = .init(identifier: .iso8601)) -> Date {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: components) ?? date
    }

    public static func end(of date: Date, calendar: Calendar = .init(identifier: .iso8601)) -> Date {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let startOfMonth = start(of: date, calendar: cal)
        return cal.date(byAdding: .month, value: 1, to: startOfMonth) ?? date
    }

    public static func range(containing date: Date, calendar: Calendar = .init(identifier: .iso8601)) -> ClosedRange<Date> {
        let s = start(of: date, calendar: calendar)
        let e = end(of: date, calendar: calendar).addingTimeInterval(-1)
        return s...e
    }
}
