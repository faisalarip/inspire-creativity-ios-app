//
//  AcquisitionAttributionTests.swift
//  InspireCreativityAppTests
//

import XCTest
@testable import InspireCreativityApp

final class AcquisitionAttributionTests: XCTestCase {

    func testSelfReportedSetsPropertyAndCampaignOnce() {
        let spy = SpyAnalyticsTracker()
        let attribution = AcquisitionAttribution(defaults: Fixtures.freshDefaults("acq"), analytics: spy)

        attribution.setSelfReported("medium")
        XCTAssertEqual(attribution.source, "medium")
        XCTAssertTrue(spy.userProperties.contains { $0.name == "acquisition_source" && $0.value == "medium" })
        XCTAssertEqual(spy.loggedNames, ["campaign_details"])
        XCTAssertEqual(spy.events.last?.parameters["medium"] as? String, "self_reported")

        attribution.setSelfReported("youtube")
        XCTAssertEqual(attribution.source, "medium", "first self-report wins")
        XCTAssertEqual(spy.loggedNames.count, 1)
    }

    func testMeasuredUTMOverridesSelfReported() {
        let spy = SpyAnalyticsTracker()
        let attribution = AcquisitionAttribution(defaults: Fixtures.freshDefaults("acq"), analytics: spy)
        attribution.setSelfReported("friend")

        let url = URL(string: "inspirecreativity://open?utm_source=Medium&utm_medium=blog&utm_campaign=aurora_post")!
        attribution.handle(url: url)

        XCTAssertEqual(attribution.source, "medium", "measured beats self-reported, lowercased")
        let last = spy.events.last
        XCTAssertEqual(last?.name, "campaign_details")
        XCTAssertEqual(last?.parameters["source"] as? String, "medium")
        XCTAssertEqual(last?.parameters["medium"] as? String, "blog")
        XCTAssertEqual(last?.parameters["campaign"] as? String, "aurora_post")
    }

    func testURLWithoutUTMIsIgnored() {
        let spy = SpyAnalyticsTracker()
        let attribution = AcquisitionAttribution(defaults: Fixtures.freshDefaults("acq"), analytics: spy)
        attribution.handle(url: URL(string: "inspirecreativity://open/detail?id=aurora-mesh")!)
        XCTAssertNil(attribution.source)
        XCTAssertTrue(spy.events.isEmpty)
    }

    func testSourceReassertedOnLaunch() {
        let defaults = Fixtures.freshDefaults("acq")
        AcquisitionAttribution(defaults: defaults, analytics: SpyAnalyticsTracker()).setSelfReported("x")

        let spy = SpyAnalyticsTracker()
        _ = AcquisitionAttribution(defaults: defaults, analytics: spy)
        XCTAssertTrue(spy.userProperties.contains { $0.name == "acquisition_source" && $0.value == "x" },
                      "user property must be re-set each launch")
    }
}
