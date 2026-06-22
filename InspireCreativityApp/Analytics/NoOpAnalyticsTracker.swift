//
//  NoOpAnalyticsTracker.swift
//  InspireCreativityApp
//
//  Used in tests/previews and whenever GoogleService-Info.plist is absent.
//

import Foundation

struct NoOpAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {}
    func track(screen: AnalyticsScreen) {}
    func setCollectionEnabled(_ on: Bool) {}
}
