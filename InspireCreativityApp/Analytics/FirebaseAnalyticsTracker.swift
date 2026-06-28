//
//  FirebaseAnalyticsTracker.swift
//  InspireCreativityApp
//
//  Production analytics backend. The ONLY file that imports Firebase, wrapped
//  entirely in `#if canImport(FirebaseAnalytics)` so the app still compiles on
//  slices that lack the package (e.g. CI without the plist). Firebase Analytics
//  (GA4) is integrated and live in the main app target. Maps the app's typed
//  events/screens onto GA4 via the Firebase Analytics SDK.
//

#if canImport(FirebaseAnalytics)
import Foundation
import FirebaseAnalytics

struct FirebaseAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func track(screen: AnalyticsScreen) {
        Analytics.logEvent(
            AnalyticsEventScreenView,
            parameters: [AnalyticsParameterScreenName: screen.rawValue]
        )
    }

    func setCollectionEnabled(_ on: Bool) {
        Analytics.setAnalyticsCollectionEnabled(on)
    }
}
#endif
