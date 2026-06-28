//
//  AnalyticsConsent.swift
//  InspireCreativityApp
//
//  Pure decision type for EEA/UK analytics opt-in gate.
//  Cross-platform (no #if os(...)). Non-EEA behavior is byte-for-byte
//  unchanged: collection follows the existing `analyticsEnabled` flag.
//

import Foundation

enum AnalyticsConsent {

    // MARK: - Decision

    /// The user's stored consent choice. nil means undecided (no prompt answered yet).
    enum Decision: String, Codable {
        case granted
        case denied
    }

    // MARK: - EEA / UK region set

    /// EU-27 + EEA (IS, LI, NO) + United Kingdom (GB).
    private static let eeaAndUKRegions: Set<String> = [
        // EU-27
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        // EEA non-EU
        "IS", "LI", "NO",
        // UK (post-Brexit, UK GDPR applies)
        "GB"
    ]

    // MARK: - Pure decision functions

    /// Returns true when `regionCode` falls within the EEA or UK.
    /// A nil regionCode is treated as non-EEA.
    static func isEEAOrUK(regionCode: String?) -> Bool {
        guard let code = regionCode else { return false }
        return eeaAndUKRegions.contains(code)
    }

    /// Returns true when the user is in EEA/UK and has not yet made a decision.
    /// Non-EEA users never need the prompt; EEA users who have already
    /// granted or denied do not need it either.
    static func needsPrompt(regionCode: String?, decision: Decision?) -> Bool {
        isEEAOrUK(regionCode: regionCode) && decision == nil
    }

    /// Determines whether analytics collection should be active.
    ///
    /// - EEA/UK: only `decision == .granted` enables collection.
    ///   `analyticsEnabled` is intentionally ignored for EEA/UK users —
    ///   consent is the exclusive gate (GDPR Art. 7). This means:
    ///   - `.granted` → collection ON regardless of `analyticsEnabled`.
    ///   - `.denied` or nil → collection OFF regardless of `analyticsEnabled`.
    ///   Consequence: the Settings analytics toggle has no effect for EEA/UK
    ///   users who have already made a decision. Future work: wire the toggle
    ///   to update the stored `Decision` for EEA users, or hide/disable it.
    ///
    /// - Non-EEA: returns `analyticsEnabled` unchanged — byte-for-byte the
    ///   same behavior as before the consent gate was introduced.
    static func collectionAllowed(
        regionCode: String?,
        decision: Decision?,
        analyticsEnabled: Bool
    ) -> Bool {
        if isEEAOrUK(regionCode: regionCode) {
            return decision == .granted
        }
        return analyticsEnabled
    }

    // MARK: - Persistence

    /// Default UserDefaults key for the stored decision.
    static let defaultKey = "analyticsConsentDecision"

    /// UserDefaults key for the global analytics-enabled toggle (mirrors SettingsView @AppStorage).
    /// Centralised here so AppContainer, SettingsView, and the consent modifier all read
    /// the same key string without risk of drift.
    static let analyticsEnabledKey = "analyticsEnabled"

    /// Reads the stored decision from `defaults` using `key`.
    /// Returns nil when no decision has been recorded.
    static func storedDecision(
        defaults: UserDefaults = .standard,
        key: String = defaultKey
    ) -> Decision? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return Decision(rawValue: raw)
    }

    /// Persists `decision` in `defaults` using `key`.
    static func storeDecision(
        _ decision: Decision,
        defaults: UserDefaults = .standard,
        key: String = defaultKey
    ) {
        defaults.set(decision.rawValue, forKey: key)
    }
}
