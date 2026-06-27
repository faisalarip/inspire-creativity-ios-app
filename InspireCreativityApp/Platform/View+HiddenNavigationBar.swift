//  View+HiddenNavigationBar.swift
import SwiftUI

extension View {
    /// Hides the navigation bar chrome on iOS. No-op on macOS, where
    /// `ToolbarPlacement.navigationBar` is unavailable (hard compile error).
    @ViewBuilder
    func hiddenNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
