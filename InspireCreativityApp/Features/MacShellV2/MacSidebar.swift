//
//  MacSidebar.swift
//  InspireCreativityApp
//
//  248-pt sidebar with tinted category rows, Library section,
//  and a Pro card at the bottom. macOS-only.
//  Matches the Claude Design reference (macos-app.jsx).
//

#if os(macOS)
import SwiftUI

// MARK: - Navigation enum

/// Top-level navigation destinations driven by the sidebar.
/// Defined here so MacSidebar can remain self-contained at compile time;
/// the root shell (Task 6) will import and bind it.
enum MacNav: Hashable {
    case discover
    case owned
    case favorites
    case recent
    case category(Category)
}

// MARK: - MacSidebar

struct MacSidebar: View {

    // MARK: Dependencies
    let container: AppContainer
    @ObservedObject var store: StoreManager
    @Binding var selection: MacNav
    let onGoPro: () -> Void

    // MARK: Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Discover ──────────────────────────────────────────────
                Row(
                    icon: MacCategoryStyle.discoverIcon,
                    label: "Discover",
                    count: nil,
                    tint: .white,
                    isActive: selection == .discover
                ) {
                    selection = .discover
                }

                // ── Categories ────────────────────────────────────────────
                sectionLabel("CATEGORIES")

                ForEach(container.animationRepository.categories(), id: \.category) { entry in
                    Row(
                        icon: MacCategoryStyle.iconName(entry.category),
                        label: entry.category.displayName,
                        count: entry.count,
                        tint: MacCategoryStyle.tint(entry.category),
                        isActive: selection == .category(entry.category)
                    ) {
                        selection = .category(entry.category)
                    }
                }

                // ── Library ───────────────────────────────────────────────
                sectionLabel("LIBRARY")

                let allItems = container.animationRepository.all()

                Row(
                    icon: MacCategoryStyle.ownedIcon,
                    label: "Owned",
                    count: allItems.filter { $0.isFree || store.isPro }.count,
                    tint: Color(hex: "#60A5FA"),
                    isActive: selection == .owned
                ) {
                    selection = .owned
                }

                Row(
                    icon: MacCategoryStyle.favoritesIcon,
                    label: "Favorites",
                    count: allItems.filter { container.favoritesRepository.isFavorite($0.id) }.count,
                    tint: Color(hex: "#FB7185"),
                    isActive: selection == .favorites
                ) {
                    selection = .favorites
                }

                Row(
                    icon: MacCategoryStyle.recentIcon,
                    label: "Recent",
                    count: min(3, allItems.count),
                    tint: Color(hex: "#FBBF24"),
                    isActive: selection == .recent
                ) {
                    selection = .recent
                }

                Spacer(minLength: 24)

                // ── Pro card ──────────────────────────────────────────────
                proCard(allItems: allItems)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .frame(width: 248)
        .background(Color.white.opacity(0.015))
        .overlay(alignment: .trailing) {
            // Right hairline border
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
        }
    }

    // MARK: - Section label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Color.white.opacity(0.32))
            .padding(.top, 18)
            .padding(.bottom, 4)
            .padding(.leading, 6)
    }

    // MARK: - Pro card

    @ViewBuilder
    private func proCard(allItems: [AnimationItem]) -> some View {
        if store.isPro {
            // Compact Pro-active confirmation
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Palette.proGoldStart)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pro · Active")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Lifetime — all unlocked")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.50))
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        } else {
            // Full Pro card
            let total     = allItems.count
            let freeCount = allItems.filter(\.isFree).count

            VStack(alignment: .leading, spacing: 10) {
                // Header: star + "Pro" label
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#FFC857"))
                    Text("Pro")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }

                // Subtitle
                Text("Unlock all \(total) animations. \(freeCount) free to start.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                // Go Pro button
                Button(action: onGoPro) {
                    Text("Go Pro")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#0a0a0c"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Palette.accent.opacity(0.28),
                                Color(hex: "#1a1a1f"),
                                Color(hex: "#141417")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }
}

// MARK: - Row

private struct Row: View {

    let icon: String
    let label: String
    let count: Int?
    let tint: Color
    let isActive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // 3-pt accent left bar (active only)
                Rectangle()
                    .fill(isActive ? Theme.Palette.accent : Color.clear)
                    .frame(width: 3, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isActive ? Theme.Palette.accent : tint)
                    .frame(width: 20)

                // Label
                Text(label)
                    .font(.system(size: 13.5, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : Color.white.opacity(0.75))

                Spacer()

                // Count pill
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(isActive ? Theme.Palette.accent : Color.white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isActive
                        ? Theme.Palette.accent.opacity(0.16)
                        : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                )
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selection: MacNav = .discover
    let container = AppContainer()
    return MacSidebar(
        container: container,
        store: container.store,
        selection: $selection,
        onGoPro: {}
    )
    .frame(height: 700)
    .background(Color(hex: "#0a0a0c"))
}
#endif
