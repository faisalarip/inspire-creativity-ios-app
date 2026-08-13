//
//  NotificationScheduling.swift
//  InspireCreativityApp
//
//  Thin protocol over UNUserNotificationCenter so coordinator logic can be
//  tested with a spy. SystemNotificationScheduler is the only untested piece
//  and contains no logic.
//

import Foundation
import UserNotifications

enum NotificationAuthorization: String {
    case notDetermined, denied, authorized
}

protocol NotificationScheduling: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func removeAllPending()
    func schedule(_ plan: NotificationPlan)
}

final class SystemNotificationScheduler: NotificationScheduling {

    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized // authorized / provisional / ephemeral
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    func schedule(_ plan: NotificationPlan) {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = plan.weekday
        comps.hour = plan.hour
        comps.minute = plan.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
    }
}
