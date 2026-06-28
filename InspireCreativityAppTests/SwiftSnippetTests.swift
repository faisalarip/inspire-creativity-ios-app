//
//  SwiftSnippetTests.swift
//  InspireCreativityAppTests
//
//  Tests for SwiftSnippet.fileName(for:) and SwiftSource.bodyWithoutImports(_:).
//

import XCTest
@testable import InspireCreativityApp

final class SwiftSnippetTests: XCTestCase {
    func test_fileName_camelCasesAndAppendsSwift() {
        XCTAssertEqual(SwiftSnippet.fileName(for: "Liquid Heart!"), "LiquidHeart.swift")
    }

    func test_fileName_fallsBackWhenEmpty() {
        XCTAssertEqual(SwiftSnippet.fileName(for: "—"), "Animation.swift")
    }

    func test_bodyWithoutImports_dropsLeadingImports() {
        let src = "import SwiftUI\n\nstruct V: View { var body: some View { Text(\"hi\") } }"
        XCTAssertFalse(SwiftSource.bodyWithoutImports(src).contains("import SwiftUI"))
        XCTAssertTrue(SwiftSource.bodyWithoutImports(src).contains("struct V"))
    }
}
