//
//  AcquisitionAttribution.swift
//  InspireCreativityApp
//
//  Where did this user come from (Medium, X, YouTube, …)? iOS has no install
//  referrer and Firebase Dynamic Links is gone, so attribution is built from
//  two honest signals:
//    1. Self-reported — "Where did you find us?" at onboarding.
//    2. Measured — utm_source/utm_medium/utm_campaign on any URL that opens
//       the app (custom scheme or universal link). Measured beats
//       self-reported.
//  Both set the GA4 user property `acquisition_source` (which segments every
//  event, including purchase_completed) and log `campaign_details` so GA4's
//  acquisition reports pick the source up.
//

import Foundation

final class AcquisitionAttribution {

    private enum Keys {
        static let source = "engagement.acquisition.source"
        static let measured = "engagement.acquisition.measured"
    }

    private let defaults: UserDefaults
    private let analytics: AnalyticsTracking

    init(defaults: UserDefaults = .standard, analytics: AnalyticsTracking) {
        self.defaults = defaults
        self.analytics = analytics
        // Re-assert the property each launch — GA4 user properties don't
        // persist across app reinstalls of the SDK cache.
        if let source = defaults.string(forKey: Keys.source) {
            analytics.set(.acquisitionSource(source))
        }
    }

    /// Current attributed source, if any (e.g. "medium", "x", "youtube").
    var source: String? { defaults.string(forKey: Keys.source) }

    /// Self-reported source from onboarding. First write wins, and a
    /// measured (UTM) source is never overwritten by a survey answer.
    func setSelfReported(_ source: String) {
        guard defaults.string(forKey: Keys.source) == nil else { return }
        store(source: source, measured: false)
        analytics.log(.campaignDetails(source: source,
                                       medium: "self_reported",
                                       campaign: "onboarding_survey"))
    }

    /// Parses utm_* parameters from a URL that opened the app. Measured
    /// attribution overwrites anything self-reported.
    func handle(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else { return }
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        guard let source = value("utm_source") ?? value("src"), !source.isEmpty else { return }
        guard defaults.bool(forKey: Keys.measured) == false
                || source != defaults.string(forKey: Keys.source) else { return }

        store(source: source, measured: true)
        analytics.log(.campaignDetails(source: source,
                                       medium: value("utm_medium") ?? "referral",
                                       campaign: value("utm_campaign") ?? "none"))
    }

    private func store(source: String, measured: Bool) {
        defaults.set(source, forKey: Keys.source)
        defaults.set(measured, forKey: Keys.measured)
        analytics.set(.acquisitionSource(source))
    }
}
