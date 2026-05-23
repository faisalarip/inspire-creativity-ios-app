//
//  SectionHeader.swift
//  StaggerApp
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    let trailing: String?
    let onTrailing: (() -> Void)?

    init(_ title: String, trailing: String? = nil, onTrailing: (() -> Void)? = nil) {
        self.title = title
        self.trailing = trailing
        self.onTrailing = onTrailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.Typo.sectionTitle)
                .foregroundStyle(.white)
                .tracking(-0.4)
            Spacer()
            if let trailing {
                Button(action: { onTrailing?() }) {
                    Text(trailing)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.xxxl)
        .padding(.bottom, Theme.Spacing.lg)
    }
}
