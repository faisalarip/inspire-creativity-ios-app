import XCTest
@testable import InspireCreativityApp

/// A Supabase row with a null/absent `is_pro` must NEVER leak as free.
/// Monetization fail-closed: if the server forgets the flag, the item is Pro.
final class RemoteCatalogFailClosedTests: XCTestCase {

    /// Minimal row as Supabase REST would return it when `is_pro` is null —
    /// the column is simply absent from the JSON object.
    private let rowWithoutIsPro = Data("""
    {
        "id": "test-null-pro",
        "name": "Null Flag",
        "category": "Backgrounds",
        "author": "Tester",
        "handle": "@tester",
        "description": "Row whose is_pro column is null",
        "palette": ["#FF0000", "#00FF00"]
    }
    """.utf8)

    func testNullIsProDecodesAsProItem() throws {
        let dto = try JSONDecoder().decode(AnimationDTO.self, from: rowWithoutIsPro)
        let item = try XCTUnwrap(dto.toAnimationItem())
        XCTAssertTrue(item.isPro,
                      "null is_pro must fail closed (Pro) — a missing server flag may not give paid content away")
    }

    func testNullIsProDecodesAsProAuroraDescriptor() throws {
        let dto = try JSONDecoder().decode(AnimationDTO.self, from: rowWithoutIsPro)
        let descriptor = try XCTUnwrap(dto.toAuroraDescriptor())
        XCTAssertTrue(descriptor.isPro,
                      "null is_pro must fail closed (Pro) in the runtime aurora descriptor too")
    }

    func testExplicitFalseStaysFree() throws {
        var json = String(data: rowWithoutIsPro, encoding: .utf8)!
        json = json.replacingOccurrences(of: "\"id\": \"test-null-pro\",",
                                         with: "\"id\": \"test-free\", \"is_pro\": false,")
        let dto = try JSONDecoder().decode(AnimationDTO.self, from: Data(json.utf8))
        let item = try XCTUnwrap(dto.toAnimationItem())
        XCTAssertFalse(item.isPro, "an explicit is_pro=false must still decode as free")
    }
}

/// Three-way gate for the code sheet. Purchasing never requires an account,
/// and a Pro entitlement unlocks code in ANY auth state — a signed-out buyer
/// (purchase or Restore) must never stay locked out (Guideline 5.1.1 risk).
final class CodeAccessTests: XCTestCase {

    func testProEntitlementGrantsRegardlessOfAuthOrTier() {
        for itemIsPro in [true, false] {
            for signedIn in [true, false] {
                XCTAssertEqual(
                    CodeAccess.evaluate(itemIsPro: itemIsPro,
                                        hasProEntitlement: true,
                                        isAuthenticated: signedIn),
                    .granted,
                    "Pro entitlement must unlock code (itemIsPro=\(itemIsPro), signedIn=\(signedIn))")
            }
        }
    }

    func testProItemWithoutEntitlementNeedsProInAnyAuthState() {
        for signedIn in [true, false] {
            XCTAssertEqual(
                CodeAccess.evaluate(itemIsPro: true,
                                    hasProEntitlement: false,
                                    isAuthenticated: signedIn),
                .needsPro,
                "Pro item without entitlement routes to the paywall, never to sign-in (signedIn=\(signedIn))")
        }
    }

    func testFreeItemNeedsSignInOnlyWhenSignedOut() {
        XCTAssertEqual(
            CodeAccess.evaluate(itemIsPro: false, hasProEntitlement: false, isAuthenticated: true),
            .granted)
        XCTAssertEqual(
            CodeAccess.evaluate(itemIsPro: false, hasProEntitlement: false, isAuthenticated: false),
            .needsSignIn)
    }
}

/// Production runs RemoteAnimationRepository; the aurora-first trending list
/// (commit cf4252c) must apply there too, not only to the in-memory repo.
final class TrendingParityTests: XCTestCase {

    /// Lead with free aurora backgrounds (the visual hook), then two popular
    /// hand-crafted pieces. Single source of truth for both repositories.
    private let auroraFirstTrending = ["au-nebula", "au-solar", "au-bokeh",
                                       "liquid-heart", "hologram-card"]

    func testRemoteTrendingLeadsWithAuroras() {
        let repo = RemoteAnimationRepository(seed: AnimationCatalogSeed.items)
        XCTAssertEqual(repo.trending().map(\.id), auroraFirstTrending,
                       "RemoteAnimationRepository.trending() drifted from the curated aurora-first list")
    }

    func testLocalTrendingLeadsWithAuroras() {
        let repo = InMemoryAnimationRepository()
        XCTAssertEqual(repo.trending().map(\.id), auroraFirstTrending,
                       "InMemoryAnimationRepository.trending() drifted from the curated aurora-first list")
    }

    func testNewlyAddedParityAcrossRepositories() {
        let remote = RemoteAnimationRepository(seed: AnimationCatalogSeed.items)
        let local = InMemoryAnimationRepository()
        XCTAssertEqual(remote.newlyAdded().map(\.id), local.newlyAdded().map(\.id),
                       "newlyAdded() must come from one shared curated list in both repositories")
    }
}
