//
//  CopyActivityStore.swift
//  InspireCreativityApp
//
//  Records code copies per day to power the Library stats card's
//  weekly-activity bars ("37 copies this week").
//

import Combine
import Foundation

final class CopyActivityStore {

    private enum Keys { static let byDay = "engagement.copies.byDay" }

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

    func recordCopy(on date: Date = Date()) {
        var counts = load()
        counts[dayFormatter.string(from: date), default: 0] += 1
        // Keys sort lexicographically as dates, so pruning is a string compare.
        if let cutoff = calendar.date(byAdding: .day, value: -21, to: date) {
            let cutoffKey = dayFormatter.string(from: cutoff)
            counts = counts.filter { $0.key >= cutoffKey }
        }
        save(counts)
        didChange.send()
    }

    /// 7 counts, Monday-first, for the week containing `date` (bars M T W T F S S).
    func weekBars(for date: Date) -> [Int] {
        let counts = load()
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        let sinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(
            byAdding: .day, value: -sinceMonday, to: calendar.startOfDay(for: date)
        ) else { return Array(repeating: 0, count: 7) }
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return 0 }
            return counts[dayFormatter.string(from: day)] ?? 0
        }
    }

    func copiesThisWeek(for date: Date = Date()) -> Int {
        weekBars(for: date).reduce(0, +)
    }

    private func load() -> [String: Int] {
        guard let data = defaults.data(forKey: Keys.byDay) else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private func save(_ counts: [String: Int]) {
        defaults.set(try? JSONEncoder().encode(counts), forKey: Keys.byDay)
    }
}
