# macOS UI Rebuild — match the Claude Design `Mac App.html` reference

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Reference design lives in claude.ai/design project `5f0a8aa4-16e3-447f-a253-d6f146560fad` (`macos-app.jsx`, `macos-discover.jsx`). The Mac layout must match it precisely; data comes from our real catalog.

**Goal:** Replace the plain `NavigationSplitView` macOS shell with a custom 3-pane layout that precisely matches the reference: a 52pt top toolbar, a 248pt tinted sidebar with a Pro card, a rich editorial Discover center (+ category grids + search), and a 460pt right detail pane (preview + Code/About tabs + Copy/Save). Wire everything to the real `AnimationItem` catalog and reuse the auth/paywall/consent already built.

**Architecture:** New macOS-only views under `Features/MacShellV2/` (all `#if os(macOS)`), built bottom-up so each compiles. The live scene swaps from `MacRootView` to the new `MacAppView` only in the final task. iOS is untouched. The old `MacShell/*` files are removed once the new root is wired.

## Global constraints
- Single app target; bundle id `com.inspirecreativity`; iOS unchanged. All new views `#if os(macOS)`.
- Verify each task: macOS build `xcodebuild -project InspireCreativityApp.xcodeproj -scheme InspireCreativityApp -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED, AND iOS build green. Full suite green at the end.
- New files → APP target Sources, unique `uuidgen | tr -d '-' | cut -c1-24` UUIDs. Standard file headers. Commit trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` / `Claude-Session: https://claude.ai/code/session_01D25kCDftE6ZXUERnKN8fks`
- Stage only each task's files; never `git add -A`; never stage `.claude/`.

## Reference facts (from the JSX — match these)
- **Palette:** window `#0a0a0c`; hairline `rgba(255,255,255,0.07)`; toolbar bg `rgba(16,16,19,0.6)` blur; accent `#FF6B4A` (use `Theme.Palette.accent`); mono font for counts/prices/ios (JetBrains Mono → our `Theme.Typo.mono`).
- **Category tints (CAT_TINT):** Backgrounds `#A78BFA`, Loaders `#22D3EE`, Buttons `#FF6B4A`, Micro-interactions `#F472B6`, Transitions `#34D399`, Navigation `#60A5FA`, Gestures `#FBBF24`, Onboarding `#FB7185`, Text effects `#C4B5FD`, Metal Shaders `#F97316`.
- **Category icons:** map each `Category` to an SF Symbol approximating the reference path (Backgrounds→`photo`, Loaders→`circle.dotted`, Buttons→`capsule`, Micro-interactions→`sparkle`, Transitions→`rectangle.righthalf.inset.filled.arrow.right`, Navigation→`square.grid.2x2`, Gestures→`hand.draw`, Onboarding→`person.crop.circle`, Text effects→`textformat`, Metal Shaders→`cube`; Discover→`house`, Owned→`shippingbox`, Favorites→`heart`, Recent→`clock`).
- **Data mapping:** design `SWIFT_CODE[id].{free,price,downloads,rating,author,handle,description}` → our `AnimationItem.{isFree,price,downloads,rating,author,handle,description}`; `a.{name,category,ios,tint,pro,difficulty,theme}` → `item.{name,category.displayName,iosVersion,tintHex,isPro,difficulty,...}` (no `theme` field — derive from category or omit). `free` = `item.isFree`. Preview `<anim.Component/>` → `AnimationPreviewRegistry.view(for: item.id)` (grid) / `.interactiveView(for:)` (detail). Category counts/list → `repository.categories()` + `repository.items(in:)` + `repository.all()`.

---

### Task 1 — Category style map + `MacAnimCard`
**Files:** create `Features/MacShellV2/MacCategoryStyle.swift`, `Features/MacShellV2/MacAnimCard.swift` (both `#if os(macOS)`).
- `MacCategoryStyle`: `static func tint(_ Category) -> Color` and `static func iconName(_ Category) -> String` (SF Symbols above), plus `discover/owned/favorites/recent` icon names. Use the CAT_TINT hexes via `Color(hex:)`.
- `MacAnimCard(item:isSelected:height:onOpen:)`: a `Button` — card (height param default 150, corner 14, `Color(hex: item.tintHex)` bg, `AnimationPreviewRegistry.view(for: item.id)`), Pro badge (gold gradient `Theme.Palette.proGoldStart→End`, top-right) when `item.isPro`, "iOS \(item.iosVersion)" mono pill bottom-left, hover lift + "View code" overlay (use `.onHover`); below: name (15ish, semibold) + "category · Free/$price" (Free in `#34D399`). Selected → 1.5pt accent border.
- Verify both builds.
- Commit: `feat(macos): MacAnimCard + category style map (design match)`.

### Task 2 — `MacCategoryGridView` + `MacSearchResults`
**Files:** create `Features/MacShellV2/MacCategoryGridView.swift`, `Features/MacShellV2/MacSearchResults.swift`.
- `MacCategoryGridView(title:subtitle:items:selectedID:onOpen:)`: header (title 30pt heavy + subtitle/count) + a sort segmented control (Popular by `downloads`, Top rated by `rating`, Free first by `isFree`) + `LazyVGrid(adaptive minimum 220, gap 18)` of `MacAnimCard`. Scrollable, padding `28/30/40`.
- `MacSearchResults(query:items:selectedID:onOpen:)`: "N results for \"query\"" header + grid; empty state.
- Verify both builds. Commit: `feat(macos): category grid + search results (design match)`.

### Task 3 — `MacSidebar` (redesigned) + Pro card
**Files:** create `Features/MacShellV2/MacSidebar.swift`.
- 248pt, hairline right border, faint bg. A `Row(section:label:count:tint:isActive:onTap:)`: SF Symbol (tinted; accent when active) + label (13.5) + count pill (mono). Active → accent-tint bg + 3pt left accent bar.
- Sections: "Discover"; label "CATEGORIES" → `repository.categories()` rows (count + `MacCategoryStyle.tint`); label "LIBRARY" → Owned/Favorites/Recent (counts: owned = free-or-Pro set, favorites = favoritesRepository, recent = first 3). Spacer.
- **Pro card** bottom: gradient (accent→dark), gold star + "Pro", "Unlock all N animations. M free to start." (N=`repository.all().count`, M=free count), a "Go Pro" button → presents the paywall (callback). When `store.isPro`, replace the card with a compact "Pro · Active" confirmation (reuse `ProStatusView` idea or a small badge).
- Drives a `@Binding selection: MacNav` (enum: discover, category(Category), owned, favorites, recent). Verify builds. Commit: `feat(macos): sidebar with tinted categories + Pro card (design match)`.

### Task 4 — `MacDiscoverView`
**Files:** create `Features/MacShellV2/MacDiscoverView.swift`.
- Scrollable editorial homepage: **Hero** (280pt, featured = `repository.featured()`, preview bg + left gradient scrim + "FEATURED TODAY" pill + name 38pt + first sentence of description + author avatar/rating + "View code →"); **stat strip** (4 cells: total animations, aurora/theme count, free count, "Fri · new drops weekly"); **Trending now** (horizontal scroll of `MacAnimCard` height 128 — use `repository.trending()`); **Browse by category** (grid of 96pt category tiles: rep preview masked + gradient + icon + name + count → selects category); **Fresh this week** (grid, `repository.newlyAdded()`); **Top creators** (horizontal cards aggregated from catalog by `author`: count + downloads). `SectionHead(title:hint:)` helper.
- Verify builds. Commit: `feat(macos): editorial Discover view (design match)`.

### Task 5 — `MacDetailPane`
**Files:** create `Features/MacShellV2/MacDetailPane.swift`.
- 460pt right pane. **Preview** (200pt, `interactiveView(for:)`, LIVE pill, close button, tap-to-replay via `.id` bump). **Meta** (name 21pt + PRO badge; author · ★rating · downloads · Free/$price; chips: iOS, category, difficulty). **Tabs** Code / About (Metal tab only if the generated source contains a `/* ... */` metal block — optional; otherwise just Code/About). **Action bar** (Copy / Copy w/o imports / Save .swift — reuse `Clipboard`, `SwiftSource.bodyWithoutImports`, `SwiftFileDocument`), gated by `CodeAccess` (locked → Sign in / Unlock-with-Pro presenting the existing sheets). Code tab → `ScrollView { SwiftCodeView(source: viewModel.code) }`. About tab → description + a 2×2 stats grid. Uses a `DetailViewModel` (via `container.makeDetailViewModel(animationId:)`).
- Verify builds. Commit: `feat(macos): right detail pane — preview + code/about + actions (design match)`.

### Task 6 — `MacAppView` root + wire-up + retire old shell
**Files:** create `Features/MacShellV2/MacAppView.swift`; modify `App/InspireCreativityApp.swift` (macOS scene → `MacAppView`); delete old `Features/MacShell/{MacRootView,MacCatalogList,MacDetailView,MacSidebar}.swift` (keep `MacSidebarSection`? no — superseded; keep its tests only if still referenced — otherwise remove test too) ; update pbxproj.
- `MacAppView`: `VStack(spacing:0){ MacToolbar; HStack(spacing:0){ MacSidebar | center | (selected ? MacDetailPane) } }`, `@State nav`, `@State selectedID`, `@State query`. Center = search ? `MacSearchResults` : nav==discover ? `MacDiscoverView` : grid. Hidden native title bar (`.windowStyle(.hiddenTitleBar)` on the macOS `WindowGroup`/Scene; account for real traffic lights at top-left of the toolbar — left-pad the brand ~76pt). Apply the existing `analyticsConsentGate` + account/paywall/auth sheets. `MacToolbar` (brand + search bound to `query` + profile button → Settings sheet).
- Verify macOS + iOS builds + full test suite green. Remove now-unused old MacShell files and their pbxproj entries; ensure `MacSidebarSection` removal doesn't break its test (delete or adapt the test).
- Commit: `feat(macos): assemble MacAppView 3-pane shell; retire NavigationSplitView shell`.

## Notes
- Real window controls: use `.windowStyle(.hiddenTitleBar)`; do NOT draw fake traffic lights. Reserve ~76pt left inset in the toolbar for the real controls.
- Keep all the production-pass behavior (auth, paywall, Restore, consent, Pro status) reachable in the new shell (profile button → Settings sheet; sidebar Pro card / locked detail → paywall).
- `theme` field doesn't exist on `AnimationItem` — derive the "aurora themes" stat from category or a fixed count; don't fabricate per-item themes.
