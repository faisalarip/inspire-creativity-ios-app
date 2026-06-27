# macOS App — Phase 0 + Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get InspireCreativity building and running as a native SwiftUI macOS app whose Detail surface shows the live preview and selectable, copyable, savable SwiftUI source side-by-side.

**Architecture:** Add a *My Mac* destination to the single existing app target (SwiftUI multiplatform). Reuse all core/domain/view-model code unchanged; branch only the navigation shell and ~7 platform-specific spots with `#if os(macOS)` / `#if canImport(UIKit)`. iOS behavior is untouched.

**Tech Stack:** Swift, SwiftUI, StoreKit 2, Supabase-swift, CoreTransferable. Xcode 26.1.1. Test target: `InspireCreativityAppTests` (XCTest). Project: `InspireCreativityApp.xcodeproj`, scheme `InspireCreativityApp`, bundle id `com.inspirecreativity`.

## Global Constraints

- Single app target; **do not** create a second target or a Swift package. Add a macOS destination to the existing target.
- One bundle id: `com.inspirecreativity` (do not change it; the IAP product-id string `com.faisalarip.InspireCreativityApp.pro.lifetime` is unrelated and must not change).
- iOS code paths and behavior must not regress — every task verifies the **iOS** build/tests still pass.
- `MACOSX_DEPLOYMENT_TARGET = 14.0` initially; if the macOS build surfaces an iOS-18/macOS-15-only API (e.g. `MeshGradient`), either add an `@available` guard or bump the macOS target to `15.0` — record which in the task that hits it. Do not silently leave a broken build.
- Platform branching: prefer `#if canImport(UIKit)` for "UIKit vs AppKit API" splits and `#if os(macOS)` / `#if os(iOS)` for "which shell/feature" splits.
- DRY, YAGNI, TDD where logic is unit-testable; frequent commits. Commit message trailer (every commit):
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01D25kCDftE6ZXUERnKN8fks
  ```
- Work on a dedicated branch `feat/macos-app` created from `release` (do not commit to `release` directly).

## Build & test commands (used throughout)

- macOS build: `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=macOS' -configuration Debug build`
- iOS build: `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build`
- Unit tests (iOS sim): `xcodebuild test -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:InspireCreativityAppTests/<Suite>/<test>`
- Run the Mac app for visual check: `open` the built `.app`, or `xcodebuild ... build` then launch the product from `Build/Products/Debug/InspireCreativityApp.app`.

## File Structure

**New files**
- `InspireCreativityApp/Platform/PlatformClipboard.swift` — cross-platform copy helper (`Clipboard.copy(_:)`).
- `InspireCreativityApp/Platform/View+HiddenNavigationBar.swift` — `hiddenNavigationBar()` modifier (iOS hides the nav bar; no-op on macOS).
- `InspireCreativityApp/Features/MacShell/MacRootView.swift` — `NavigationSplitView` shell (macOS only).
- `InspireCreativityApp/Features/MacShell/MacSidebar.swift` — sidebar section model + view.
- `InspireCreativityApp/Features/MacShell/MacCatalogList.swift` — content column (search + grid).
- `InspireCreativityApp/Features/MacShell/MacDetailView.swift` — `HSplitView` preview ∥ code.
- `InspireCreativityApp/Animations/CodeExport.swift` — adopted from branch `feat/code-export` (`SwiftSnippet`, `SwiftSource`).
- `InspireCreativityAppTests/SwiftSnippetTests.swift`, `InspireCreativityAppTests/MacSidebarSectionTests.swift`.

**Modified files**
- `InspireCreativityApp.xcodeproj/project.pbxproj` — add macOS destination, deployment target.
- `InspireCreativityApp/InspireCreativityApp.entitlements` (create if absent) — sandbox + network.client + user-selected files.
- `InspireCreativityApp/App/InspireCreativityApp.swift` — pick shell per platform.
- `InspireCreativityApp/App/RootView.swift:102,105,108` — use `hiddenNavigationBar()`.
- `InspireCreativityApp/Features/Settings/SettingsView.swift:59`, `Features/Discover/DiscoverView.swift:558`, `Features/Detail/DetailView.swift:171` — use `hiddenNavigationBar()`.
- `InspireCreativityApp/Features/Detail/CodeSheet.swift:9,165` — drop `import UIKit`, use `Clipboard.copy`.
- `InspireCreativityApp/Animations/Catalog/TextEffects/WeightBreatheView.swift:3,91` — `NSFont` under `#if`.
- `InspireCreativityApp/App/RootView.swift:610-621` + `Features/Search/SearchView.swift:45` — gate iOS-only text-field modifiers.
- `InspireCreativityApp/Features/Detail/SwiftCodeView.swift` — add `.textSelection(.enabled)`.

> **Line numbers are from the `release` snapshot and may drift; confirm with a `grep` before editing each site.**

---

# Phase 0 — Mac builds green

### Task 0: Create the work branch

- [ ] **Step 1: Branch from release**

Run:
```bash
git checkout release && git pull --ff-only 2>/dev/null; git checkout -b feat/macos-app
```
Expected: `Switched to a new branch 'feat/macos-app'`.

---

### Task 1: `hiddenNavigationBar()` modifier + replace the 6 blocker sites

**Files:**
- Create: `InspireCreativityApp/Platform/View+HiddenNavigationBar.swift`
- Modify: `RootView.swift` (3 sites), `SettingsView.swift`, `DiscoverView.swift`, `DetailView.swift`

**Interfaces:**
- Produces: `extension View { func hiddenNavigationBar() -> some View }` — hides the navigation bar on iOS, no-op on macOS.

- [ ] **Step 1: Create the modifier**

```swift
//  View+HiddenNavigationBar.swift
import SwiftUI

extension View {
    /// Hides the navigation bar chrome on iOS. No-op on macOS, where
    /// `ToolbarPlacement.navigationBar` is unavailable (hard compile error).
    @ViewBuilder
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
```

- [ ] **Step 2: Find the call sites**

Run: `grep -rn "\.toolbar(\.hidden, for: \.navigationBar)" InspireCreativityApp/`
Expected: 6 matches (RootView ×3, SettingsView, DiscoverView, DetailView).

- [ ] **Step 3: Replace each `.toolbar(.hidden, for: .navigationBar)` with `.hiddenNavigationBar()`**

At every matched site, replace the modifier call. Example (RootView.swift detail destination):
```swift
DetailView(viewModel: container.makeDetailViewModel(animationId: id))
    .hiddenNavigationBar()
```

- [ ] **Step 4: Verify no sites remain and iOS builds**

Run: `grep -rn "\.toolbar(\.hidden, for: \.navigationBar)" InspireCreativityApp/` → Expected: no matches.
Run the iOS build command → Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Platform/View+HiddenNavigationBar.swift InspireCreativityApp/App/RootView.swift InspireCreativityApp/Features/Settings/SettingsView.swift InspireCreativityApp/Features/Discover/DiscoverView.swift InspireCreativityApp/Features/Detail/DetailView.swift
git commit -m "refactor(macos): route navigation-bar hiding through a platform modifier"
```

---

### Task 2: `Clipboard` copy helper + replace `UIPasteboard`

**Files:**
- Create: `InspireCreativityApp/Platform/PlatformClipboard.swift`
- Modify: `InspireCreativityApp/Features/Detail/CodeSheet.swift` (remove `import UIKit`, replace `UIPasteboard.general.string = source`)

**Interfaces:**
- Produces: `enum Clipboard { static func copy(_ string: String) }` — writes plain text to the system pasteboard on iOS and macOS.

- [ ] **Step 1: Create the helper**

```swift
//  PlatformClipboard.swift
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cross-platform plain-text clipboard write. The app's "Copy Code" payoff
/// must land in the real system pasteboard on both iOS and macOS.
enum Clipboard {
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
```

- [ ] **Step 2: Find the copy site**

Run: `grep -n "import UIKit\|UIPasteboard" InspireCreativityApp/Features/Detail/CodeSheet.swift`
Expected: `import UIKit` (line ~9) and `UIPasteboard.general.string = source` (line ~165).

- [ ] **Step 3: Replace usage**

Remove `import UIKit` from `CodeSheet.swift`. Replace the copy line:
```swift
Clipboard.copy(source)
```

- [ ] **Step 4: Verify iOS build + behavior unchanged**

Run the iOS build command → Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Platform/PlatformClipboard.swift InspireCreativityApp/Features/Detail/CodeSheet.swift
git commit -m "refactor(macos): cross-platform Clipboard helper, drop UIPasteboard from CodeSheet"
```

---

### Task 3: `NSFont` shim in `WeightBreatheView`

**Files:**
- Modify: `InspireCreativityApp/Animations/Catalog/TextEffects/WeightBreatheView.swift` (lines ~3, ~91)

- [ ] **Step 1: Inspect the usage**

Run: `grep -n "import UIKit\|UIFont" InspireCreativityApp/Animations/Catalog/TextEffects/WeightBreatheView.swift`
Expected: `import UIKit` and a `UIFont.systemFont(ofSize:weight:)` / `UIFont.Weight(...)` construction.

- [ ] **Step 2: Replace the import and font construction with a platform branch**

Replace `import UIKit` with:
```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```
Replace the font line (adapt to the exact local variable names found in Step 1):
```swift
#if canImport(UIKit)
let resolved = UIFont.systemFont(ofSize: size, weight: UIFont.Weight(weightValue))
#elseif canImport(AppKit)
let resolved = NSFont.systemFont(ofSize: size, weight: NSFont.Weight(weightValue))
#endif
```

- [ ] **Step 3: Verify iOS build**

Run the iOS build command → Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add InspireCreativityApp/Animations/Catalog/TextEffects/WeightBreatheView.swift
git commit -m "refactor(macos): bridge WeightBreatheView font through NSFont on macOS"
```

---

### Task 4: Gate `AuthField` iOS-only text modifiers

**Files:**
- Modify: `InspireCreativityApp/App/RootView.swift` (AuthField struct, ~610-621), `InspireCreativityApp/Features/Search/SearchView.swift:45`

- [ ] **Step 1: Inspect AuthField**

Run: `grep -n "UITextContentType\|UIKeyboardType\|keyboardType\|textInputAutocapitalization" InspireCreativityApp/App/RootView.swift InspireCreativityApp/Features/Search/SearchView.swift`

- [ ] **Step 2: Make the stored UIKit-typed properties and modifiers iOS-only**

In `AuthField`, wrap the iOS-only stored properties and their use:
```swift
#if os(iOS)
let contentType: UITextContentType?
let keyboard: UIKeyboardType
#endif
var autocapitalization: TextInputAutocapitalization = .never
```
Wrap the modifier application:
```swift
TextField("", text: $text, prompt: prompt)
    #if os(iOS)
    .keyboardType(keyboard)
    .textInputAutocapitalization(autocapitalization)
    #endif
```
For every `AuthField(...)` initializer call site, wrap the `contentType:`/`keyboard:` arguments so they are only passed on iOS — simplest: give those parameters `#if os(iOS)` default-bearing inits, or add a second memberwise init under `#if os(macOS)` that omits them. Choose the init-overload approach:
```swift
#if os(iOS)
init(placeholder: String, text: Binding<String>, isSecure: Bool,
     contentType: UITextContentType?, keyboard: UIKeyboardType,
     autocapitalization: TextInputAutocapitalization = .never) { ... }
#else
init(placeholder: String, text: Binding<String>, isSecure: Bool,
     autocapitalization: TextInputAutocapitalization = .never) { ... }
#endif
```
At `SearchView.swift:45`, wrap `.textInputAutocapitalization(.never)` in `#if os(iOS)`.

- [ ] **Step 3: Verify iOS build**

Run the iOS build command → Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add InspireCreativityApp/App/RootView.swift InspireCreativityApp/Features/Search/SearchView.swift
git commit -m "refactor(macos): gate iOS-only text-field modifiers in AuthField/SearchView"
```

---

### Task 5: Add the macOS destination + entitlements

**Files:**
- Modify: `InspireCreativityApp.xcodeproj/project.pbxproj`
- Create: `InspireCreativityApp/InspireCreativityApp.entitlements` (if not present) and reference it via `CODE_SIGN_ENTITLEMENTS`

- [ ] **Step 1: Add macOS as a supported destination (Xcode UI or pbxproj)**

In Xcode: select the `InspireCreativityApp` target → General → Supported Destinations → **+ Mac**. This sets `SUPPORTED_PLATFORMS` to include `macosx` and adds `SUPPORTS_MACCATALYST = NO` with a native macOS slice. Set `MACOSX_DEPLOYMENT_TARGET = 14.0` for both Debug and Release.

- [ ] **Step 2: Create the entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
</dict>
</plist>
```
Set `CODE_SIGN_ENTITLEMENTS = InspireCreativityApp/InspireCreativityApp.entitlements` for the app target. If an iOS entitlements file already exists (Sign in with Apple), merge these keys into a single file used by both platforms (the sandbox keys are ignored on iOS), or keep platform-specific entitlements via `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`. Keep the existing `com.apple.developer.applesignin` entitlement.

- [ ] **Step 3: Verify the destination resolves**

Run: `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -showdestinations 2>/dev/null | grep -i "platform:macOS"`
Expected: a `platform:macOS` destination is listed.

- [ ] **Step 4: Commit (build not yet green — App scene still references iOS-only RootView paths; resolved in Task 6)**

```bash
git add InspireCreativityApp.xcodeproj/project.pbxproj InspireCreativityApp/InspireCreativityApp.entitlements
git commit -m "build(macos): add My Mac destination + App Sandbox entitlements"
```

---

### Task 6: First clean macOS build (minimal Mac entry point)

**Files:**
- Modify: `InspireCreativityApp/App/InspireCreativityApp.swift`

**Interfaces:**
- Produces: the app's `body: some Scene` shows `MacBootstrapView` (a temporary placeholder) on macOS and `RootView` on iOS, so the macOS slice links and runs before the real shell exists.

- [ ] **Step 1: Add a temporary macOS placeholder scene branch**

In `InspireCreativityApp.swift` `body`:
```swift
var body: some Scene {
    WindowGroup {
        #if os(macOS)
        Text("InspireCreativity for Mac — shell coming next")
            .frame(minWidth: 900, minHeight: 600)
            .environmentObject(container)
            .environmentObject(container.authStore)
            .environmentObject(container.store)
            .preferredColorScheme(.dark)
        #else
        RootView()
            .environmentObject(container)
            .environmentObject(container.authStore)
            .environmentObject(container.store)
            .tint(Theme.Palette.accent)
            .preferredColorScheme(.dark)
        #endif
    }
}
```

- [ ] **Step 2: Build for macOS and fix any remaining compile errors**

Run the macOS build command.
Expected: `** BUILD SUCCEEDED **`. If it fails:
- An iOS-18/macOS-15-only API (e.g. `MeshGradient`) → add `if #available(macOS 15, *)` guards in that view, or bump `MACOSX_DEPLOYMENT_TARGET` to `15.0`. Record the choice in the commit message.
- A `DragGesture.Value.velocity` (`JellyWobbleView`) availability mismatch → guard with `#available`.
- Any further stray `import UIKit` → shim per Tasks 2–4.

- [ ] **Step 3: Verify iOS still builds**

Run the iOS build command → Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Run the Mac app once**

Launch the built `.app`; expect a dark window with the placeholder text (proves the macOS slice links, launches, and the container initializes without crashing).

- [ ] **Step 5: Commit (Phase 0 deliverable: macOS builds & launches)**

```bash
git add InspireCreativityApp/App/InspireCreativityApp.swift
git commit -m "build(macos): green macOS build + launch via placeholder scene"
```

---

# Phase 1 — Split-view shell + preview ∥ code detail

### Task 7: Sidebar section model (TDD)

**Files:**
- Create: `InspireCreativityApp/Features/MacShell/MacSidebar.swift`
- Test: `InspireCreativityAppTests/MacSidebarSectionTests.swift`

**Interfaces:**
- Produces: `enum MacSidebarSection: Hashable, Identifiable { case discover; case category(Category); case owned; case favorites; case recent }` with `var title: String` and `static func all(categories: [Category]) -> [MacSidebarSection]`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import InspireCreativityApp

final class MacSidebarSectionTests: XCTestCase {
    func test_all_startsWithDiscover_thenCategories_thenLibrary() {
        let cats: [Category] = [.backgrounds, .metalShaders]
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
```

- [ ] **Step 2: Run the test, expect failure**

Run: `xcodebuild test -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:InspireCreativityAppTests/MacSidebarSectionTests`
Expected: FAIL (type `MacSidebarSection` not found).

- [ ] **Step 3: Implement the section model**

```swift
//  MacSidebar.swift
import SwiftUI

enum MacSidebarSection: Hashable, Identifiable {
    case discover
    case category(Category)
    case owned, favorites, recent

    var id: String {
        switch self {
        case .discover: "discover"
        case .category(let c): "cat-\(c.rawValue)"
        case .owned: "owned"; case .favorites: "favorites"; case .recent: "recent"
        }
    }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .category(let c): c.displayName
        case .owned: "Owned"; case .favorites: "Favorites"; case .recent: "Recent"
        }
    }

    static func all(categories: [Category]) -> [MacSidebarSection] {
        [.discover] + categories.map(MacSidebarSection.category) + [.owned, .favorites, .recent]
    }
}
```
(If `Category` is not `RawRepresentable` with a `rawValue` string, adapt `id` to use `displayName`.)

- [ ] **Step 4: Run the test, expect pass**

Run the same `-only-testing` command → Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Features/MacShell/MacSidebar.swift InspireCreativityAppTests/MacSidebarSectionTests.swift
git commit -m "feat(macos): sidebar section model with tests"
```

---

### Task 8: `MacRootView` NavigationSplitView shell

**Files:**
- Create: `InspireCreativityApp/Features/MacShell/MacRootView.swift`, `InspireCreativityApp/Features/MacShell/MacCatalogList.swift`
- Modify: `InspireCreativityApp/App/InspireCreativityApp.swift` (swap placeholder for `MacRootView`)

**Interfaces:**
- Consumes: `AppContainer` (env object), `MacSidebarSection`, `BrowseViewModel` (via `container.makeBrowseViewModel()`), `AnimationCard`.
- Produces: `struct MacRootView: View` (macOS shell) with `@State selection: MacSidebarSection` and `@State selectedItemID: AnimationItem.ID?`.

- [ ] **Step 1: Implement the content list column**

```swift
//  MacCatalogList.swift
import SwiftUI

/// Middle column: search + a grid of cards for the selected sidebar section.
struct MacCatalogList: View {
    let items: [AnimationItem]
    @Binding var selectedItemID: AnimationItem.ID?
    @Binding var search: String

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { item in
                    AnimationCard(item) { selectedItemID = item.id }
                        .overlay(selectedItemID == item.id
                                 ? RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.Palette.accent, lineWidth: 2)
                                 : nil)
                }
            }
            .padding(16)
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search animations, authors…")
        .background(Theme.Palette.background)
    }
}
```

- [ ] **Step 2: Implement the split-view shell**

```swift
//  MacRootView.swift
import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var browse: BrowseViewModel
    @State private var selection: MacSidebarSection = .discover
    @State private var selectedItemID: AnimationItem.ID?
    @State private var search = ""

    init(container: AppContainer) {
        _browse = StateObject(wrappedValue: container.makeBrowseViewModel())
    }

    var body: some View {
        NavigationSplitView {
            List(MacSidebarSection.all(categories: orderedCategories), selection: $selection) { section in
                Text(section.title).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } content: {
            MacCatalogList(items: visibleItems, selectedItemID: $selectedItemID, search: $search)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420)
        } detail: {
            if let id = selectedItemID {
                MacDetailView(viewModel: container.makeDetailViewModel(animationId: id))
                    .id(id)
            } else {
                ContentUnavailableView("Select an animation", systemImage: "sparkles")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: search) { _, q in browse.searchText = q }
        .onChange(of: selection) { _, _ in selectedItemID = nil }
    }

    private var orderedCategories: [Category] {
        browse.categories.map(\.category)
    }

    private var visibleItems: [AnimationItem] {
        switch selection {
        case .discover:           return container.animationRepository.all()
        case .category(let cat):  return container.animationRepository.items(in: cat)
        case .owned, .favorites, .recent:
            // Library sections reuse the same access rules as iOS Library.
            let all = container.animationRepository.all()
            switch selection {
            case .owned:     return all.filter { $0.isFree || container.store.isPro }
            case .favorites: return all.filter { container.favoritesRepository.isFavorite($0.id) }
            default:         return Array(all.prefix(3))
            }
        }
    }
}
```
(Confirm `AppContainer` exposes `animationRepository`, `favoritesRepository`, `store` — it does, per `AppContainer.swift`. If any are `private`, widen to `let`/internal.)

- [ ] **Step 3: Wire it into the App scene**

Replace the macOS placeholder branch in `InspireCreativityApp.swift` with:
```swift
#if os(macOS)
MacRootView(container: container)
    .environmentObject(container)
    .environmentObject(container.authStore)
    .environmentObject(container.store)
    .tint(Theme.Palette.accent)
    .preferredColorScheme(.dark)
#else
```

- [ ] **Step 4: Build for macOS and run**

Run the macOS build command → Expected: `** BUILD SUCCEEDED **`. Launch the app: a 3-column window — sidebar sections, a searchable grid, and an empty detail prompt. Selecting a card highlights it; the detail column shows the placeholder/`MacDetailView` (built next). Verify iOS build still succeeds.

- [ ] **Step 5: Commit**

```bash
git add InspireCreativityApp/Features/MacShell/MacRootView.swift InspireCreativityApp/Features/MacShell/MacCatalogList.swift InspireCreativityApp/App/InspireCreativityApp.swift
git commit -m "feat(macos): NavigationSplitView shell — sidebar, searchable grid, detail column"
```

---

### Task 9: `MacDetailView` — preview ∥ selectable code

**Files:**
- Create: `InspireCreativityApp/Features/MacShell/MacDetailView.swift`
- Modify: `InspireCreativityApp/Features/Detail/SwiftCodeView.swift` (add selection)

**Interfaces:**
- Consumes: `DetailViewModel` (existing: `item`, `code`, `hasPro`, `isOwned`), `AnimationPreviewRegistry.interactiveView(for:)`, `SwiftCodeView`, `CodeAccess`.
- Produces: `struct MacDetailView: View`.

- [ ] **Step 1: Make `SwiftCodeView` selectable**

In `SwiftCodeView.body`, add to the outer `VStack`:
```swift
.textSelection(.enabled)
```

- [ ] **Step 2: Implement the detail split**

```swift
//  MacDetailView.swift
import SwiftUI

struct MacDetailView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel: DetailViewModel

    init(viewModel: DetailViewModel) { _viewModel = StateObject(wrappedValue: viewModel) }

    private var access: CodeAccess {
        CodeAccess.evaluate(itemIsPro: viewModel.item.isPro,
                            hasProEntitlement: viewModel.hasPro,
                            isAuthenticated: authStore.isAuthenticated)
    }
    private var canViewCode: Bool { access == .granted }

    var body: some View {
        HSplitView {
            ZStack {
                Color(hex: viewModel.item.tintHex)
                AnimationPreviewRegistry.interactiveView(for: viewModel.item.id)
            }
            .frame(minWidth: 280)

            Group {
                if canViewCode {
                    ScrollView { SwiftCodeView(source: viewModel.code).padding(12) }
                } else {
                    CodeLockedView(access: access)   // reuse the iOS lock CTA or a Mac equivalent
                }
            }
            .frame(minWidth: 360)
            .background(Theme.Palette.background)
        }
        .navigationTitle(viewModel.item.name)
    }
}
```
(If no shared `CodeLockedView` exists, inline a minimal locked panel: a lock icon + "Unlock with Pro" / "Sign in" button that triggers the Mac paywall/auth — wired in Task 10 and Phase 3. For this task a static locked panel is sufficient; gating is verified in Task 10.)

- [ ] **Step 3: Build for macOS and run**

Run the macOS build command → Expected: `** BUILD SUCCEEDED **`. Launch: selecting a card shows live preview on the left and (for an owned/free item) syntax-highlighted, **selectable** code on the right; a Pro item shows the locked panel. Verify iOS build still succeeds.

- [ ] **Step 4: Commit**

```bash
git add InspireCreativityApp/Features/MacShell/MacDetailView.swift InspireCreativityApp/Features/Detail/SwiftCodeView.swift
git commit -m "feat(macos): preview∥code detail split with selectable source"
```

---

### Task 10: Copy + Save .swift (adopt CodeExport) with gating

**Files:**
- Create: `InspireCreativityApp/Animations/CodeExport.swift` (port from `feat/code-export`)
- Create: `InspireCreativityAppTests/SwiftSnippetTests.swift`
- Modify: `InspireCreativityApp/Features/MacShell/MacDetailView.swift` (action bar)

**Interfaces:**
- Consumes: `Clipboard.copy`, `DetailViewModel.code`, `viewModel.item.name`.
- Produces: `struct SwiftSnippet: Transferable` with `init(displayName:source:)` and `static func fileName(for:) -> String`; `enum SwiftSource { static func bodyWithoutImports(_:) -> String }`.

- [ ] **Step 1: Port CodeExport.swift from the branch**

Run: `git show feat/code-export:InspireCreativityApp/Animations/CodeExport.swift > InspireCreativityApp/Animations/CodeExport.swift`
Then remove anything beyond `SwiftSnippet` + `SwiftSource` if the deep-link section pulls in unused types (keep it minimal; deep-linking is out of scope here).

- [ ] **Step 2: Write the failing test**

```swift
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
```

- [ ] **Step 3: Run the test, expect pass (logic ported from the branch)**

Run: `xcodebuild test ... -only-testing:InspireCreativityAppTests/SwiftSnippetTests`
Expected: PASS. (If FAIL, reconcile the ported `fileName`/`bodyWithoutImports` to match these assertions.)

- [ ] **Step 4: Add the action bar to `MacDetailView`**

Add above the code `ScrollView` (only when `canViewCode`):
```swift
HStack(spacing: 10) {
    Button { Clipboard.copy(viewModel.code) } label: { Label("Copy", systemImage: "doc.on.doc") }
    Button { Clipboard.copy(SwiftSource.bodyWithoutImports(viewModel.code)) } label: { Label("Copy w/o imports", systemImage: "doc.on.clipboard") }
    Button { showExporter = true } label: { Label("Save .swift", systemImage: "square.and.arrow.down") }
    Spacer()
}
.padding(.horizontal, 12).padding(.top, 10)
.buttonStyle(.bordered)
```
Add state + exporter to the view:
```swift
@State private var showExporter = false
// ...
.fileExporter(isPresented: $showExporter,
              document: SwiftFileDocument(text: viewModel.code),
              contentType: .swiftSource,
              defaultFilename: SwiftSnippet.fileName(for: viewModel.item.name)) { _ in }
```
Add a minimal `FileDocument` (new small type in `CodeExport.swift`):
```swift
import UniformTypeIdentifiers
import SwiftUI

struct SwiftFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.swiftSource] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

- [ ] **Step 5: Build for macOS and run**

Run the macOS build command → Expected: `** BUILD SUCCEEDED **`. Launch: for an owned/free item, Copy puts code on the clipboard (paste into TextEdit to confirm), "Copy w/o imports" omits the leading `import` lines, "Save .swift" opens a save panel with a CamelCased default name and writes a compilable file. Verify iOS build still succeeds.

- [ ] **Step 6: Commit**

```bash
git add InspireCreativityApp/Animations/CodeExport.swift InspireCreativityAppTests/SwiftSnippetTests.swift InspireCreativityApp/Features/MacShell/MacDetailView.swift
git commit -m "feat(macos): copy / copy-without-imports / Save .swift on the code pane"
```

---

## Subsequent plans (not detailed here)

These become their own plans once Phase 1 lands and the shell's real shape is known:

- **Phase 2 plan** — drag `.swift` out via `.draggable(SwiftSnippet(...))` (Tier 1); `.commands` menu (Copy ⌘C, Save ⌘S, New Window ⌘N, Find ⌘F, Restore Purchases); keyboard navigation; multi-window via `WindowGroup(for: AnimationItem.ID)`.
- **Phase 3 plan** — Google OAuth key-window anchor via `signInWithOAuth(configure:)`; `AppStore.sync()` (or prominent Restore) on Mac first launch; the Mac paywall/auth routing for the locked code panel.
- **Phase 4 plan** — monetization rollout (confirm ASC bundle id, dry-run platform-add on a non-production record, sandbox cross-platform unlock test) and the full on-Mac verification checklist (shaders, gestures-under-pointer, materials in active/inactive windows). Add the macOS destination to the Xcode Cloud lane.

## Self-Review

**Spec coverage (Phase 0 + Phase 1 portion):** §3 blockers → Tasks 1,3,4,5,6; §3 UIKit shims → Tasks 2,3,4; §4.1/4.2 target+sharing → Task 5,6; §4.3 shell → Tasks 7,8; §4.4 detail split → Task 9; §4.5 copy/Save (partial — drag-out/ShareLink deferred to Phase 2) → Task 10; §4.8 entitlements → Task 5. Auth/StoreKit (§4.7), drag-out/menus/multi-window (§4.6), monetization rollout (§5), verification (§7) are explicitly deferred to the Phase 2/3/4 plans listed above. No Phase-0/1 spec item is unaddressed.

**Placeholder scan:** No "TBD/TODO". The two soft spots are explicit, not placeholders: Task 4 offers a concrete init-overload approach, and Task 9's `CodeLockedView` says "inline a minimal locked panel" with what it must contain (gating verified in Task 10). Acceptable.

**Type consistency:** `MacSidebarSection` (Task 7) is consumed in Task 8. `SwiftSnippet.fileName(for:)` / `SwiftSource.bodyWithoutImports` (Task 10) match the ported `CodeExport.swift` and the tests. `Clipboard.copy` (Task 2) is used in Task 10. `DetailViewModel.code`/`hasPro`/`item` match the current `DetailViewModel`. `CodeAccess.evaluate(itemIsPro:hasProEntitlement:isAuthenticated:)` matches the current signature.
