//
//  Chip.swift
//  StaggerApp
//

import SwiftUI

/// Pill / chip used in filter rows and tag rows.
struct Chip: View {
    let title: String
    let count: Int?
    let isActive: Bool
    let action: () -> Void

    init(_ title: String, count: Int? = nil, isActive: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.count = count
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isActive ? Theme.Palette.accent : Color.white.opacity(0.06),
                in: Capsule()
            )
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        Chip("All", count: 24, isActive: true)
        Chip("Loaders", count: 5)
    }
    .padding()
    .background(Theme.Palette.background)
}
