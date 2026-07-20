//
//  ActivityRepository.swift
//  InspireCreativityApp
//
//  The in-app Activity inbox (v2.0). Local-only: seeded once, then a
//  "Friday Drop is live" entry is appended each drop week. Persisted as a
//  JSON blob in UserDefaults.
//

import Combine
import Foundation

struct ActivityItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case drop, streak, creator, priceDrop, trending, challenge
    }

    let id: String
    let kind: Kind
    /// Bold leading segment, e.g. "Friday Drop is live".
    let headline: String
    /// Regular trailing segment, e.g. "— 5 new Aurora animations".
    let detail: String
    let subtitle: String
    let date: Date
    /// When set, the row leads with this animation's live preview tile.
    let animationId: String?
    /// When set (and `animationId` is nil), the row leads with an avatar.
    let authorName: String?
    var isRead: Bool
}

protocol ActivityRepositoryProtocol: AnyObject {
    var itemsPublisher: AnyPublisher<[ActivityItem], Never> { get }
    var unreadCount: Int { get }
    func all() -> [ActivityItem]
    func markAllRead()
    /// Seeds the demo inbox on first run; appends one drop entry per week
    /// when called on/after Friday.
    func refresh(now: Date)
}

final class ActivityRepository: ActivityRepositoryProtocol {

    private enum Keys {
        static let items = "engagement.activity.items"
        static let lastDropWeek = "engagement.activity.lastDropWeek"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let subject: CurrentValueSubject<[ActivityItem], Never>

    var itemsPublisher: AnyPublisher<[ActivityItem], Never> {
        subject.eraseToAnyPublisher()
    }

    var unreadCount: Int {
        subject.value.filter { !$0.isRead }.count
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Keys.items),
           let saved = try? JSONDecoder().decode([ActivityItem].self, from: data) {
            self.subject = CurrentValueSubject(saved)
        } else {
            self.subject = CurrentValueSubject([])
        }
    }

    func all() -> [ActivityItem] {
        subject.value.sorted { $0.date > $1.date }
    }

    func markAllRead() {
        update(subject.value.map { item in
            var read = item
            read.isRead = true
            return read
        })
    }

    func refresh(now: Date) {
        if subject.value.isEmpty, defaults.data(forKey: Keys.items) == nil {
            update(Self.seed(relativeTo: now))
        }
        appendDropEntryIfNeeded(now: now)
    }

    // MARK: - Weekly drop entry

    private func appendDropEntryIfNeeded(now: Date) {
        let periodSeed = EngagementSchedule.dropPeriodSeed(for: now, calendar: calendar)
        let stored = defaults.integer(forKey: Keys.lastDropWeek)
        defaults.set(periodSeed, forKey: Keys.lastDropWeek)
        // First run just records the current period — the seed inbox already
        // contains a drop entry. Later period changes append one entry each.
        guard stored != 0, stored != periodSeed else { return }
        let entry = ActivityItem(
            id: "drop-\(periodSeed)",
            kind: .drop,
            headline: "New drop is live",
            detail: "— 5 new animations",
            subtitle: "Fresh every Tuesday and Friday",
            date: now,
            animationId: "aurora-mesh",
            authorName: nil,
            isRead: false
        )
        update([entry] + subject.value)
    }

    // MARK: - First-run seed (copy from the v2.0 design)

    static func seed(relativeTo now: Date) -> [ActivityItem] {
        [
            ActivityItem(
                id: "seed-drop", kind: .drop,
                headline: "Friday Drop is live", detail: "— 5 new Aurora animations",
                subtitle: "Aurora Ember is free this week",
                date: now.addingTimeInterval(-2 * 3600),
                animationId: "aurora-mesh", authorName: nil, isRead: false
            ),
            ActivityItem(
                id: "seed-streak", kind: .streak,
                headline: "Daily pick is ready", detail: "— keep the streak going",
                subtitle: "Liquid Chrome · tap to preview",
                date: now.addingTimeInterval(-3 * 3600),
                animationId: "liquid-chrome", authorName: nil, isRead: false
            ),
            ActivityItem(
                id: "seed-creator", kind: .creator,
                headline: "Kenji Saito", detail: "published Glass Ripple",
                subtitle: "New in Metal Shaders · you follow Kenji",
                date: now.addingTimeInterval(-2 * 86_400),
                animationId: nil, authorName: "Kenji Saito", isRead: false
            ),
            ActivityItem(
                id: "seed-price", kind: .priceDrop,
                headline: "Wave Loader", detail: "is in this week's free rotation",
                subtitle: "From your favorites",
                date: now.addingTimeInterval(-3 * 86_400),
                animationId: "wave-loader", authorName: nil, isRead: true
            ),
            ActivityItem(
                id: "seed-trending", kind: .trending,
                headline: "Liquid Tab Bar", detail: "is trending",
                subtitle: "#1 in Navigation this week",
                date: now.addingTimeInterval(-3 * 86_400 - 1800),
                animationId: "liquid-tabs", authorName: nil, isRead: true
            ),
            ActivityItem(
                id: "seed-challenge", kind: .challenge,
                headline: "Challenge results", detail: "are in",
                subtitle: "Your entry placed top 10 in Spring Week",
                date: now.addingTimeInterval(-7 * 86_400),
                animationId: nil, authorName: nil, isRead: true
            ),
        ]
    }

    private func update(_ items: [ActivityItem]) {
        subject.send(items)
        defaults.set(try? JSONEncoder().encode(items), forKey: Keys.items)
    }
}
