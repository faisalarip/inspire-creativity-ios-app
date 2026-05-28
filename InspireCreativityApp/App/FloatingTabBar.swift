//
//  FloatingTabBar.swift
//  InspireCreativityApp
//
//  Floating liquid-glass pill tab bar — detached from the screen edge with
//  heavy frosted blur, a meniscus highlight up top, a soft shadow beneath,
//  and a sliding accent pill that animates between active tabs.
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selected: AppTab

    private var activeIndex: Int {
        AppTab.allCases.firstIndex(of: selected) ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            let tabs = AppTab.allCases
            let tabWidth = (proxy.size.width - 12) / CGFloat(tabs.count)

            ZStack(alignment: .leading) {
                // Sliding accent pill underneath the buttons.
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .frame(width: tabWidth - 12,
                           height: proxy.size.height - 12)
                    .offset(
                        x: CGFloat(activeIndex) * tabWidth + 12,
                        y: 0
                    )
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: activeIndex)

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        TabButton(
                            tab: tab,
                            isActive: tab == selected,
                            tap: { selected = tab }
                        )
                        .frame(width: tabWidth)
                    }
                }
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: 60)
        .padding(6)
        .background(liquidGlassPill)
        .padding(.horizontal, 14)
        .padding(.bottom, 22)
    }

    /// Frosted-glass pill: ultraThinMaterial base + layered highlight gradients
    /// to simulate a glass meniscus, plus inner stroke + drop shadow for lift.
    private var liquidGlassPill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(.ultraThinMaterial)

            // Subtle vertical highlight gradient over the material to give the
            // pill the glass-meniscus look from the design.
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Hairline outer border for the 'wet' edge.
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

private struct TabButton: View {
    let tab: AppTab
    let isActive: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
            }
            .foregroundStyle(isActive
                             ? Theme.Palette.accent
                             : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .scaleEffect(isActive ? 1.02 : 1.0)
            .offset(y: isActive ? -1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
