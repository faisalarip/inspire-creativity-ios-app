import XCTest
@testable import InspireCreativityApp

/// Locks in the v1.1 "palette-true code generation" invariants for aurora
/// catalog items. Previously every aurora item shipped the byte-identical
/// `Code.auroraMesh` sample; these tests guarantee each item now carries a
/// self-contained, palette-true Swift snippet generated from its descriptor.
final class AuroraCodeGenTests: XCTestCase {

    // The aurora entries actually shipped in the seed catalog.
    private var auroraItems: [AnimationItem] {
        AnimationCatalogSeed.items.filter { $0.id.hasPrefix("au-") }
    }

    // MARK: - Seed invariants

    /// (a) Every aurora seed item has non-empty swiftCode.
    func testEveryAuroraItemHasNonEmptySwiftCode() {
        XCTAssertFalse(auroraItems.isEmpty, "expected aurora items in the seed catalog")
        for item in auroraItems {
            XCTAssertFalse(
                item.swiftCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(item.id) has empty swiftCode"
            )
        }
    }

    /// (b) No two aurora items share identical swiftCode.
    func testNoTwoAuroraItemsShareIdenticalSwiftCode() {
        var seen: [String: String] = [:]   // swiftCode -> first id that used it
        for item in auroraItems {
            if let prior = seen[item.swiftCode] {
                XCTFail("\(item.id) shares identical swiftCode with \(prior)")
            }
            seen[item.swiftCode] = item.id
        }
        XCTAssertEqual(seen.count, auroraItems.count, "duplicate swiftCode detected")
    }

    /// (c) Each item's generated code contains every one of its palette hex strings.
    func testGeneratedCodeContainsEveryPaletteHex() {
        for descriptor in AuroraDescriptors.all {
            let code = AuroraCodeGen.swiftCode(for: descriptor)
            for hex in descriptor.palette {
                XCTAssertTrue(
                    code.contains(hex),
                    "\(descriptor.id) (\(descriptor.engine)) code missing palette hex \(hex)"
                )
            }
        }
    }

    /// The seed items' swiftCode is the generated code (not a hardcoded sample),
    /// so the palette-hex guarantee holds for what actually ships, too.
    func testSeedItemSwiftCodeMatchesGeneratorAndContainsPalette() {
        let byId = AnimationCatalogSeed.items.reduce(into: [String: AnimationItem]()) { $0[$1.id] = $1 }
        for descriptor in AuroraDescriptors.all {
            guard let item = byId[descriptor.id] else {
                XCTFail("descriptor \(descriptor.id) has no seed item")
                continue
            }
            XCTAssertEqual(
                item.swiftCode,
                AuroraCodeGen.swiftCode(for: descriptor),
                "\(descriptor.id) seed swiftCode is not the generated code"
            )
            for hex in descriptor.palette {
                XCTAssertTrue(item.swiftCode.contains(hex), "\(descriptor.id) shipped code missing \(hex)")
            }
        }
    }

    /// (d) Generated code contains the engine-appropriate structural markers.
    func testGeneratedCodeContainsEngineStructuralMarkers() {
        for descriptor in AuroraDescriptors.all {
            let code = AuroraCodeGen.swiftCode(for: descriptor)

            // Self-contained contract: imports SwiftUI, embeds a local Color(hex:),
            // and never references the app's internal HexColor extension.
            XCTAssertTrue(code.contains("import SwiftUI"), "\(descriptor.id) missing import SwiftUI")
            XCTAssertTrue(code.contains("init(hex:"), "\(descriptor.id) missing local Color(hex:) initializer")
            XCTAssertFalse(code.contains("Theme.Palette"), "\(descriptor.id) leaks internal Theme.Palette")

            switch descriptor.engine {
            case .mesh, .goo:
                // Radial blobs drifting on cos/sin offsets, screen-blended.
                XCTAssertTrue(code.contains("RadialGradient"), "\(descriptor.id) mesh/goo missing RadialGradient")
                XCTAssertTrue(code.contains(".blendMode(.screen)"), "\(descriptor.id) mesh/goo missing screen blend")
            case .spin:
                XCTAssertTrue(code.contains("AngularGradient"), "\(descriptor.id) spin missing AngularGradient")
                XCTAssertTrue(code.contains("rotationEffect"), "\(descriptor.id) spin missing rotationEffect")
            case .bloom:
                XCTAssertTrue(code.contains("RadialGradient"), "\(descriptor.id) bloom missing RadialGradient")
                XCTAssertTrue(code.contains("pulse"), "\(descriptor.id) bloom missing pulse")
            case .streaks:
                XCTAssertTrue(code.contains("Capsule"), "\(descriptor.id) streaks missing Capsule")
                XCTAssertTrue(code.contains("LinearGradient"), "\(descriptor.id) streaks missing LinearGradient")
            }
        }
    }

    /// (e) Seed ids are unique (catches descriptor-table dupes feeding the catalog).
    func testSeedIdsAreUnique() {
        let ids = AnimationCatalogSeed.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in the seed catalog")
    }

    // MARK: - Generator directly

    func testGeneratorIsDeterministic() {
        for descriptor in AuroraDescriptors.all.prefix(5) {
            XCTAssertEqual(
                AuroraCodeGen.swiftCode(for: descriptor),
                AuroraCodeGen.swiftCode(for: descriptor),
                "\(descriptor.id) generator is not deterministic"
            )
        }
    }

    /// Every one of the five engines is exercised by the descriptor table, so the
    /// per-engine template paths are all covered by the tests above.
    func testAllEnginesAreRepresented() {
        let engines = Set(AuroraDescriptors.all.map(\.engine))
        XCTAssertTrue(engines.contains(.mesh))
        XCTAssertTrue(engines.contains(.spin))
        XCTAssertTrue(engines.contains(.bloom))
        XCTAssertTrue(engines.contains(.streaks))
        XCTAssertTrue(engines.contains(.goo))
    }
}
