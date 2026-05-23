//
//  StaggerApp.swift
//  StaggerApp
//
//  App entry point. Wires the composition root and presents `RootView`.
//

import SwiftUI

@main
struct StaggerApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .tint(Theme.Palette.accent)
                .preferredColorScheme(.dark)
        }
    }
}
