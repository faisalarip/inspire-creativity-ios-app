//
//  AnalyticsTracking.swift
//  InspireCreativityApp
//
//  Abstraction over the analytics backend. Call sites depend on this; only
//  FirebaseAnalyticsTracker imports Firebase.
//

import Foundation

protocol AnalyticsTracking {
    func log(_ event: AnalyticsEvent)
    func track(screen: AnalyticsScreen)
    func setCollectionEnabled(_ on: Bool)
}
