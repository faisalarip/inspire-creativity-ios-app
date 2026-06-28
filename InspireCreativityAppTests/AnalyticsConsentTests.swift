//
//  AnalyticsConsentTests.swift
//  InspireCreativityAppTests
//
//  TDD tests for AnalyticsConsent — pure decision type.
//  EEA/UK users require prior opt-in; non-EEA follows analyticsEnabled unchanged.
//

import XCTest
@testable import InspireCreativityApp

final class AnalyticsConsentTests: XCTestCase {

    // MARK: - isEEAOrUK

    func test_isEEAOrUK_returnsTrue_forEU27Members() {
        let eu27 = ["AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR",
                    "DE","GR","HU","IE","IT","LV","LT","LU","MT","NL",
                    "PL","PT","RO","SK","SI","ES","SE"]
        for code in eu27 {
            XCTAssertTrue(AnalyticsConsent.isEEAOrUK(regionCode: code),
                          "\(code) should be EEA")
        }
    }

    func test_isEEAOrUK_returnsTrue_forEEANonEU() {
        for code in ["IS", "LI", "NO"] {
            XCTAssertTrue(AnalyticsConsent.isEEAOrUK(regionCode: code),
                          "\(code) should be EEA")
        }
    }

    func test_isEEAOrUK_returnsTrue_forGB() {
        XCTAssertTrue(AnalyticsConsent.isEEAOrUK(regionCode: "GB"))
    }

    func test_isEEAOrUK_returnsFalse_forUS() {
        XCTAssertFalse(AnalyticsConsent.isEEAOrUK(regionCode: "US"))
    }

    func test_isEEAOrUK_returnsFalse_forNil() {
        XCTAssertFalse(AnalyticsConsent.isEEAOrUK(regionCode: nil))
    }

    func test_isEEAOrUK_returnsFalse_forAU() {
        XCTAssertFalse(AnalyticsConsent.isEEAOrUK(regionCode: "AU"))
    }

    func test_isEEAOrUK_returnsFalse_forCA() {
        XCTAssertFalse(AnalyticsConsent.isEEAOrUK(regionCode: "CA"))
    }

    func test_isEEAOrUK_returnsFalse_forJP() {
        XCTAssertFalse(AnalyticsConsent.isEEAOrUK(regionCode: "JP"))
    }

    // MARK: - needsPrompt

    func test_needsPrompt_trueWhenEEA_andNilDecision() {
        XCTAssertTrue(AnalyticsConsent.needsPrompt(regionCode: "DE", decision: nil))
        XCTAssertTrue(AnalyticsConsent.needsPrompt(regionCode: "FR", decision: nil))
        XCTAssertTrue(AnalyticsConsent.needsPrompt(regionCode: "GB", decision: nil))
    }

    func test_needsPrompt_falseWhenEEA_andDecisionGranted() {
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: "DE", decision: .granted))
    }

    func test_needsPrompt_falseWhenEEA_andDecisionDenied() {
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: "DE", decision: .denied))
    }

    func test_needsPrompt_falseWhenNonEEA_regardlessOfDecision() {
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: "US", decision: nil))
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: "US", decision: .granted))
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: "US", decision: .denied))
    }

    func test_needsPrompt_falseWhenNilRegion_andNilDecision() {
        XCTAssertFalse(AnalyticsConsent.needsPrompt(regionCode: nil, decision: nil))
    }

    // MARK: - collectionAllowed (the full matrix)

    // Non-EEA: follows analyticsEnabled, decision is irrelevant
    func test_collectionAllowed_US_nilDecision_analyticsOn_isTrue() {
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "US", decision: nil, analyticsEnabled: true))
    }

    func test_collectionAllowed_US_nilDecision_analyticsOff_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "US", decision: nil, analyticsEnabled: false))
    }

    func test_collectionAllowed_US_grantedDecision_analyticsOn_isTrue() {
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "US", decision: .granted, analyticsEnabled: true))
    }

    func test_collectionAllowed_US_deniedDecision_analyticsOn_isTrue() {
        // Non-EEA: analyticsEnabled wins regardless of decision
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "US", decision: .denied, analyticsEnabled: true))
    }

    func test_collectionAllowed_US_deniedDecision_analyticsOff_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "US", decision: .denied, analyticsEnabled: false))
    }

    // EEA: only decision==.granted allows collection; analyticsEnabled is irrelevant until decided
    func test_collectionAllowed_DE_nilDecision_analyticsOn_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: nil, analyticsEnabled: true))
    }

    func test_collectionAllowed_DE_nilDecision_analyticsOff_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: nil, analyticsEnabled: false))
    }

    func test_collectionAllowed_DE_granted_analyticsOn_isTrue() {
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: .granted, analyticsEnabled: true))
    }

    func test_collectionAllowed_DE_granted_analyticsOff_isTrue() {
        // EEA: granted overrides analyticsEnabled=false
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: .granted, analyticsEnabled: false))
    }

    func test_collectionAllowed_DE_denied_analyticsOn_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: .denied, analyticsEnabled: true))
    }

    func test_collectionAllowed_DE_denied_analyticsOff_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "DE", decision: .denied, analyticsEnabled: false))
    }

    // GB treated same as EEA
    func test_collectionAllowed_GB_nilDecision_analyticsOn_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "GB", decision: nil, analyticsEnabled: true))
    }

    func test_collectionAllowed_GB_granted_isTrue() {
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: "GB", decision: .granted, analyticsEnabled: true))
    }

    func test_collectionAllowed_GB_denied_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: "GB", decision: .denied, analyticsEnabled: true))
    }

    // nil region treated as non-EEA
    func test_collectionAllowed_nilRegion_analyticsOn_isTrue() {
        XCTAssertTrue(AnalyticsConsent.collectionAllowed(
            regionCode: nil, decision: nil, analyticsEnabled: true))
    }

    func test_collectionAllowed_nilRegion_analyticsOff_isFalse() {
        XCTAssertFalse(AnalyticsConsent.collectionAllowed(
            regionCode: nil, decision: nil, analyticsEnabled: false))
    }

    // MARK: - decisionForToggle

    func test_decisionForToggle_EEA_on_returnsGranted() {
        XCTAssertEqual(AnalyticsConsent.decisionForToggle(regionCode: "DE", on: true), .granted)
    }

    func test_decisionForToggle_EEA_off_returnsDenied() {
        XCTAssertEqual(AnalyticsConsent.decisionForToggle(regionCode: "DE", on: false), .denied)
    }

    func test_decisionForToggle_GB_on_returnsGranted() {
        XCTAssertEqual(AnalyticsConsent.decisionForToggle(regionCode: "GB", on: true), .granted)
    }

    func test_decisionForToggle_GB_off_returnsDenied() {
        XCTAssertEqual(AnalyticsConsent.decisionForToggle(regionCode: "GB", on: false), .denied)
    }

    func test_decisionForToggle_nonEEA_US_returnsNil() {
        XCTAssertNil(AnalyticsConsent.decisionForToggle(regionCode: "US", on: true))
        XCTAssertNil(AnalyticsConsent.decisionForToggle(regionCode: "US", on: false))
    }

    func test_decisionForToggle_nilRegion_returnsNil() {
        XCTAssertNil(AnalyticsConsent.decisionForToggle(regionCode: nil, on: true))
        XCTAssertNil(AnalyticsConsent.decisionForToggle(regionCode: nil, on: false))
    }

    // MARK: - EEA withdrawal end-to-end

    /// After an EEA user withdraws consent via the toggle (decision stored as .denied),
    /// collectionAllowed must return false even when analyticsEnabled is true.
    func test_eeaWithdrawal_collectionNotAllowed_whenDecisionDenied_andAnalyticsEnabled() {
        // Simulate: user previously granted, now withdraws by toggling OFF.
        // decisionForToggle returns .denied for EEA; caller stores it.
        let region = "FR"
        let withdrawDecision = AnalyticsConsent.decisionForToggle(regionCode: region, on: false)
        XCTAssertEqual(withdrawDecision, .denied, "Toggling OFF for EEA must map to .denied")

        // After storing .denied, collectionAllowed must be false regardless of analyticsEnabled.
        XCTAssertFalse(
            AnalyticsConsent.collectionAllowed(regionCode: region, decision: .denied, analyticsEnabled: true),
            "Collection must stop after EEA withdrawal even with analyticsEnabled=true"
        )
    }

    // MARK: - Decision Codable / raw value

    func test_decision_rawValues() {
        XCTAssertEqual(AnalyticsConsent.Decision.granted.rawValue, "granted")
        XCTAssertEqual(AnalyticsConsent.Decision.denied.rawValue, "denied")
    }

    func test_decision_roundTripsFromRawValue() {
        XCTAssertEqual(AnalyticsConsent.Decision(rawValue: "granted"), .granted)
        XCTAssertEqual(AnalyticsConsent.Decision(rawValue: "denied"), .denied)
        XCTAssertNil(AnalyticsConsent.Decision(rawValue: "unknown"))
    }

    // MARK: - Persistence (storedDecision / storeDecision)

    func test_storedDecision_returnsNil_whenNothingPersisted() {
        let key = "analyticsConsentDecision_test_\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        // Use isolated key to avoid cross-test bleed
        let result = AnalyticsConsent.storedDecision(defaults: .standard, key: key)
        XCTAssertNil(result)
    }

    func test_storeAndRetrieve_granted() {
        let key = "analyticsConsentDecision_test_\(UUID().uuidString)"
        AnalyticsConsent.storeDecision(.granted, defaults: .standard, key: key)
        XCTAssertEqual(AnalyticsConsent.storedDecision(defaults: .standard, key: key), .granted)
    }

    func test_storeAndRetrieve_denied() {
        let key = "analyticsConsentDecision_test_\(UUID().uuidString)"
        AnalyticsConsent.storeDecision(.denied, defaults: .standard, key: key)
        XCTAssertEqual(AnalyticsConsent.storedDecision(defaults: .standard, key: key), .denied)
    }
}
