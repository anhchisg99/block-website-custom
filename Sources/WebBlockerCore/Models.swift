import Foundation

/// A weekly time window during which the site list is blocked.
public struct BlockSchedule: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Calendar weekdays: 1 = Sunday, 2 = Monday, ... 7 = Saturday.
    public var weekdays: Set<Int>
    /// Minutes since midnight.
    public var startMinute: Int
    public var endMinute: Int
    public var isEnabled: Bool

    public init(id: UUID = UUID(), weekdays: Set<Int>, startMinute: Int, endMinute: Int, isEnabled: Bool = true) {
        self.id = id
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    /// - start == end: the whole day.
    /// - start > end: overnight window; it belongs to the day it starts on.
    public func isActive(weekday: Int, minute: Int) -> Bool {
        guard isEnabled else { return false }
        if startMinute == endMinute {
            return weekdays.contains(weekday)
        }
        if startMinute < endMinute {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        let previousDay = weekday == 1 ? 7 : weekday - 1
        return (weekdays.contains(weekday) && minute >= startMinute)
            || (weekdays.contains(previousDay) && minute < endMinute)
    }
}

public struct BlockConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var sites: [String]
    public var schedules: [BlockSchedule]

    public init(isEnabled: Bool, sites: [String], schedules: [BlockSchedule]) {
        self.isEnabled = isEnabled
        self.sites = sites
        self.schedules = schedules
    }

    /// First-launch config: block on weekdays 9:00–17:00.
    public static let initial = BlockConfig(
        isEnabled: true,
        sites: [],
        schedules: [BlockSchedule(weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 17 * 60)]
    )

    public func isBlocking(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, !sites.isEmpty else { return false }
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let minute = c.hour! * 60 + c.minute!
        return schedules.contains { $0.isActive(weekday: c.weekday!, minute: minute) }
    }
}
