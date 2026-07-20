//
//  FloatingTabBar.swift
//  InspireCreativityApp
//
//  Floating liquid-glass pill tab bar. On iOS/macOS 26+ the bar and the
//  selection pill use the NATIVE Liquid Glass API (glassEffect); older
//  systems get the hand-rolled material fallback. One persistent pill
//  slides between tabs (conditional glass views freeze on iOS 26).
//

import SwiftUI

struct FloatingTabBar: View {
    /// Plain values only. Two hard-won rules from a rendering-freeze hunt:
    /// 1. `selected` is a value, not a Binding — binding-only children can be
    ///    skipped by the diff when the published value changes.
    /// 2. NEVER read UIKit window state (UIApplication.shared…) inside body —
    ///    it detaches this view from the update graph and freezes it. The
    ///    bottom inset is measured by RootView in an event context instead.
    let selected: AppTab
    let bottomInset: CGFloat
    let onSelect: (AppTab) -> Void

    private var activeIndex: Int {
        AppTab.allCases.firstIndex(of: selected) ?? 0
    }



    var body: some View {
        GeometryReader { proxy in
            let tabWidth = proxy.size.width / CGFloat(AppTab.allCases.count)

            ZStack(alignment: .topLeading) {
                // ONE persistent glass pill that slides — never conditionally
                // inserted (conditional glassEffect views freeze on iOS 26)
                // and no matchedGeometryEffect identity churn.
                selectionPill
                    .frame(width: tabWidth - 8, height: proxy.size.height - 8)
                    .offset(x: CGFloat(activeIndex) * tabWidth + 4, y: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeIndex)

                HStack(spacing: 0) {
                    ForEach(AppTab.allCases) { tab in
                        TabButton(tab: tab, isActive: tab == selected) {
                            onSelect(tab)
                        }
                        .frame(width: tabWidth)
                    }
                }
            }
        }
        .frame(height: 60)
        .padding(6)
        .background(barBackground)
        .clipShape(Capsule())
        .padding(.horizontal, 14)
        // Anchor 22pt above the PHYSICAL screen bottom (per the design), not
        // above the safe area — otherwise the pill floats ~56pt high on
        // home-indicator devices. Negative padding extends past the safe line.
        .padding(.bottom, 22 - bottomInset)
    }

    // MARK: - Selection pill

    @ViewBuilder
    private var selectionPill: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
    }

    // MARK: - Bar background

    @ViewBuilder
    private var barBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: .capsule)
        } else {
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)

                // Subtle vertical highlight gradient over the material to give
                // the pill the glass-meniscus look from the design.
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02),
                                Color.black.opacity(0.10),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
