# Engagement Update v2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the "Engagement Update" (Claude Design project, `Engagement Update.html`, 9 artboards): a retention layer (streaks, daily pick, Friday Drop countdown, weekly challenge), a local-notification system (priming → permission → preferences → scheduled reminders), an in-app Activity inbox, and v2 redesigns of Discover, Browse, Samples, Search (promoted to a 5th tab), and Library (stats + collections).

**Architecture:** Follows the repo's MVVM + light Clean Architecture: value-type domain logic in pure `enum`/`struct` helpers (testable date math), protocol-first repositories persisted to `UserDefaults` (mirroring `FavoritesRepository` / `JourneyMetrics` patterns), `@MainActor ObservableObject` view models built by `AppContainer` factories, SwiftUI views using `Theme` tokens. Notifications are local-only (`UserNotifications` framework) behind a `NotificationScheduling` protocol so planning logic is unit-testable.

**Tech Stack:** Swift 5 / SwiftUI, Combine, StoreKit 2 (existing), UserNotifications (new), XCTest.

## Global Constraints

- Single multiplatform target: all new code must compile for **iphoneos AND macosx** (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`). Gate UIKit-only APIs with `#if os(iOS)`. The new screens are used by the iOS shell (`RootView`); the Mac shell (`MacShellV2`) is **out of scope** but must keep compiling.
- iOS 17.0+ / macOS 14.0+ deployment targets — no iOS-18-only APIs without availability checks.
- Dark-only app: use `Theme.Palette.*` tokens. Accent is `Theme.Palette.accent` (`#FF6B4A`) — matches the design's `--accent`.
- Streak flame color: `#FF9F0A`. Challenge purple: `#A78BFA`. Success green: `Theme.Palette.success`.
- New `UserDefaults` keys use the `engagement.` prefix (existing namespaces: `stagger.*`, `journey.*`).
- View models: `@MainActor final class X: ObservableObject` with `@Published private(set)` outputs, deps injected via init, factories on `AppContainer`. No `@Observable` macro.
- Tests: XCTest in `InspireCreativityAppTests/`, injected `UserDefaults(suiteName:)` + fixed `Calendar`/`Date` (UTC) — never `Date()` in assertions.
- All user-facing copy comes verbatim from the design (quoted per task below).
- Commit per task with conventional-commit messages; work on branch `feat/engagement-update-v2`.
- Existing analytics patterns: screens tracked centrally (router/RootView), events logged from view models via `AnalyticsTracking`.

**Catalog facts** (verified): ~317 `AnimationItem`s. Real ids include `spring-button, heart-burst, spinner, wave-loader, toast, shimmer, ticker, liquid-tabs, confetti, onboarding, progress-arc, aurora-mesh, hologram-card, aurora-borealis, liquid-chrome, aurora-pulse, lava-flow`. Aurora themes (`AuroraDescriptor.theme`) are strings like `Mood, Atmospheric, Iridescent, Cosmic, Particles, Geometric, Liquid`. `AnimationItem` has `tintHex: String`, `isFree`, `price: Double?`, `downloads`, `rating`, `author`; **no theme property** (themes live on `AuroraDescriptors.byId[id]`).

---

### Task 1: EngagementSchedule — pure date/rotation math

**Files:**
- Create: `InspireCreativityApp/Engagement/EngagementSchedule.swift`
- Test: `InspireCreativityAppTests/EngagementScheduleTests.swift`

**Interfaces (Produces):**
```swift
enum EngagementSchedule {
    /// Deterministic pick of the day: stable within a calendar day, rotates daily.
    static func dailyPick(from items: [AnimationItem], on date: Date, calendar: Calendar) -> AnimationItem?
    /// Seconds until the daily pick resets (next local midnight).
    static func dailyPickResetsIn(from date: Date, calendar: Calendar) -> TimeInterval
    /// "resets in 9h" (hours, rounded up; "resets in 1h" minimum granularity is minutes under 1h: "resets in 35m")
    static func dailyResetLabel(from date: Date, calendar: Calendar) -> String
    /// Next Friday 08:00 local (today 08:00 if Friday before 8; else the following Friday).
    static func nextDrop(after date: Date, calendar: Calendar) -> Date
    /// "in 2d 14h" (or "in 14h 5m" under a day, "in 5m" under an hour)
    static func countdownLabel(to target: Date, from now: Date) -> String
    /// Deterministic 4 free items for the ISO week containing `date`; rotates each week.
    static func freeThisWeek(from items: [AnimationItem], on date: Date, calendar: Calendar) -> [AnimationItem]
    /// Days left in the weekly challenge (ends Sunday 23:59 local): "3d left" / "1d left" / "ends today"
    static func challengeDaysLeftLabel(from date: Date, calendar: Calendar) -> String
}
```
Implementation notes: `dailyPick` sorts candidates by `id` (stability), indexes with `dayOrdinal % count` where `dayOrdinal = calendar.ordinality(of: .day, in: .era, for: date)`. `freeThisWeek` filters `isFree`, sorts by `id`, uses `weekSeed = yearForWeekOfYear * 100 + weekOfYear`, takes 4 starting at `(weekSeed * 4) % count` with wraparound.

- [x] **Step 1: Write failing tests** — same-day stability, next-day rotation, resets-in math at 15:00 → 9h, nextDrop on Wed → Friday 08:00 same week, nextDrop on Friday 09:00 → next Friday, countdown labels ("in 2d 14h"), freeThisWeek stable within week / different across weeks / all `isFree`, challenge label Thu → "3d left". Use `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "UTC")!` and `DateComponents`-built dates.
- [x] **Step 2: Run tests, verify FAIL** (`xcodebuild test … -only-testing:InspireCreativityAppTests/EngagementScheduleTests`)
- [x] **Step 3: Implement `EngagementSchedule`**
- [x] **Step 4: Run tests, verify PASS**
- [x] **Step 5: Commit** `feat(engagement): deterministic daily pick, drop countdown, weekly free rotation`

### Task 2: StreakTracker

**Files:**
- Create: `InspireCreativityApp/Engagement/StreakTracker.swift`
- Test: `InspireCreativityAppTests/StreakTrackerTests.swift`

**Interfaces (Produces):**
```swift
final class StreakTracker {
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current)
    let didChange = PassthroughSubject<Void, Never>()
    private(set) var current: Int { get }        // 0 before first open
    @discardableResult func recordAppOpen(on date: Date = Date()) -> Int
}
```
Keys: `engagement.streak.count` (Int), `engagement.streak.lastOpenDay` (String "yyyy-MM-dd", formatted with a fixed `en_US_POSIX` formatter using the injected calendar's time zone). Logic: no previous day → 1; same day → unchanged; previous day == yesterday → +1; otherwise → 1. Emits `didChange` when the value changes.

- [x] **Step 1: Failing tests** — first open→1, same-day repeat→1, consecutive day→2 then 3, two-day gap→1, persists across instances (same suite).
- [x] **Step 2: Verify FAIL** | **Step 3: Implement** | **Step 4: Verify PASS**
- [x] **Step 5: Commit** `feat(engagement): streak tracker with day-boundary logic`

### Task 3: CopyActivityStore (weekly activity bars)

**Files:**
- Create: `InspireCreativityApp/Engagement/CopyActivityStore.swift`
- Test: `InspireCreativityAppTests/CopyActivityStoreTests.swift`

**Interfaces (Produces):**
```swift
final class CopyActivityStore {
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current)
    let didChange = PassthroughSubject<Void, Never>()
    func recordCopy(on date: Date = Date())
    /// 7 counts, Monday-first, for the week containing `date` (design bars M T W T F S S).
    func weekBars(for date: Date) -> [Int]
    func copiesThisWeek(for date: Date) -> Int   // sum of weekBars
}
```
Storage: JSON `[String: Int]` keyed "yyyy-MM-dd" under `engagement.copies.byDay`; prune entries older than 21 days on record.

- [x] **Step 1: Failing tests** — record 3 on Wed + 1 on Fri → bars `[0,0,3,0,1,0,0]`, sum 4; previous-week records excluded; prune drops >21-day-old keys.
- [x] **Step 2: FAIL** | **Step 3: Implement** | **Step 4: PASS**
- [x] **Step 5: Commit** `feat(engagement): copy-activity store for weekly stats`

### Task 4: RecentItemsRepository ("Pick up where you left off")

**Files:**
- Create: `InspireCreativityApp/Repositories/RecentItemsRepository.swift`
- Test: `InspireCreativityAppTests/RecentItemsRepositoryTests.swift`

**Interfaces (Produces):**
```swift
protocol RecentItemsRepositoryProtocol: AnyObject {
    var idsPublisher: AnyPublisher<[String], Never> { get }
    func all() -> [String]
    func record(_ id: String)
}
final class RecentItemsRepository: RecentItemsRepositoryProtocol {
    init(defaults: UserDefaults = .standard)   // key "engagement.recents.ids", cap 10
}
```
`record` moves an existing id to the front (dedupe), caps at 10, persists `[String]`, publishes via `CurrentValueSubject` (mirror `FavoritesRepository`).

- [x] **Steps 1–4: TDD** — record order (most recent first), dedupe-moves-to-front, cap 10, persistence across instances.
- [x] **Step 5: Commit** `feat(engagement): recently-viewed repository`

### Task 5: CollectionsRepository

**Files:**
- Create: `InspireCreativityApp/Repositories/CollectionsRepository.swift`
- Test: `InspireCreativityAppTests/CollectionsRepositoryTests.swift`

**Interfaces (Produces):**
```swift
struct AnimationCollection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var animationIds: [String]
}
protocol CollectionsRepositoryProtocol: AnyObject {
    var collectionsPublisher: AnyPublisher<[AnimationCollection], Never> { get }
    func all() -> [AnimationCollection]
    @discardableResult func create(name: String) -> AnimationCollection
    func delete(_ id: UUID)
    func add(_ animationId: String, to collectionId: UUID)      // no duplicates
    func remove(_ animationId: String, from collectionId: UUID)
}
final class CollectionsRepository: CollectionsRepositoryProtocol {
    init(defaults: UserDefaults = .standard)
}
```
Storage: JSON blob under `engagement.collections` (AuthStore pattern). **First-run seed** (only when the key is absent): `Onboarding ideas` → `["aurora-mesh", "onboarding", "confetti", "spring-button"]`; `Client app · Nova` → `["liquid-tabs", "shimmer", "progress-arc", "toast"]` (all verified catalog ids).

- [x] **Steps 1–4: TDD** — first-run seed present, create appends + persists, add dedupes, remove/delete persist across instances, empty-key (post-delete-all) does not re-seed (persist an empty array is valid state).
- [x] **Step 5: Commit** `feat(engagement): user collections repository`

### Task 6: RecentSearchesStore

**Files:**
- Create: `InspireCreativityApp/Features/Search/RecentSearchesStore.swift`
- Test: `InspireCreativityAppTests/RecentSearchesStoreTests.swift`

**Interfaces (Produces):**
```swift
final class RecentSearchesStore {
    init(defaults: UserDefaults = .standard)   // key "engagement.search.recents", cap 8
    var queriesPublisher: AnyPublisher<[String], Never> { get }
    func all() -> [String]
    func record(_ query: String)   // trimmed, case-insensitive dedupe to front, ignores empty
    func clear()
}
```

- [x] **Steps 1–4: TDD** — record/dedupe (case-insensitive), cap 8, clear empties + persists, whitespace-only ignored.
- [x] **Step 5: Commit** `feat(search): persisted recent searches`

### Task 7: Activity inbox repository

**Files:**
- Create: `InspireCreativityApp/Engagement/ActivityRepository.swift`
- Test: `InspireCreativityAppTests/ActivityRepositoryTests.swift`

**Interfaces (Produces):**
```swift
struct ActivityItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case drop, streak, creator, priceDrop, trending, challenge }
    let id: String
    let kind: Kind
    let headline: String        // bold segment, e.g. "Friday Drop is live"
    let detail: String          // rest, e.g. "— 5 new Aurora animations"
    let subtitle: String        // e.g. "Aurora Ember is free this week"
    let date: Date
    let animationId: String?    // preview-tile rows
    let authorName: String?     // avatar rows
    var isRead: Bool
}
protocol ActivityRepositoryProtocol: AnyObject {
    var itemsPublisher: AnyPublisher<[ActivityItem], Never> { get }
    var unreadCount: Int { get }
    func all() -> [ActivityItem]                 // newest first
    func markAllRead()
    /// Seeds demo inbox on first run; appends one "Friday Drop is live" entry per ISO week when called on/after Friday.
    func refresh(now: Date)
}
final class ActivityRepository: ActivityRepositoryProtocol {
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current)
}
```
Keys: `engagement.activity.items` (JSON), `engagement.activity.lastDropWeek` (Int weekSeed). First-run seed (dates relative to `now`, copy verbatim from artboard 03):
- drop, "Friday Drop is live", "— 5 new Aurora animations", "Aurora Ember is free this week", now−2h, animationId "aurora-mesh", unread
- streak, "Daily pick is ready", "— keep the streak going", "Liquid Chrome · tap to preview", now−3h, animationId "liquid-chrome", unread
- creator, "Kenji Saito", "published Glass Ripple", "New in Metal Shaders · you follow Kenji", now−2d, authorName "Kenji Saito", unread
- priceDrop, "Wave Loader", "is in this week's free rotation", "From your favorites", now−3d, animationId "wave-loader", read
- trending, "Liquid Tab Bar", "is trending", "#1 in Navigation this week", now−3d, animationId "liquid-tabs", read
- challenge, "Challenge results", "are in", "Your entry placed top 10 in Spring Week", now−7d, read

- [x] **Steps 1–4: TDD** — first-run seeds 6 items newest-first, unreadCount==3, markAllRead → 0 and persists, `refresh` on a Friday appends drop entry once (second call same week: no duplicate), non-Friday appends nothing.
- [x] **Step 5: Commit** `feat(engagement): activity inbox repository with weekly drop entries`

### Task 8: Notification preferences + planner (pure)

**Files:**
- Create: `InspireCreativityApp/Notifications/NotificationPreferences.swift`
- Create: `InspireCreativityApp/Notifications/EngagementNotificationPlanner.swift`
- Test: `InspireCreativityAppTests/NotificationPlannerTests.swift`

**Interfaces (Produces):**
```swift
struct NotificationPreferences: Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable { case realtime, daily, weekly
        var title: String { /* "Real-time", "Daily digest", "Weekly" */ } }
    var isEnabled: Bool            // master
    var fridayDrops: Bool
    var freeThisWeek: Bool
    var creators: Bool
    var priceDrops: Bool
    var trending: Bool
    var streakReminders: Bool
    var frequency: Frequency
    static let `default` = NotificationPreferences(isEnabled: true, fridayDrops: true, freeThisWeek: true, creators: true, priceDrops: true, trending: false, streakReminders: true, frequency: .realtime)
    static func load(from defaults: UserDefaults) -> NotificationPreferences   // key "engagement.notifications.prefs"
    func save(to defaults: UserDefaults)
}
struct NotificationPlan: Equatable {
    let id: String; let title: String; let body: String
    let weekday: Int?   // Gregorian: 6 = Friday; nil = daily
    let hour: Int; let minute: Int
}
enum EngagementNotificationPlanner {
    static func plans(for prefs: NotificationPreferences, streak: Int) -> [NotificationPlan]
}
```
Plans (copy from artboard 01 pushes): master off → `[]`.
- `fridayDrops` → id `engagement.drop.friday`, "🎁 Friday Drop is live", "5 new animations just landed. One is always free this week.", Friday 08:00
- `freeThisWeek` → id `engagement.free.friday`, "Free this week rotated", "A new set of free animations is live. Grab them before next Friday.", Friday 09:00
- `streakReminders` **and** `streak >= 1` → id `engagement.streak.daily`, "🔥 \(streak)-day streak", "Your daily pick is ready. 30 seconds to stay inspired.", daily 19:30

- [x] **Steps 1–4: TDD** — default prefs round-trip via load/save with `UserDefaults(suiteName:)`; planner: all-on+streak 6 → 3 plans with exact ids/weekday/hour; master off → []; streak 0 suppresses streak plan; trending/creators/priceDrops produce no local plans.
- [x] **Step 5: Commit** `feat(notifications): preferences model and pure schedule planner`

### Task 9: Notification scheduling + coordinator

**Files:**
- Create: `InspireCreativityApp/Notifications/NotificationScheduling.swift`
- Create: `InspireCreativityApp/Notifications/NotificationCoordinator.swift`
- Test: `InspireCreativityAppTests/NotificationCoordinatorTests.swift`

**Interfaces (Produces):**
```swift
enum NotificationAuthorization: String { case notDetermined, denied, authorized }
protocol NotificationScheduling: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func removeAllPending()
    func schedule(_ plan: NotificationPlan)
}
final class SystemNotificationScheduler: NotificationScheduling { init() }  // UNUserNotificationCenter.current(), UNCalendarNotificationTrigger(repeats: true)
@MainActor final class NotificationCoordinator: ObservableObject {
    init(scheduler: NotificationScheduling, defaults: UserDefaults = .standard, analytics: AnalyticsTracking)
    @Published private(set) var preferences: NotificationPreferences
    @Published private(set) var authorization: NotificationAuthorization  // .notDetermined until refreshed
    var isRemindMeActive: Bool { authorization == .authorized && preferences.isEnabled && preferences.fridayDrops }
    func refreshAuthorization() async
    /// Requests system permission; on grant enables master + reapplies. Logs analytics.
    @discardableResult func requestPermission(streak: Int) async -> Bool
    func update(_ prefs: NotificationPreferences, streak: Int)   // save + apply
    func apply(streak: Int)  // removeAllPending, then schedule planner plans iff authorized && master
}
```
`SystemNotificationScheduler` is a thin untested wrapper (`UNMutableNotificationContent`, `DateComponents(hour:minute:weekday:)`). Coordinator logic is tested with a `SpyScheduler`.

- [x] **Steps 1–4: TDD (coordinator with SpyScheduler)** — `apply` when authorized+enabled schedules planner plans after `removeAllPending`; master off → only removal; denied → only removal; `requestPermission` granted → prefs.isEnabled true + apply called + `notificationPermission(granted:)` analytics event logged (extend `AnalyticsEvent` — see Task 10).
- [x] **Step 5: Commit** `feat(notifications): scheduling protocol, system scheduler, coordinator`

### Task 10: App wiring — tab, routes, DI, analytics

**Files:**
- Modify: `InspireCreativityApp/App/AppRouter.swift` (add `AppTab.search` between `.samples` and `.library` with title "Search", icon `magnifyingglass`; add `searchPath`; add routes `case activity`, `case notificationSettings`, `case collection(id: UUID)`)
- Modify: `InspireCreativityApp/App/RootView.swift` (mount Search tab content; `navigationDestination` branches for `.activity` → `ActivityView`, `.notificationSettings` → `NotificationSettingsView`, `.collection(id)` → `CollectionDetailView`)
- Modify: `InspireCreativityApp/App/AppContainer.swift` (register: `streakTracker`, `copyActivity`, `recentItemsRepository`, `collectionsRepository`, `activityRepository`, `recentSearches`, `notificationCoordinator`; update `makeDiscoverViewModel`/`makeBrowseViewModel`/`makeSearchViewModel`/`makeLibraryViewModel` signatures as later tasks define; `makeDetailViewModel` gains `recents.record(id)` + `copyActivity` hooks)
- Modify: `InspireCreativityApp/Analytics/AnalyticsScreen.swift` (add `case activity, search`; `case notificationSettings = "notification_settings"`)
- Modify: `InspireCreativityApp/Analytics/AnalyticsEvent.swift` (add `case notificationPermission(granted: Bool)` → name `notification_permission`, params `["granted": "true"/"false"]`)
- Test: extend `InspireCreativityAppTests/AnalyticsEventTests.swift` with the new event's name/params.

Interim: `ActivityView`/`NotificationSettingsView`/`CollectionDetailView`/Search tab body may reference the real views from Tasks 11–17; execute this task **together with skeleton view files** that later tasks flesh out (each skeleton = final file path + minimal body so the target compiles).

- [x] **Steps: implement, build both platforms** (`xcodebuild build -destination 'generic/platform=iOS Simulator'` and `-destination 'platform=macOS'`), analytics test passes, **commit** `feat(app): search tab, engagement routes, DI for engagement services`

### Task 11: Discover v2 (artboard 05)

**Files:**
- Rewrite: `InspireCreativityApp/Features/Discover/DiscoverViewModel.swift`
- Rewrite: `InspireCreativityApp/Features/Discover/DiscoverView.swift` (keep `UsageMockup` types — move them to `InspireCreativityApp/Features/Samples/UsageMockups.swift` if in the way)
- Create: `InspireCreativityApp/Features/Discover/DailyPickCard.swift`, `DropCountdownStrip.swift`, `WeeklyChallengeCard.swift`, `EngagementMiniCard.swift`
- Test: `InspireCreativityAppTests/DiscoverViewModelTests.swift`

**ViewModel outputs:** `dateLabel` ("Friday, July 17" via `Date.FormatStyle().weekday(.wide).month(.wide).day()`), `streak: Int`, `unreadCount: Int`, `dailyPick: AnimationItem?`, `dailyResetLabel: String`, `dropCountdownLabel: String` ("in 2d 14h · 5 new animations"), `challengeDaysLeft: String`, `challengeJoined: Bool` (persisted `engagement.challenge.joined.<weekSeed>`), `freeThisWeek: [AnimationItem]`, `trending: [AnimationItem]`, `isPro: Bool`, `isRemindMeActive: Bool`. Actions: `joinChallenge()` (sets joined + routes to Loaders category via router pending), `copyDailyPick()` (owned → `Clipboard.copy` + `copyActivity.recordCopy()` + analytics `.codeCopied`; locked → returns `.needsDetail` so the view pushes `.detail`).

**View layout (exact design values):** header row (date caption `textSecondary`, "Discover" `Theme.Typo.largeTitle`, streak chip: flame icon + count, bg `#FF9F0A` 14%, border 30%, radius 999; bell `IconButton` + red `#FF3B30` badge with `unreadCount`, push `.activity`) → Daily Pick card (h 210, radius 20, live preview via `AnimationPreviewRegistry.view(for:)`, top gradient overlay `black 25%→clear→black 72%`, "DAILY PICK" caps chip + reset chip both `black 45%` capsules, name 21 heavy + "\(author) · 30-second read" 12.5, white "Copy today's code" button) → Drop strip (🎁, "Next Friday Drop" 14/700, countdown label mono 12 `textSecondary`, accent capsule button bell+"Remind me" / green "Reminder set ✓" when `isRemindMeActive`; bg accent 10%, border accent 28%, radius 14) → Weekly challenge card (radius 18, gradient `#A78BFA 16% → #60A5FA 8%` 140°, border `#A78BFA` 30%, trophy + "WEEKLY CHALLENGE" caps 10.5/800 `#A78BFA`, trailing "3d left" mono, "Loader Week" 18/800, body "Build a loader that feels alive. Best entry ships in the library — with your name on it.", 3 overlapping `Avatar`s ("Maya Ortega", "Kenji Saito", "Lena Hofstad") + "214 entries", trailing `#A78BFA` "Join"/"Joined ✓" capsule) → "Free this week" + trailing "rotates Friday" section, horizontal `EngagementMiniCard` row (w 150, preview h 96 radius 13, name 12.5/650, price line mono 11) → "Trending now" + accent "See all" (→ Browse tab), mini-card row. Bottom padding 120 for the floating tab bar. Remove: AuroraPackPromoCard, category grid, "Aurora in the wild", "New & noteworthy" from Discover (categories → Browse v2, mockups → Samples).

- [x] **Steps: VM tests (daily pick wiring, joined persistence, copy-owned records copy activity, unread passthrough) → implement views → build → commit** `feat(discover): v2 engagement layer — daily pick, streak, drop countdown, challenge`

### Task 12: Notification priming + Remind-me flow (artboard 02)

**Files:**
- Create: `InspireCreativityApp/Features/Notifications/NotificationPrimingView.swift`
- Modify: `DiscoverView.swift` (Remind-me tap logic)

Full-screen cover (`.fullScreenCover` on iOS; `.sheet` fallback under `#if os(macOS)`). Background: `AnimationPreviewRegistry.view(for: "aurora-borealis")` at 50% opacity under gradient `rgba(10,10,12,0.55) → 0.92 @70%`. "Not now" capsule top-right (white 8% bg). Bell hero 76pt, radius 24, accent gradient, badge "5". Title "Never miss a\nFriday Drop." (32 heavy, -1 tracking). Subtitle "2–3 notifications a week, only about things you chose. Tune or mute anytime." Perk rows (38pt icon tiles white 7%): 🎁 "Friday Drops" / "Be first to grab the 5 new animations each week — one is always free."; 🏷️ "Price drops" / "When something on your favorites goes on sale."; ✨ "Creators you follow" / "New animations from authors you care about." CTA full-width 15-radius accent "Turn on notifications" → `coordinator.requestPermission(streak:)` (real system prompt; design's faux alert is not implemented) → granted: green-tinted "Notifications on ✓" state, auto-dismiss after 0.8s.

**Remind-me logic (Discover):** `.notDetermined` → present priming; `.denied` → `#if os(iOS)` open `UIApplication.openNotificationSettingsURLString`; `.authorized` → enable `fridayDrops` + master via `coordinator.update`, button flips to "Reminder set ✓".

- [x] **Steps: implement → build → commit** `feat(notifications): pre-permission priming screen and remind-me flow`

### Task 13: Activity inbox screen (artboard 03)

**Files:**
- Create: `InspireCreativityApp/Features/Notifications/ActivityView.swift` (+ `ActivityViewModel` in same file)

Pushed via `.activity`. Header: "Activity" 34/800 + trailing accent text button "Mark all read". Sections `Today` / `This week` / `Earlier` (caps 12/700 white 40%) grouped from item dates (`calendar.isDateInToday`, else within 7 days, else earlier). Rows: 46pt leading tile — `animationId` → preview tile (radius 12, tint bg); `authorName` → `Avatar(name, size: 46)`; else icon tile (flame `#FF9F0A` / trophy `#FFC857` at 16% bg, 30% border). Title: `Text(headline).fontWeight(.semibold) + Text(" \(detail)")` 14.5; subtitle 12.5 white 50%; trailing relative time (`Date.RelativeFormatStyle` short) + 8pt accent unread dot. Tap row with `animationId` → push `.detail`. `onAppear`: track screen `.activity`.

- [x] **Steps: implement → build → commit** `feat(engagement): activity inbox screen`

### Task 14: Notification preferences screen (artboard 04) + Settings entry

**Files:**
- Create: `InspireCreativityApp/Features/Notifications/NotificationSettingsView.swift`
- Modify: `InspireCreativityApp/Features/Settings/SettingsView.swift` (new `SettingsCard(title: "Notifications")` with `actionRow(icon: "bell.badge.fill", title: "Notifications", subtitle: "Drops, price drops, streaks")` → `router.push(.notificationSettings)` — place between About and Danger sections)

Layout (cards = white 4.5% bg, radius 14, hairline border): master card (40pt accent bell tile, "Push notifications" 15.5/700, "Usually 2–3 a week", trailing `Toggle` tinted `Theme.Palette.success`) → "WHAT YOU GET" card rows each with Toggle bound into `preferences` via `coordinator.update(_:streak:)`: Friday Drops/"The weekly release — 5 new animations", Free this week/"When a pro animation goes free", Creators you follow/"New animations from followed authors", Price drops/"Only for items in your favorites", Trending/"Popular in categories you browse", Streak reminders/"One nudge before your streak resets". Rows dim to 40% opacity when master off. → "DELIVERY" segmented capsule row (Real-time / Daily digest / Weekly; active = accent bg) + "Quiet hours" row "10:00 PM – 8:00 AM" with chevron (display-only) → footer "Notifications deep-link straight to the animation. Muting here never affects your library or purchases." If `authorization == .denied`: warning banner card "Notifications are off in iOS Settings." + "Open Settings" button (`#if os(iOS)`). Track screen `.notificationSettings`.

- [x] **Steps: implement → build → commit** `feat(notifications): preferences screen with per-category toggles`

### Task 15: Browse v2 (artboard 06)

**Files:**
- Rewrite: `InspireCreativityApp/Features/Browse/BrowseViewModel.swift`
- Rewrite: `InspireCreativityApp/Features/Browse/BrowseView.swift`
- Create: `InspireCreativityApp/Features/Browse/CategoryCard.swift`
- Rewrite test: `InspireCreativityAppTests/BrowseFilterTests.swift` → new VM API

**ViewModel:**
```swift
enum BrowseSort: String, CaseIterable { case popular = "Popular", rating = "Top rated", freeFirst = "Free first" }
enum BrowseScope: Hashable { case overview; case category(Category); case theme(String) }
// @Published: scope, sort, pageLimit (12, +12 per loadMore)
// outputs: categories [(Category, count)], themes [(String, count)] (from AuroraDescriptors.all),
// popular (top 6 by downloads), drillItems (filtered+sorted, prefix pageLimit), drillTotal, totalCount
```
Theme filter: ids of `AuroraDescriptors.all.filter { $0.theme == theme }` → items with those ids. Sorts: popular = downloads desc; rating = rating desc; freeFirst = `isFree` first then downloads desc. Keeps `router.pendingBrowseCategory` handoff (`scope = .category(c)`).

**View:** overview — "Browse" large title + "\(totalCount) animations · \(categories.count) categories · new every Friday"; search pill (non-editable, "Search animations, themes, authors…", tap → `router.selectedTab = .search`); "Categories" 2-col grid of `CategoryCard` (h 96, radius 16: rep preview right-edge width 110 masked with leading-fade gradient, left gradient `#0A0A0C 90% → clear` @90°, 7pt tint dot per category — tints: Backgrounds `#A78BFA`, Loaders `#22D3EE`, Buttons `#FF6B4A`, Micro-interactions `#F472B6`, Transitions `#34D399`, Navigation `#60A5FA`, Gestures `#FBBF24`, Onboarding `#FB7185`, Text effects `#C4B5FD`, Metal Shaders `#F97316` — accent "5 new" caps badge on Backgrounds, name 13.5/750, count mono 10.5); "Aurora themes" + "\(themes.count) moods" chips row (`Chip(theme, count:)` → `scope = .theme`); "Popular right now"/"most copied" 2-col `AnimationCard` grid; "Explore all \(totalCount) animations" bordered button → `scope = .category(.backgrounds)`. Drill — back chip ("← All" capsule, white 8%) → `.overview`; title + accent count pill (mono 11.5, accent 16% bg); sort chips row; 2-col grid; "Show more · \(remaining) left" bordered button.

- [x] **Steps: VM tests (theme filter, 3 sorts, paging, pending-category handoff) → FAIL → implement VM+views → PASS → build → commit** `feat(browse): v2 category-first browse with theme moods and drill-in sort`

### Task 16: Samples v2 (artboard 07)

**Files:**
- Rewrite: `SamplesView` (extract from `DiscoverView.swift` into `InspireCreativityApp/Features/Samples/SamplesView.swift` along with `UsageMockup`/`MockupViewRegistry` if not already moved)
- Create: `InspireCreativityApp/Features/Samples/SampleCodeSheet.swift`

Header "Samples" large + "\(count) real-app recipes — see it in context, copy the exact code". Featured (first mockup, only in "All" group): card h 250 radius 20 with live scaled mockup (`MockupViewRegistry.view(for:cardWidth:cardHeight:)`), bottom fade, "FEATURED RECIPE" caps chip, title 19/800 + "\(appName) · uses \(animationName)", white "View code" pill. Filter chips with counts — groups match on `title + appName + why` (case-insensitive regex, from design): All; AI & Voice `AI|voice|audio|assistant|chat|LLM`; Wellness `mindful|yoga|sleep|meditat|calm|empty|breath`; Fitness `workout|fitness|run|cycle|timer`; Money `finance|crypto|bank|trading|subscription|loyalty|paywall|premium|wallet`; Celebration `success|unlock|achiev|recap|milestone|wrapped|confirm|tier`. 2-col grid: thumb h 220 radius 16 (scaled live mockup + bottom fade), title 13.5/700, appName/why line 11.5, accent capsule chip (sparkle glyph + animation name). "Show more · N left" (+8, start 8). Tap → `SampleCodeSheet` (`.sheet` + `presentationDetents([.large])`): grabber, title + "\(appName) · \(animationName)", accent "Copy code"/"✓ Copied" button (copies `mockup.swiftCode ?? item.swiftCode` resolved like `DetailViewModel.code`; records `copyActivity.recordCopy()` + `.codeCopied` analytics), close X, `SwiftCodeView(source:)` scroll. Free/locked: samples code is copyable as-is (usage recipes, not the gated catalog source) — no paywall gate here.

- [x] **Steps: implement → build → run existing tests → commit** `feat(samples): v2 recipes tab — featured card, filters, code sheet`

### Task 17: Search v2 as 5th tab (artboard 08)

**Files:**
- Rewrite: `InspireCreativityApp/Features/Search/SearchViewModel.swift`
- Rewrite: `InspireCreativityApp/Features/Search/SearchView.swift`
- Test: `InspireCreativityAppTests/SearchViewModelTests.swift`

**ViewModel:** deps repository + `RecentSearchesStore` + analytics + journeyMetrics. `@Published var query`; outputs: `state` (idle/empty/results — keep existing enum), `recents: [String]` (from store), `suggestions = ["aurora","glass","spring","mesh","liquid","cosmic","free"]`, `trendingSearches: [(query: String, delta: Delta)]` with `enum Delta { up, down, same }` = `[("aurora mesh",.up),("liquid chrome",.up),("metal shaders",.same),("confetti",.up),("tab bar",.down)]`, `popular: [AnimationItem]` (ids `["aurora-mesh","liquid-chrome","liquid-tabs","hologram-card"]` resolved via `repository.find`). `commit(_ query: String)` records to store + sets query (called from suggestion/trending/recent taps + `.onSubmit`). `clearRecents()`. Debounced 180ms search (existing), logs `.search(termLength:)` + `journeyMetrics.recordSearch()` (existing pattern).

**View:** "Search" large title; input row (radius 12, white 7% bg, 1pt accent border when focused via `@FocusState`, magnifier, `TextField` "Animations, themes, authors…", clear ×). Idle: suggestion chips (bordered transparent capsules); "TRENDING SEARCHES" caps label + 5 rows (rank mono 14/800 — accent for top 3, white 35% after; query 15/550; delta glyph: up green arrow `#34D399`, down gray, same dash); "RECENT" caps + "Clear" (only when non-empty) + wrapped `Chip`s with clock glyph (use `FlowLayout`); "Popular this week"/"most searched" 2-col grid. Results: "\(n) result(s)" mono caption + 2-col grid (cap 12 rows + "Show more" reuse pattern from Browse if >12: simple `prefix(24)`). Empty: centered 56pt icon tile + "No matches for “\(query)”" 15/650 + "Try a theme like “cosmic” or an author’s name."

- [x] **Steps: VM tests (commit records recent, clear, popular resolution, results filter) → implement → build → commit** `feat(search): v2 discovery-first search as its own tab`

### Task 18: Library v2 (artboard 09)

**Files:**
- Rewrite: `InspireCreativityApp/Features/Library/LibraryViewModel.swift`
- Rewrite: `InspireCreativityApp/Features/Library/LibraryView.swift`
- Create: `InspireCreativityApp/Features/Library/LibraryStatsCard.swift`, `CollectionCard.swift`, `CollectionDetailView.swift`
- Test: `InspireCreativityAppTests/LibraryViewModelTests.swift` (new)

**ViewModel:** tabs `owned`/`favorites` only (drop `recent` — replaced by continue row). Outputs: `owned`, `favorites`, `recentItems` (RecentItemsRepository ids → items, order preserved), `collections: [AnimationCollection]`, `streak: Int`, `weekBars: [Int]`, `copiesThisWeek: Int`, `isPro`. Actions: `createCollection(named:)`, `deleteCollection(id:)`. Export: `var exportSnippet: SwiftSnippet` — combined `.swift` of the visible tab's items (cap 20, each prefixed `// MARK: - <Name> (<id>)`), via existing `CodeExport.SwiftSnippet`; locked items (pro && !isPro) excluded.

**View:** header "Library" + gear (unchanged). Stats card (radius 18, gradient `accent 16% over #131316 → #101013` 150°): `Avatar("You Dev", 46)`, "Hey, developer" 16/750 + `ProBadge` if pro, line: flame + "\(streak)-day streak" `#FF9F0A` 700 + "· \(owned) owned · \(favorites) saved" 60% — accent "Go Pro" capsule if !pro → `.paywall(source:"library")`; weekly bars (7 columns, h relative to max(bars) scaled to 32pt, today accent / others white 14%, day letters M T W T F S S mono 9) + right block: `copiesThisWeek` 18/800 mono + "copies this week" 9.5. → "Pick up where you left off" horizontal row (132pt `EngagementMiniCard` from Task 11, h 90) — hidden when empty. → "Collections" header + accent "New collection" (alert with `TextField`); horizontal row: `CollectionCard` w 168 (2×2 preview grid of first 4 ids, 56pt cells radius 7, name 13/700, "\(n) animations" mono 10.5) → push `.collection(id:)`; trailing dashed "New" tile (w 108, dashed 1.5 white 18% border, plus icon). → underline tabs "Owned \(n)" / "Favorites \(n)" (15/650, 2pt accent underline on active) + trailing "Export .swift" button (`ShareLink(item: exportSnippet, preview:)`, arrow-down icon, 12.5/650 white 60%). → 2-col `AnimationCard` grid + existing empty state. Remove the old sign-out row (Settings owns sign-out).

**CollectionDetailView:** `NavHeader(collection.name, onBack: router.pop)` + "\(n) animations" subtitle; 2-col grid with per-item context menu "Remove from collection"; toolbar "+" opens picker sheet (searchable catalog list, checkmark = membership toggle via repo add/remove); empty state "Nothing in this collection yet." + "Add animations" button opening the picker. Delete collection: trailing trash icon with confirmation dialog → `deleteCollection` + `router.pop()`.

- [x] **Steps: VM tests (recents mapping order, export excludes locked + caps 20, create/delete collection flows through repo) → implement → build → commit** `feat(library): v2 stats card, continue row, collections, swift export`

### Task 19: Lifecycle wiring + final verification

**Files:**
- Modify: `InspireCreativityApp/App/RootView.swift` — on appear + `scenePhase == .active`: `container.streakTracker.recordAppOpen()`, `container.activityRepository.refresh(now: Date())`, `Task { await container.notificationCoordinator.refreshAuthorization(); container.notificationCoordinator.apply(streak: container.streakTracker.current) }`
- Modify: `InspireCreativityApp/Features/Detail/DetailViewModel.swift` — `markViewed()` also `recents.record(item.id)`; `logCodeCopied()` also `copyActivity.recordCopy()`

- [x] **Step 1:** implement wiring; build.
- [x] **Step 2:** run FULL test suite — all green (fix any regressions in existing tests).
- [x] **Step 3:** launch in iOS Simulator via the `run-inspirecreativityapp` skill; screenshot Discover, Activity, Notification settings, Browse (overview + drill), Samples (+code sheet), Search, Library; compare against artboards; fix visual gaps.
- [x] **Step 4:** Commit `feat(engagement): lifecycle wiring for streaks, activity, notification scheduling`

## Self-Review Notes

- Artboard 01 (lock screen) is marketing/reference — its copy feeds the planner content (Task 8), not a screen.
- Design's fake iOS permission alert (artboard 02) intentionally replaced by the real `UNUserNotificationCenter` prompt.
- Creators/price-drop/trending toggles persist and render but schedule no local notifications (server push out of scope) — planner test asserts this explicitly.
- Weekly challenge is local-only engagement UI (no backend): static "Loader Week" content, Join routes to Loaders category; entries/avatars are display copy from the design.
- Type-consistency check: `NotificationPlan` produced by Task 8 is consumed by Task 9's `schedule(_:)`; `EngagementMiniCard` (Task 11) reused by Task 18's continue row; `RecentSearchesStore` (Task 6) consumed by Task 17; `SwiftSnippet` exists in `Animations/CodeExport.swift` (verified unused infra).
