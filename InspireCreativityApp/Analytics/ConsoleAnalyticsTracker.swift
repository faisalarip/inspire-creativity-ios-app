//
//  ConsoleAnalyticsTracker.swift
//  InspireCreativityApp
//
//  DEBUG-only echo so events are verifiable locally without a backend.
//

import Foundation

struct ConsoleAnalyticsTracker: AnalyticsTracking {
    func log(_ event: AnalyticsEvent) {
        print("[analytics] event=\(event.name) params=\(event.parameters)")
    }
    func track(screen: AnalyticsScreen) {
        print("[analytics] screen_view screen=\(screen.rawValue)")
    }
    func setCollectionEnabled(_ on: Bool) {
        print("[analytics] collection_enabled=\(on)")
    }
}
