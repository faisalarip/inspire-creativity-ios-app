//
//  EngagementNotificationPlanner.swift
//  InspireCreativityApp
//
//  Pure mapping from preferences → local notification plans. Copy comes from
//  the v2.0 design's lock-screen artboard. Kept UN-framework-free so it is
//  trivially unit-testable.
//

import Foundation

struct NotificationPlan: Equatable {
    let id: String
    let title: String
    let body: String
    /// Gregorian weekday (1 = Sunday … 6 = Friday); nil repeats daily.
    let weekday: Int?
    let hour: Int
    let minute: Int
}

enum EngagementNotificationPlanner {

    static func plans(for prefs: NotificationPreferences, streak: Int) -> [NotificationPlan] {
        guard prefs.isEnabled else { return [] }
        var plans: [NotificationPlan] = []
        if prefs.fridayDrops {
            plans.append(NotificationPlan(
                id: "engagement.drop.friday",
                title: "🎁 Friday Drop is live",
                body: "5 new animations just landed. One is always free this week.",
                weekday: 6, hour: 8, minute: 0
            ))
        }
        if prefs.freeThisWeek {
            plans.append(NotificationPlan(
                id: "engagement.free.friday",
                title: "Free this week rotated",
                body: "A new set of free animations is live. Grab them before next Friday.",
                weekday: 6, hour: 9, minute: 0
            ))
        }
        if prefs.streakReminders, streak >= 1 {
            plans.append(NotificationPlan(
                id: "engagement.streak.daily",
                title: "🔥 \(streak)-day streak",
                body: "Your daily pick is ready. 30 seconds to stay inspired.",
                weekday: nil, hour: 19, minute: 30
            ))
        }
        return plans
    }
}
