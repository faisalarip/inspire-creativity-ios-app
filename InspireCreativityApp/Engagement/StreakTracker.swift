//
//  StreakTracker.swift
//  InspireCreativityApp
//
//  Tracks consecutive-day app opens — the 🔥 streak shown on Discover and
//  Library. UserDefaults-backed, day boundaries in the injected calendar's
//  time zone.
//

import Combine
import Foundation

final class StreakTracker {

    private enum Keys {
        static let count = "engagement.streak.count"
        static let lastOpenDay = "engagement.streak.lastOpenDay"
    }

    let didChange = PassthroughSubject<Void, Never>()

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dayFormatter: DateFormatter

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = formatter
    }

    /// Current streak in days; 0 before the first recorded open.
    var current: Int { defaults.integer(forKey: Keys.count) }

    @discardableResult
    func recordAppOpen(on date: Date = Date()) -> Int {
        let today = dayFormatter.string(from: date)
        let last = defaults.string(forKey: Keys.lastOpenDay)
        guard last != today else { return current }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
            .map(dayFormatter.string(from:))
        let next = (last != nil && last == yesterday) ? current + 1 : 1
        defaults.set(next, forKey: Keys.count)
        defaults.set(today, forKey: Keys.lastOpenDay)
        didChange.send()
        return next
    }
}
