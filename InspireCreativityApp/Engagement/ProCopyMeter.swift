//
//  ProCopyMeter.swift
//  InspireCreativityApp
//
//  v2.1 metering: every non-Pro user gets a few Pro copies per drop week
//  (Friday 08:00 → Friday 08:00). Redeeming unlocks that animation's code
//  for the rest of the period; the paywall fires only once the meter is
//  spent — the highest-intent moment in the funnel.
//

import Combine
import Foundation

final class ProCopyMeter {

    /// Free Pro copies per drop week.
    static let weeklyAllowance = 3

    private enum Keys {
        static let period = "engagement.meter.period"
        static let ids = "engagement.meter.ids"
    }

    let didChange = PassthroughSubject<Void, Never>()

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Pro copies left in the period containing `date`.
    func remaining(on date: Date = Date()) -> Int {
        max(0, Self.weeklyAllowance - redeemedIds(on: date).count)
    }

    /// Animations already unlocked with a metered copy this period.
    func redeemedIds(on date: Date = Date()) -> Set<String> {
        guard defaults.integer(forKey: Keys.period) == seed(for: date) else { return [] }
        return Set(defaults.stringArray(forKey: Keys.ids) ?? [])
    }

    func isRedeemed(_ id: String, on date: Date = Date()) -> Bool {
        redeemedIds(on: date).contains(id)
    }

    /// Consumes one copy for `id`. Idempotent per period: an already-redeemed
    /// id stays unlocked and never double-charges. Returns false only when
    /// the meter is spent and the id wasn't redeemed yet.
    @discardableResult
    func redeem(_ id: String, on date: Date = Date()) -> Bool {
        var ids = redeemedIds(on: date)
        if ids.contains(id) { return true }
        guard ids.count < Self.weeklyAllowance else { return false }
        ids.insert(id)
        defaults.set(seed(for: date), forKey: Keys.period)
        defaults.set(Array(ids), forKey: Keys.ids)
        didChange.send()
        return true
    }

    private func seed(for date: Date) -> Int {
        EngagementSchedule.dropPeriodSeed(for: date, calendar: calendar)
    }
}
