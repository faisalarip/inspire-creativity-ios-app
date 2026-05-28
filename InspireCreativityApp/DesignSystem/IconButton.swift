//
//  IconButton.swift
//  InspireCreativityApp
//

import SwiftUI

/// 34pt circular icon button matching the prototype's nav buttons.
struct IconButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    init(_ systemName: String, tint: Color = .white, action: @escaping () -> Void) {
        self.systemName = systemName
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName.replacingOccurrences(of: ".", with: " "))
    }
}
