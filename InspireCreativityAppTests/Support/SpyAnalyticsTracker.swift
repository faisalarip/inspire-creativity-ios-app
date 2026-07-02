import Foundation
@testable import InspireCreativityApp

/// Records calls so tests can assert which events a view-model emits.
final class SpyAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var screens: [AnalyticsScreen] = []
    private(set) var collectionEnabledCalls: [Bool] = []
    private(set) var userProperties: [(name: String, value: String?)] = []

    func log(_ event: AnalyticsEvent) { events.append(event) }
    func track(screen: AnalyticsScreen) { screens.append(screen) }
    func setCollectionEnabled(_ on: Bool) { collectionEnabledCalls.append(on) }
    func set(_ property: AnalyticsUserProperty) { userProperties.append((property.name, property.value)) }

    var loggedNames: [String] { events.map(\.name) }
}
