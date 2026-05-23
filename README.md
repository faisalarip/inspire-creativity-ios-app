# Stagger — SwiftUI Animation Catalog

A native iOS 17+ SwiftUI port of the Stagger animation catalog prototype. Browse, preview, and buy hand-crafted SwiftUI animations.

## Run

1. Open `StaggerApp.xcodeproj` in **Xcode 16** (any 15.4+ should work).
2. Pick any iPhone simulator (iOS 17+; iOS 18+ recommended for the full `MeshGradient` aurora effects).
3. `Cmd-R`.

That's it — no SPM resolves, no third-party deps, no CocoaPods.

> **Note:** if the iOS 17 simulator on macOS produces a clipped layout (content appears in the left half of the screen), this is a known Xcode 16 / iOS 17 host display quirk unrelated to the app. Use an iOS 18 simulator (iPhone 16 / 16 Plus / 16 Pro) for a clean render.

## Architecture

MVVM + light Clean Architecture, single Xcode target.

```
Presentation (SwiftUI Views)
        │
        ▼
ViewModels (@MainActor, ObservableObject, @Published)
        │
        ▼
Domain        (value-type entities: AnimationItem, Category, Difficulty)
        │
        ▼
Repositories  (protocols + concrete impls — in-memory + UserDefaults)
```

### Folder layout

```
StaggerApp/
├── App/                   App entry, container, router, root shell, tab bar
├── DesignSystem/          Theme tokens, shared atoms (Chip, NavHeader, Avatar, AnimationCard…)
├── Models/                Pure-Swift domain entities (AnimationItem, Category, Difficulty)
├── Repositories/          Animation/Favorites/Purchase repos + seed data + Swift code samples
├── Animations/
│   ├── AnimationPreviewRegistry.swift   id → preview view lookup
│   └── Previews/                         30 hand-coded SwiftUI animations
├── Features/
│   ├── Discover/          Home tab (hero, trending, categories, Aurora pack promo)
│   ├── Browse/            Category grid with chips + sort
│   ├── Search/            Debounced search (Combine) with idle/empty/results states
│   ├── Library/           Owned / Favorites / Recent tabs
│   ├── Detail/            Drag-up code sheet with syntax highlighting
│   └── Paywall/           Subscription pitch with plan picker
└── Resources/             Asset catalog (AccentColor)
```

### Dependency injection

`AppContainer` is the single composition root. It vends repositories (as protocols) and view-model factories:

```swift
// In RootView
DetailView(viewModel: container.makeDetailViewModel(animationId: id))
```

Every view model takes its dependencies via `init`. No singletons, no `@EnvironmentObject` for business logic — only for navigation state (`AppRouter`) and the container itself.

## State patterns

- **`@MainActor` view models** ensure UI updates stay on the main thread.
- **Combine** for search debouncing (`SearchViewModel.bind()`) and reactive favorites/purchases (`DetailViewModel`, `LibraryViewModel`).
- **`async/await` Tasks** drive looping preview animations (see `CorePreviews.swift`).
- **UserDefaults** persists favorites + purchase state. Swap with SwiftData behind the same protocol for production.

## Mesh gradients

The Aurora previews use `MeshGradient` on iOS 18+ and fall back to `LinearGradient` with `hueRotation` on iOS 17. See `CreativePreviews.AuroraMeshPreview` for the runtime version check.

## What's complete

| Screen          | Status         | Notes                                              |
|-----------------|----------------|----------------------------------------------------|
| Discover (Home) | Fully working  | Hero, trending, categories, new, Aurora promo      |
| Browse          | Fully working  | Chip filters, sort toggle, 2-col grid              |
| Search          | Fully working  | Combine debounce, idle/empty/results states        |
| Library         | Fully working  | Owned / Favorites / Recent tabs, Go-Pro CTA        |
| Detail          | Fully working  | Drag-up code sheet, syntax highlighting, favorites |
| Paywall         | Fully working  | Plan picker, fake-subscribe action                 |

## Animation previews

30 hand-coded SwiftUI animations across all categories (Backgrounds, Loaders, Buttons, Micro-interactions, Transitions, Navigation, Gestures, Onboarding, Text effects, Metal Shaders). All loop forever; none use third-party libraries (no Lottie / Rive).

## TODOs / Known limitations

- **Lab mode** (scrubbable knobs that feed back into the preview) — not implemented. The `LiveParametersPanel` sliders are visual-only.
- **Real StoreKit** — `PurchaseRepository.purchase(id:)` and `.subscribePro()` immediately flip in-memory state. A production app would integrate `StoreKit 2` behind the same protocol.
- **Recent activity** — the Library `Recent` tab uses a derived `Array(owned.prefix(3))`. A real activity log would be persisted on each detail view + copy event.
- **Liquid Ripple preview** — the published `CodeSamples.liquidRipple` references a Metal shader (`ripple`) that isn't bundled in this scope. The preview uses a SwiftUI ring approximation.
- **Tests** — no unit/UI tests included in this scope. The protocol-based DI is ready for them; add an `XCTest` target and wire fakes against `AnimationRepositoryProtocol`, `FavoritesRepositoryProtocol`, `PurchaseRepositoryProtocol`.
- **Accessibility** — basic labels and Dynamic Type are wired on the major atoms; full VoiceOver flow has not been exhaustively QA'd.

## Supabase integration (optional)

The app boots from a bundled seed catalog. To extend the catalog through a
server — adding new animations without rebuilding the app — wire it to your
Supabase project.

### 1. Create the table

Open Supabase Dashboard → **SQL Editor** → paste the contents of
[`supabase_schema.sql`](supabase_schema.sql) → **Run**. This creates the
`animations` table, a public read policy, indexes, and inserts two example
rows.

### 2. Configure the app

Open `StaggerApp/App/AppContainer.swift` and fill in `SupabaseConfig`:

```swift
enum SupabaseConfig {
    static let url     = "https://YOUR-PROJECT.supabase.co"
    static let anonKey = "YOUR-ANON-PUBLIC-KEY"
}
```

Both come from your Supabase project's **Settings → API** page. The anon
key is safe to ship in the app — its access is gated entirely by the RLS
policies you configure server-side.

### 3. Run

On next launch the app:

1. Boots instantly from the bundled seed catalog.
2. Fires an async `GET /rest/v1/animations?select=*` in the background.
3. Replaces the in-memory cache with the remote rows on success.
4. Posts `.animationsUpdated` — Discover and Browse rebind to the new data.

If the fetch fails or `SupabaseConfig` is empty, the app silently keeps the
seed catalog. No errors are surfaced to the user.

### 4. Add new animations

Insert rows via the Supabase Dashboard, SQL editor, JS/Swift SDKs, or
`psql`. To get a real animated preview without rebuilding the app, supply
`palette` (array of hex colors) and optionally `engine` (one of `mesh`,
`spin`, `bloom`, `streaks`, `goo`). The iOS preview registry checks
`runtimeDescriptors` for any unknown id at render time, so server-added
rows with a `palette` get a live `ParametricAuroraPreview` without an app
rebuild.

## Min iOS

- **Deployment target:** iOS 17.0
- **MeshGradient:** iOS 18+ (gracefully falls back on 17)
- **Xcode:** 16.0+

## License

This project is a design/engineering exercise. The Swift code samples shown in the in-app code sheets are illustrative — see `Repositories/CodeSamples.swift` for full source.
