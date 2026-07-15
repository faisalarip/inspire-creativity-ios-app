//
//  NotificationCoordinator.swift
//  InspireCreativityApp
//
//  Owns notification preferences + authorization state and keeps the pending
//  local notifications in sync with them (reapplied on every app activation).
//

import Combine
import Foundation

@MainActor
final class NotificationCoordinator: ObservableObject {

    @Published private(set) var preferences: NotificationPreferences
    @Published private(set) var authorization: NotificationAuthorization = .notDetermined

    private let scheduler: NotificationScheduling
    private let defaults: UserDefaults
    private let analytics: AnalyticsTracking

    init(
        scheduler: NotificationScheduling,
        defaults: UserDefaults = .standard,
        analytics: AnalyticsTracking
    ) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.analytics = analytics
        self.preferences = NotificationPreferences.load(from: defaults)
    }

    /// The Discover "Remind me" state: drops reminder scheduled and allowed.
    var isRemindMeActive: Bool {
        authorization == .authorized && preferences.isEnabled && preferences.fridayDrops
    }

    func refreshAuthorization() async {
        authorization = await scheduler.authorizationStatus()
    }

    /// Presents the system permission prompt; on grant, turns the master
    /// switch on and schedules. Logs the outcome either way.
    @discardableResult
    func requestPermission(streak: Int) async -> Bool {
        let granted = await scheduler.requestAuthorization()
        analytics.log(.notificationPermission(granted: granted))
        await refreshAuthorization()
        if granted {
            var prefs = preferences
            prefs.isEnabled = true
            update(prefs, streak: streak)
        }
        return granted
    }

    func update(_ prefs: NotificationPreferences, streak: Int) {
        preferences = prefs
        prefs.save(to: defaults)
        apply(streak: streak)
    }

    /// Reconciles pending notifications with current auth + preferences.
    func apply(streak: Int) {
        scheduler.removeAllPending()
        guard authorization == .authorized, preferences.isEnabled else { return }
        for plan in EngagementNotificationPlanner.plans(for: preferences, streak: streak) {
            scheduler.schedule(plan)
        }
    }
}
