import XCTest
@testable import InspireCreativityApp

/// Locks in the v1.1 "palette-true code generation" invariants for aurora
/// catalog items. Aurora seed items intentionally ship an EMPTY `swiftCode`
/// (generation is deferred off the launch path); the code sheet regenerates it
/// on demand from the item's descriptor via `DetailViewModel.code`. These tests
/// assert the user-facing guarantees on that RESOLVED code, not the seed field.
final class AuroraCodeGenTests: XCTestCase {

    // The aurora entries actually shipped in the seed catalog.
    private var auroraItems: [AnimationItem] {
        AnimationCatalogSeed.items.filter { $0.id.hasPrefix("au-") }
    }

    /// Mirrors `DetailViewModel.code`: aurora items defer codegen, so resolve
    /// the snippet on demand from the descriptor the same way the app does.
    private func resolvedCode(for item: AnimationItem) -> String {
        if !item.swiftCode.isEmpty { return item.swiftCode }
        if let descriptor = AuroraDescriptors.byId[item.id]
            ?? AnimationPreviewRegistry.runtimeDescriptors[item.id] {
            return AuroraCodeGen.swiftCode(for: descriptor)
        }
        return item.swiftCode
    }

    // MARK: - Seed invariants (on-demand codegen contract)

    /// Aurora seed items ship EMPTY swiftCode by design, so generation stays off
    /// the launch path. Re-baking it here would reintroduce the launch freeze.
    func testAuroraSeedItemsShipEmptySwiftCodeByDesign() {
        XCTAssertFalse(auroraItems.isEmpty, "expected aurora items in the seed catalog")
        for item in auroraItems {
            XCTAssertTrue(
                item.swiftCode.isEmpty,
                "\(item.id) bakes swiftCode into the seed; aurora codegen must stay deferred to DetailViewModel.code"
            )
        }
    }

    /// (a) Every aurora item has a descriptor and resolves on demand to
    /// non-empty code — i.e. the code sheet is never empty.
    func testEveryAuroraItemResolvesToNonEmptyCode() {
        XCTAssertFalse(auroraItems.isEmpty, "expected aurora items in the seed catalog")
        for item in auroraItems {
            XCTAssertNotNil(
                AuroraDescriptors.byId[item.id],
                "\(item.id) has no descriptor — its code sheet would be empty"
            )
            XCTAssertFalse(
                resolvedCode(for: item).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(item.id) resolves to empty code"
            )
        }
    }

    /// (b) No two aurora items resolve to identical code (palette-true
    /// uniqueness, preserved through on-demand generation).
    func testNoTwoAuroraItemsResolveToIdenticalCode() {
        var seen: [String: String] = [:]   // resolved code -> first id that used it
        for item in auroraItems {
            let code = resolvedCode(for: item)
            if let prior = seen[code] {
                XCTFail("\(item.id) resolves to identical code as \(prior)")
            }
            seen[code] = item.id
        }
        XCTAssertEqual(seen.count, auroraItems.count, "duplicate resolved code detected")
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

    /// What the user actually copies (the resolved on-demand code) is the
    /// generator output and contains every palette hex, for every descriptor
    /// that ships as a seed item.
    func testResolvedSeedCodeMatchesGeneratorAndContainsPalette() {
        let byId = AnimationCatalogSeed.items.reduce(into: [String: AnimationItem]()) { $0[$1.id] = $1 }
        for descriptor in AuroraDescriptors.all {
            guard let item = byId[descriptor.id] else {
                XCTFail("descriptor \(descriptor.id) has no seed item")
                continue
            }
            let resolved = resolvedCode(for: item)
            XCTAssertEqual(
                resolved,
                AuroraCodeGen.swiftCode(for: descriptor),
                "\(descriptor.id) resolved code is not the generated code"
            )
            for hex in descriptor.palette {
                XCTAssertTrue(resolved.contains(hex), "\(descriptor.id) resolved code missing \(hex)")
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
