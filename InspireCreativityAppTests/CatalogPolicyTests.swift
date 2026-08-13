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

/// Two-way gate for the code sheet. Purchasing never requires an account,
/// a Pro entitlement unlocks code in ANY auth state — and free code is open
/// to everyone: copying free code is the activation moment, never gate it
/// behind sign-in (analytics showed the wall cut ~77% of users off).
final class CodeAccessTests: XCTestCase {

    func testProEntitlementGrantsRegardlessOfTier() {
        for itemIsPro in [true, false] {
            XCTAssertEqual(
                CodeAccess.evaluate(itemIsPro: itemIsPro, hasProEntitlement: true),
                .granted,
                "Pro entitlement must unlock code (itemIsPro=\(itemIsPro))")
        }
    }

    func testProItemWithoutEntitlementNeedsPro() {
        XCTAssertEqual(
            CodeAccess.evaluate(itemIsPro: true, hasProEntitlement: false),
            .needsPro,
            "Pro item without entitlement routes to the paywall, never to sign-in")
    }

    func testFreeItemGrantedWithoutEntitlement() {
        XCTAssertEqual(
            CodeAccess.evaluate(itemIsPro: false, hasProEntitlement: false),
            .granted,
            "free code must be copyable with no account and no purchase")
    }
}

/// Discover rows are shuffled for a fresh feel each launch / pull-to-refresh,
/// so assert the structural contract (count, distinctness, validity, dynamism)
/// rather than a fixed curated list.
final class DiscoverRowsTests: XCTestCase {

    func testTrendingIsDistinctValidSample() {
        let repo = InMemoryAnimationRepository()
        let catalog = Set(repo.all().map(\.id))
        let trending = repo.trending()
        XCTAssertEqual(trending.count, CuratedRows.trendingCount)
        XCTAssertEqual(Set(trending.map(\.id)).count, trending.count, "trending rows must be distinct")
        XCTAssertTrue(trending.allSatisfy { catalog.contains($0.id) }, "trending items must exist in the catalog")
    }

    func testNewlyAddedIsDistinctValidSample() {
        let repo = InMemoryAnimationRepository()
        let catalog = Set(repo.all().map(\.id))
        let rows = repo.newlyAdded()
        XCTAssertEqual(rows.count, CuratedRows.newlyAddedCount)
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count, "newlyAdded rows must be distinct")
        XCTAssertTrue(rows.allSatisfy { catalog.contains($0.id) }, "newlyAdded items must exist in the catalog")
    }

    /// With 300+ items choosing 8, two shuffled draws are effectively never identical.
    func testTrendingIsDynamic() {
        let repo = InMemoryAnimationRepository()
        XCTAssertNotEqual(repo.trending().map(\.id), repo.trending().map(\.id),
                          "trending should vary between calls (shuffled)")
    }

    func testRemoteRowsMatchLocalShape() {
        let remote = RemoteAnimationRepository(seed: AnimationCatalogSeed.items)
        let local = InMemoryAnimationRepository()
        XCTAssertEqual(remote.trending().count, local.trending().count)
        XCTAssertEqual(remote.newlyAdded().count, local.newlyAdded().count)
    }
}
