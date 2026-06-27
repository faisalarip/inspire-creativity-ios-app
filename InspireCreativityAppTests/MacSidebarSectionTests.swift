import XCTest
@testable import InspireCreativityApp

final class MacSidebarSectionTests: XCTestCase {
    func test_all_startsWithDiscover_thenCategories_thenLibrary() {
        // Explicit element-level cast avoids ObjC runtime.h Category typedef ambiguity.
        let cats = [Category.backgrounds, Category.metalShaders]
        let sections = MacSidebarSection.all(categories: cats)
        XCTAssertEqual(sections.first, .discover)
        XCTAssertTrue(sections.contains(.category(.backgrounds)))
        XCTAssertEqual(sections.suffix(3), [.owned, .favorites, .recent])
    }

    func test_title_forCategory_usesDisplayName() {
        XCTAssertEqual(MacSidebarSection.category(.backgrounds).title,
                       Category.backgrounds.displayName)
    }
}
