//
//  NotificationPreferences.swift
//  InspireCreativityApp
//
//  User-tunable notification preferences (v2.0 "Notifications" screen).
//  Creators / price drops / trending persist for future server pushes but
//  schedule no local notifications today.
//

import Foundation

struct NotificationPreferences: Codable, Equatable {

    enum Frequency: String, Codable, CaseIterable {
        case realtime, daily, weekly

        var title: String {
            switch self {
            case .realtime: return "Real-time"
            case .daily: return "Daily digest"
            case .weekly: return "Weekly"
            }
        }
    }

    var isEnabled: Bool
    var fridayDrops: Bool
    var freeThisWeek: Bool
    var creators: Bool
    var priceDrops: Bool
    var trending: Bool
    var streakReminders: Bool
    var frequency: Frequency

    static let `default` = NotificationPreferences(
        isEnabled: true,
        fridayDrops: true,
        freeThisWeek: true,
        creators: true,
        priceDrops: true,
        trending: false,
        streakReminders: true,
        frequency: .realtime
    )

    private static let key = "engagement.notifications.prefs"

    static func load(from defaults: UserDefaults) -> NotificationPreferences {
        guard let data = defaults.data(forKey: key),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return .default
        }
        return prefs
    }

    func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
