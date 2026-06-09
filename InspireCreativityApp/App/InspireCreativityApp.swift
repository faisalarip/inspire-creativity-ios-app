//
//  InspireCreativityApp.swift
//  InspireCreativityApp
//
//  App entry point. Wires the composition root and presents `RootView`.
//

import SwiftUI

@main
struct InspireCreativityApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.authStore)
                .environmentObject(container.store)
                .tint(Theme.Palette.accent)
                .preferredColorScheme(.dark)
        }
    }
}
