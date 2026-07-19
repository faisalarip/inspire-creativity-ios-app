//
//  OnboardingPreferences.swift
//  InspireCreativityApp
//
//  v2.1 first-session quest: one screen asks what the user is building and
//  tunes Discover toward those categories. 28% of installs never viewed a
//  single animation — this closes the first_open → animation_view gap.
//

import Combine
import Foundation

final class OnboardingPreferences {

    private enum Keys {
        static let done = "engagement.onboarding.done"
        static let categories = "engagement.onboarding.categories"
    }

    let didChange = PassthroughSubject<Void, Never>()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// True once the user finished (or skipped) the first-run screen.
    var isCompleted: Bool { defaults.bool(forKey: Keys.done) }

    /// Categories the user said they're building for; empty = skipped or
    /// no preference — callers fall back to the global curation.
    var categories: [Category] {
        (defaults.stringArray(forKey: Keys.categories) ?? [])
            .compactMap(Category.init(rawValue:))
    }

    /// Marks onboarding done. An empty selection is a valid "skip".
    func complete(categories: [Category]) {
        defaults.set(true, forKey: Keys.done)
        defaults.set(categories.map(\.rawValue), forKey: Keys.categories)
        didChange.send()
    }
}
