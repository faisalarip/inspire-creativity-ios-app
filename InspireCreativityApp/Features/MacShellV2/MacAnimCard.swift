//
//  MacAnimCard.swift
//  InspireCreativityApp
//
//  Reusable animation card for the macOS redesigned shell (MacShellV2).
//  Precisely matches the reference MacAnimCard from macos-app.jsx.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

/// A tappable card that shows a live animation preview, optional Pro badge,
/// iOS version pill, hover "View code" overlay, and a name/category footer.
///
/// Matches the reference `MacAnimCard` from the Claude Design JSX exactly.
struct MacAnimCard: View {

    let item: AnimationItem
    var isSelected: Bool = false
    var height: CGFloat = 150
    let onOpen: () -> Void

    @State private var hover = false

    // MARK: - Body

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                // ── Card thumbnail ──────────────────────────────────────────
                ZStack(alignment: .topLeading) {
                    // Base: tint fill + live preview
                    ZStack {
                        Color(hex: item.tintHex)
                        AnimationPreviewRegistry.view(for: item.id)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? Theme.Palette.accent
                                    : Color.white.opacity(0.07),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )

                    // Pro badge — top-right
                    if item.isPro {
                        proBadge
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                    }

                    // iOS version pill — bottom-left
                    iosPill
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.bottom, 8)
                        .padding(.leading, 8)

                    // Hover overlay: "View code"
                    if hover {
                        viewCodeOverlay
                    }
                }
                .frame(height: height)
                .offset(y: hover ? -2 : 0)
                .shadow(
                    color: hover ? Color.black.opacity(0.35) : .clear,
                    radius: hover ? 12 : 0,
                    x: 0,
                    y: hover ? 6 : 0
                )
                .animation(.easeOut(duration: 0.18), value: hover)

                // ── Footer ─────────────────────────────────────────────────
                cardFooter
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hover = isHovering
        }
    }

    // MARK: - Subviews

    /// Gold gradient "PRO" badge shown at the top-right of the card.
    private var proBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "seal.fill")
                .font(.system(size: 7, weight: .heavy))
            Text("PRO")
                .font(.system(size: 9.5, weight: .heavy))
        }
        .foregroundColor(Color(red: 0x1A / 255, green: 0x0E / 255, blue: 0))
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            LinearGradient(
                colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }

    /// Frosted "iOS X+" pill shown at the bottom-left of the card.
    private var iosPill: some View {
        Text("iOS \(item.iosVersion)")
            .font(Theme.Typo.mono(9.5))
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                    )
            )
    }

    /// "View code" pill that fades in on hover.
    private var viewCodeOverlay: some View {
        ZStack {
            Color.black.opacity(0.30)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("View code")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.white.opacity(0.18))
                )
        }
        .frame(height: height)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: hover)
    }

    /// Name + category/price row below the card.
    private var cardFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(item.category.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))

                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))

                if item.isFree {
                    Text("Free")
                        .font(Theme.Typo.mono(12))
                        .foregroundColor(Color(hex: "#34D399"))
                } else {
                    Text("$\(Int(item.price ?? 0))")
                        .font(Theme.Typo.mono(12))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sample = AnimationItem(
        id: "springBounce",
        name: "Spring Bounce",
        category: .microInteractions,
        difficulty: .beginner,
        iosVersion: "17+",
        isPro: false,
        isFeatured: true,
        tintHex: "#F472B6",
        author: "Demo",
        handle: "@demo",
        downloads: 1200,
        rating: 4.8,
        price: nil,
        description: "A bouncy spring micro-interaction.",
        swiftCode: ""
    )
    MacAnimCard(item: sample, isSelected: false, height: 150) {}
        .frame(width: 220)
        .padding()
        .background(Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0C / 255))
}
#endif
