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
        // and can select the Firebase tracker. Guarded so the app builds and
        // runs unchanged until the FirebaseCore package + plist are added.
        #if canImport(FirebaseCore)
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
        _container = StateObject(wrappedValue: AppContainer())
    }

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
