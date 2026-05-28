//
//  NavHeader.swift
//  InspireCreativityApp
//
//  Large-title navigation header. Slim variant uses a centered title +
//  back button; large variant places a 32pt title under the bar.
//

import SwiftUI

struct NavHeader<Trailing: View>: View {
    let title: String
    let isLarge: Bool
    let onBack: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        isLarge: Bool = false,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.isLarge = isLarge
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let onBack {
                    IconButton("chevron.left", action: onBack)
                } else {
                    Color.clear.frame(width: 34, height: 34)
                }
                Spacer()
                if !isLarge {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                trailing()
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(minHeight: 36)

            if isLarge {
                Text(title)
                    .font(Theme.Typo.largeTitle)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
        }
        .padding(.top, 8)
    }
}
