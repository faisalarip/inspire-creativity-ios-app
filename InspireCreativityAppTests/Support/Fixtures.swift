//
//  Fixtures.swift
//  InspireCreativityAppTests
//
//  Shared builders for domain entities used across unit tests.
//

import Foundation
@testable import InspireCreativityApp

enum Fixtures {

    static func item(
        id: String,
        name: String? = nil,
        category: AnimationCategory = .buttons,
        isPro: Bool = false,
        downloads: Int = 100,
        rating: Double = 4.5,
        author: String = "InspireCreativity",
        swiftCode: String = "struct Demo: View { var body: some View { Text(\"hi\") } }"
    ) -> AnimationItem {
        AnimationItem(
            id: id,
            name: name ?? id.capitalized,
            category: category,
            difficulty: .beginner,
            iosVersion: "17+",
            isPro: isPro,
            isFeatured: false,
            tintHex: "#1e1e22",
            author: author,
            handle: "@inspirecreativity",
            downloads: downloads,
            rating: rating,
            price: isPro ? 10 : nil,
            description: "Test item",
            swiftCode: swiftCode
        )
    }

    /// Gregorian calendar pinned to UTC so date math in tests is deterministic.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0
    ) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return utcCalendar.date(from: comps)!
    }

    static func freshDefaults(_ label: String) -> UserDefaults {
        let suite = "\(label).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
