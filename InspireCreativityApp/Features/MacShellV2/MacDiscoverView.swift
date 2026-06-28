//
//  MacDiscoverView.swift
//  InspireCreativityApp
//
//  Editorial "Discover" homepage for the macOS redesigned shell (MacShellV2).
//  Precisely matches the reference macos-discover.jsx from Claude Design.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

// MARK: - MacDiscoverView

struct MacDiscoverView: View {

    @ObservedObject var container: AppContainer
    let selectedID: String?
    let onOpen: (String) -> Void
    let onNav: (MacNav) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                heroSection
                statStrip
                trendingRow
                categoryTiles
                freshGrid
                creatorsRow
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HeroSection(
            container: container,
            onOpen: onOpen
        )
        .padding(.top, 24)
    }

    // MARK: - Stat Strip

    private var statStrip: some View {
        StatStrip(container: container)
            .padding(.top, 18)
    }

    // MARK: - Trending Row

    private var trendingRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Trending now", hint: "Most copied this week")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(container.animationRepository.trending()) { item in
                        MacAnimCard(item: item, isSelected: item.id == selectedID, height: 128) {
                            onOpen(item.id)
                        }
                        .frame(width: 200)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Category Tiles

    private var categoryTiles: some View {
        CategoryTilesSection(container: container, onNav: onNav)
    }

    // MARK: - Fresh Grid

    private var freshGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Fresh this week", hint: "Just added")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200), spacing: 16)],
                spacing: 16
            ) {
                ForEach(container.animationRepository.newlyAdded()) { item in
                    MacAnimCard(item: item, isSelected: item.id == selectedID, height: 130) {
                        onOpen(item.id)
                    }
                }
            }
        }
    }

    // MARK: - Creators Row

    private var creatorsRow: some View {
        CreatorsRow(container: container)
    }
}

// MARK: - HeroSection

private struct HeroSection: View {

    let container: AppContainer
    let onOpen: (String) -> Void

    @State private var hover = false

    var body: some View {
        let featured = container.animationRepository.featured()
        Button {
            onOpen(featured.id)
        } label: {
            heroCard(for: featured)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .offset(y: hover ? -2 : 0)
        .shadow(
            color: hover ? Color.black.opacity(0.4) : .clear,
            radius: hover ? 16 : 0, x: 0, y: hover ? 8 : 0
        )
        .animation(.easeOut(duration: 0.18), value: hover)
    }

    private func heroCard(for featured: AnimationItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background: tint + live preview
            ZStack {
                Color(hex: featured.tintHex)
                AnimationPreviewRegistry.view(for: featured.id)
                    .allowsHitTesting(false)
            }

            // Left-to-transparent dark gradient scrim
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Overlaid content
            HeroContent(item: featured)
                .frame(maxWidth: 460)
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - HeroContent

private struct HeroContent: View {

    let item: AnimationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "FEATURED TODAY" pill
            featuredPill

            // Title
            Text(item.name)
                .font(.system(size: 38, weight: .heavy))
                .tracking(-1.2)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // First sentence of description
            if let firstSentence = item.description.components(separatedBy: ".").first, !firstSentence.isEmpty {
                Text(firstSentence.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            // Author row
            heroFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featuredPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: 6, height: 6)
            Text("FEATURED TODAY")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.9)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
    }

    private var heroFooter: some View {
        HStack(spacing: 12) {
            // Author avatar (initials)
            InitialsAvatar(name: item.author, size: 28)

            Text(item.author)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Text("★ \(String(format: "%.1f", item.rating))")
                .font(Theme.Typo.mono(12))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            // "View code →" accent button
            Text("View code →")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Palette.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Theme.Palette.accent.opacity(0.18))
                )
        }
    }
}

// MARK: - StatStrip

private struct StatStrip: View {

    let container: AppContainer

    var body: some View {
        let all = container.animationRepository.all()
        let freeCount = all.filter { $0.isFree }.count
        let auroraThemes = all.filter { $0.category == .backgrounds }.count

        let cells: [(value: String, label: String, color: Color)] = [
            ("\(all.count)", "animations", Color(hex: "#FF6B4A")),
            ("\(auroraThemes)", "aurora themes", Color(hex: "#A78BFA")),
            ("\(freeCount)", "free to grab", Color(hex: "#34D399")),
            ("Fri", "new drops weekly", Color(hex: "#60A5FA"))
        ]

        HStack(spacing: 12) {
            ForEach(cells, id: \.label) { cell in
                StatCell(value: cell.value, label: cell.label, color: cell.color)
            }
        }
    }
}

private struct StatCell: View {

    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(Theme.Typo.mono(22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - CategoryTilesSection

private struct CategoryTilesSection: View {

    let container: AppContainer
    let onNav: (MacNav) -> Void

    var body: some View {
        let categories = container.animationRepository.categories()

        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Browse by category", hint: "\(categories.count) collections")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 232), spacing: 12)],
                spacing: 12
            ) {
                ForEach(categories, id: \.category) { entry in
                    CategoryTile(
                        entry: entry,
                        repItem: container.animationRepository.items(in: entry.category).first,
                        onNav: onNav
                    )
                }
            }
        }
    }
}

private struct CategoryTile: View {

    let entry: (category: Category, count: Int)
    let repItem: AnimationItem?
    let onNav: (MacNav) -> Void

    @State private var hover = false

    var body: some View {
        Button {
            onNav(.category(entry.category))
        } label: {
            tileContent
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .scaleEffect(hover ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.16), value: hover)
    }

    private var tileContent: some View {
        ZStack(alignment: .bottomLeading) {
            // Background: rep tint
            Color(hex: repItem?.tintHex ?? "#1a1a1f")

            // Rep preview (masked on right)
            if let repItem {
                HStack(spacing: 0) {
                    Spacer()
                    AnimationPreviewRegistry.view(for: repItem.id)
                        .allowsHitTesting(false)
                        .frame(width: 100)
                        .clipped()
                }
            }

            // Left-to-transparent gradient
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Tile info
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: MacCategoryStyle.iconName(entry.category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MacCategoryStyle.tint(entry.category))

                Text(entry.category.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("\(entry.count) animations")
                    .font(Theme.Typo.mono(11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
}

// MARK: - CreatorsRow

private struct CreatorsRow: View {

    let container: AppContainer

    var body: some View {
        let creators = aggregatedCreators(from: container.animationRepository.all())

        VStack(alignment: .leading, spacing: 0) {
            SectionHead(title: "Top creators", hint: "Animators behind the library")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(creators.prefix(6)) { creator in
                        CreatorCard(creator: creator)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func aggregatedCreators(from items: [AnimationItem]) -> [CreatorSummary] {
        var byAuthor: [String: (handle: String, count: Int, totalDownloads: Int)] = [:]
        for item in items {
            let existing = byAuthor[item.author]
            byAuthor[item.author] = (
                handle: existing?.handle ?? item.handle,
                count: (existing?.count ?? 0) + 1,
                totalDownloads: (existing?.totalDownloads ?? 0) + item.downloads
            )
        }
        return byAuthor.map { name, info in
            CreatorSummary(
                id: name,
                name: name,
                handle: info.handle,
                count: info.count,
                totalDownloads: info.totalDownloads
            )
        }
        .sorted { $0.totalDownloads > $1.totalDownloads }
    }
}

private struct CreatorSummary: Identifiable {
    let id: String
    let name: String
    let handle: String
    let count: Int
    let totalDownloads: Int
}

private struct CreatorCard: View {

    let creator: CreatorSummary

    var body: some View {
        VStack(spacing: 10) {
            InitialsAvatar(name: creator.name, size: 52)

            VStack(spacing: 3) {
                Text(creator.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(creator.handle)
                    .font(Theme.Typo.mono(11))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)

                Text("\(creator.count) animations · \(creator.totalDownloads / 1000)k ↓")
                    .font(Theme.Typo.mono(10))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 168)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }
}

// MARK: - SectionHead

private struct SectionHead: View {

    let title: String
    let hint: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)

            Text(hint)
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.top, 26)
        .padding(.bottom, 14)
    }
}

// MARK: - InitialsAvatar

private struct InitialsAvatar: View {

    let name: String
    let size: CGFloat

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var gradientColors: [Color] {
        let seed = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hue = Double(seed % 360) / 360.0
        return [
            Color(hue: hue, saturation: 0.7, brightness: 0.8),
            Color(hue: fmod(hue + 0.12, 1.0), saturation: 0.6, brightness: 0.6)
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initials)
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    MacDiscoverView(
        container: AppContainer(),
        selectedID: nil,
        onOpen: { _ in },
        onNav: { _ in }
    )
    .frame(width: 900, height: 800)
    .background(Color(hex: "#0a0a0c"))
}
#endif
