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
            #if os(macOS)
            // Temporary macOS placeholder scene so the macOS slice links and
            // runs before the real Mac shell exists. Replaced in a later phase.
            Text("InspireCreativity for Mac — shell coming next")
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(container)
                .environmentObject(container.authStore)
                .environmentObject(container.store)
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
