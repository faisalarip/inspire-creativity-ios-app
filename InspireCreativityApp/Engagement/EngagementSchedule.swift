//
//  EngagementSchedule.swift
//  InspireCreativityApp
//
//  Pure date/rotation math behind the v2.0 engagement layer: the daily pick,
//  the Friday Drop countdown, the weekly free rotation and the challenge
//  window. No side effects — everything takes an explicit date + calendar.
//

import Foundation

enum EngagementSchedule {

    /// Deterministic pick of the day: stable within a calendar day, rotates daily.
    static func dailyPick(from items: [AnimationItem], on date: Date, calendar: Calendar) -> AnimationItem? {
        guard !items.isEmpty else { return nil }
        let sorted = items.sorted { $0.id < $1.id }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return sorted[day % sorted.count]
    }

    /// Seconds until the daily pick resets (next local midnight).
    static func dailyPickResetsIn(from date: Date, calendar: Calendar) -> TimeInterval {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return 0 }
        return max(0, calendar.startOfDay(for: tomorrow).timeIntervalSince(date))
    }

    /// "resets in 9h" (hours rounded up; minutes under one hour).
    static func dailyResetLabel(from date: Date, calendar: Calendar) -> String {
        let remaining = dailyPickResetsIn(from: date, calendar: calendar)
        if remaining >= 3600 {
            return "resets in \(Int((remaining / 3600).rounded(.up)))h"
        }
        return "resets in \(max(1, Int((remaining / 60).rounded(.up))))m"
    }

    /// Drops land twice a week: Tuesday and Friday at 08:00 local. Returns
    /// whichever comes next (today 08:00 if still ahead).
    static func nextDrop(after date: Date, calendar: Calendar) -> Date {
        let candidates = [3, 6].compactMap { weekday -> Date? in // Tue, Fri
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = 8
            comps.minute = 0
            return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
        }
        return candidates.min() ?? date
    }

    /// "in 2d 14h" / "in 14h 5m" / "in 5m" / "now".
    static func countdownLabel(to target: Date, from now: Date) -> String {
        let remaining = Int(target.timeIntervalSince(now))
        guard remaining > 0 else { return "now" }
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        if days > 0 { return "in \(days)d \(hours)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(max(1, minutes))m"
    }

    /// Deterministic 4 free items for the week containing `date`; rotates each week.
    static func freeThisWeek(from items: [AnimationItem], on date: Date, calendar: Calendar) -> [AnimationItem] {
        let free = items.filter(\.isFree).sorted { $0.id < $1.id }
        guard free.count > 4 else { return free }
        let seed = calendar.component(.yearForWeekOfYear, from: date) * 100
            + calendar.component(.weekOfYear, from: date)
        let start = (seed * 4) % free.count
        return (0..<4).map { free[(start + $0) % free.count] }
    }

    /// Identifies the drop period (drop → next drop) that `date` falls in.
    /// Stable within a period, changes exactly at each Tue/Fri 08:00 drop —
    /// used by the Pro-copy meter so allowances reset with every drop.
    static func dropPeriodSeed(for date: Date, calendar: Calendar) -> Int {
        Int(nextDrop(after: date, calendar: calendar).timeIntervalSince1970)
    }

    /// The 5 "new in this drop" animations: deterministic per drop period,
    /// rotating through the whole catalog — with 300+ bundled items that is
    /// months of twice-weekly freshness before a repeat.
    static func dropPicks(from items: [AnimationItem], on date: Date, calendar: Calendar) -> [AnimationItem] {
        guard !items.isEmpty else { return [] }
        let sorted = items.sorted { $0.id < $1.id }
        // Consecutive periods advance by 5 so drops never overlap until the
        // catalog wraps. Period seeds are drop timestamps ~3-4 days apart;
        // dividing by a period-length lower bound yields a stable ordinal.
        let ordinal = dropPeriodSeed(for: date, calendar: calendar) / (3 * 86_400)
        let start = ((ordinal * 5) % sorted.count + sorted.count) % sorted.count
        return (0..<min(5, sorted.count)).map { sorted[(start + $0) % sorted.count] }
    }

    /// Days until the weekly challenge closes (Sunday): "3d left" / "ends today".
    static func challengeDaysLeftLabel(from date: Date, calendar: Calendar) -> String {
        guard calendar.component(.weekday, from: date) != 1 else { return "ends today" }
        var comps = DateComponents()
        comps.weekday = 1 // Sunday
        guard let sunday = calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime) else {
            return ""
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: sunday)
        ).day ?? 0
        return days <= 0 ? "ends today" : "\(days)d left"
    }
}
