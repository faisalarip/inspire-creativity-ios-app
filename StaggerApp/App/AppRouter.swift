//
//  AppRouter.swift
//  InspireCreativityApp
//
//  Per-tab navigation paths plus modal-style sheet presentations (Detail,
//  Paywall). The tab bar is hidden when a modal route is active to mirror
//  the prototype's behavior.
//

import SwiftUI
import Observation

/// Tabs the user can switch between.
enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case discover, browse, samples, library
    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .browse: "Browse"
        case .samples: "Samples"
        case .library: "Library"
        }
    }

    var icon: String {
        switch self {
        case .discover: "house.fill"
        case .browse: "square.grid.2x2.fill"
        case .samples: "play.rectangle.on.rectangle.fill"
        case .library: "books.vertical.fill"
        }
    }
}

/// Route values pushed onto a tab's NavigationStack.
enum AppRoute: Hashable {
    case detail(animationId: String)
    case paywall
}

/// Per-tab path storage + sheet presentation. Observable so views can bind.
@MainActor
final class AppRouter: ObservableObject {

    @Published var selectedTab: AppTab = .discover

    @Published var discoverPath: [AppRoute] = []
    @Published var browsePath: [AppRoute] = []
    @Published var samplesPath: [AppRoute] = []
    @Published var libraryPath: [AppRoute] = []

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        switch tab {
        case .discover: return Binding(get: { self.discoverPath }, set: { self.discoverPath = $0 })
        case .browse:   return Binding(get: { self.browsePath },   set: { self.browsePath = $0 })
        case .samples:   return Binding(get: { self.samplesPath },   set: { self.samplesPath = $0 })
        case .library:  return Binding(get: { self.libraryPath },  set: { self.libraryPath = $0 })
        }
    }

    func push(_ route: AppRoute) {
        switch selectedTab {
        case .discover: discoverPath.append(route)
        case .browse:   browsePath.append(route)
        case .samples:   samplesPath.append(route)
        case .library:  libraryPath.append(route)
        }
    }

    func pop() {
        switch selectedTab {
        case .discover: if !discoverPath.isEmpty { discoverPath.removeLast() }
        case .browse:   if !browsePath.isEmpty   { browsePath.removeLast() }
        case .samples:   if !samplesPath.isEmpty   { samplesPath.removeLast() }
        case .library:  if !libraryPath.isEmpty  { libraryPath.removeLast() }
        }
    }

    /// True when any tab has pushed a modal-ish screen (Detail or Paywall).
    var hidesTabBar: Bool {
        currentPath().last != nil
    }

    private func currentPath() -> [AppRoute] {
        switch selectedTab {
        case .discover: return discoverPath
        case .browse:   return browsePath
        case .samples:   return samplesPath
        case .library:  return libraryPath
        }
    }
}
