//
//  InspireCreativityApp.swift
//  InspireCreativityApp
//
//  App entry point. Wires the composition root and presents `RootView`.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct InspireCreativityApp: App {
    @StateObject private var container: AppContainer

    init() {
        // Configure Firebase BEFORE the composition root is built, so
        // AppContainer.makeAnalyticsTracker() sees a live FirebaseApp.app()
        // and returns FirebaseAnalyticsTracker (GA4). The canImport guard keeps
        // config-less slices (e.g. CI without plist) building cleanly.
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
        _container = StateObject(wrappedValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacRootView(container: container)
                .environmentObject(container)
                .environmentObject(container.authStore)
                .environmentObject(container.store)
                .tint(Theme.Palette.accent)
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
}
