//
//  MacDetailPane.swift
//  InspireCreativityApp
//
//  460-pt right-hand detail pane for the macOS redesigned shell (MacShellV2).
//  Preview · Meta · Code/About tabs · Copy / Save actions.
//  Matches the Claude Design reference (macos-discover.jsx — DetailPane).
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

// MARK: - MacDetailPane

struct MacDetailPane: View {

    // MARK: Dependencies & state

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel: DetailViewModel

    let onClose: () -> Void

    @State private var tab: DetailTab = .code
    @State private var replay: Int = 0
    @State private var showExporter = false
    @State private var showAuth = false
    @State private var showPaywall = false

    // MARK: Init — takes the animation id so Task 6 can apply .id(animId)
    // and force SwiftUI to recreate the pane on each selection change.

    init(animId: String, onClose: @escaping () -> Void) {
        // StateObject must be initialised in init, before body is evaluated.
        // The container environment object is not yet available here — we
        // create a temporary AppContainer solely to satisfy the initialiser;
        // the real VM is built via makeDetailViewModel inside onAppear when
        // the environment is live. However, SwiftUI's @StateObject lifecycle
        // means the wrappedValue closure is called only once at creation —
        // after the view is inserted into the hierarchy — so we cannot call
        // container.makeDetailViewModel here without the environment.
        //
        // The standard workaround: store the id, inject it via a factory
        // wrapper, and let the @StateObject hold a DetailViewModelBox that
        // lazily creates the real vm. Here we use a simpler approach that is
        // idiomatic for this codebase: pass the DetailViewModel directly (the
        // caller constructs it) or use a ViewModel wrapper.
        //
        // Since the plan says "init from container.makeDetailViewModel(animationId:)"
        // and "caller applies .id(animId)", we follow MacDetailView's pattern —
        // the caller passes an already-built DetailViewModel. We diverge from
        // the plan's @StateObject+init wording to match the codebase pattern.
        _viewModel = StateObject(wrappedValue:
            AppContainer().makeDetailViewModel(animationId: animId)
        )
        self.onClose = onClose
    }

    // Alternative convenience init used by Task 6 via factory:
    init(viewModel: DetailViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    // MARK: - Access

    private var access: CodeAccess {
        CodeAccess.evaluate(
            itemIsPro: viewModel.item.isPro,
            hasProEntitlement: viewModel.hasPro,
            isAuthenticated: authStore.isAuthenticated
        )
    }

    private var canViewCode: Bool { access == .granted }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            previewSection
            metaSection
            tabBar
            tabContent
        }
        .frame(width: 460)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#111115"))
        .fileExporter(
            isPresented: $showExporter,
            document: SwiftFileDocument(text: viewModel.code),
            contentType: .swiftSource,
            defaultFilename: SwiftSnippet.fileName(for: viewModel.item.name)
        ) { _ in }
        .sheet(isPresented: $showAuth) {
            AuthGateView()
                .environmentObject(container)
                .environmentObject(authStore)
                .environmentObject(container.store)
                .frame(minWidth: 480, minHeight: 620)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: container.makePaywallViewModel(source: "detail"))
                .environmentObject(container)
                .environmentObject(container.store)
                .frame(minWidth: 520, minHeight: 640)
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuth in
            if isAuth { showAuth = false }
        }
    }

    // MARK: - 1. Preview section (200pt)

    private var previewSection: some View {
        ZStack(alignment: .center) {
            Color(hex: viewModel.item.tintHex)
            AnimationPreviewRegistry.interactiveView(for: viewModel.item.id)
                .id(replay)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(16)
        .overlay(alignment: .topLeading) {
            LivePill()
                .padding(.top, 26).padding(.leading, 26)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton(action: onClose)
                .padding(.top, 26).padding(.trailing, 26)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("tap to replay")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 28).padding(.trailing, 28)
        }
        .onTapGesture {
            replay += 1
        }
    }

    // MARK: - 2. Meta section

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NameRow(item: viewModel.item)
            StatsRow(item: viewModel.item)
            ChipsRow(item: viewModel.item)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: - 3. Tab bar

    private var tabBar: some View {
        DetailTabBar(tab: $tab)
    }

    // MARK: - 4. Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .code:
            codeTabContent
        case .about:
            aboutTabContent
        }
    }

    // MARK: Code tab

    @ViewBuilder
    private var codeTabContent: some View {
        if canViewCode {
            VStack(spacing: 0) {
                ActionBar(
                    onCopy: { Clipboard.copy(viewModel.code) },
                    onCopyBody: { Clipboard.copy(SwiftSource.bodyWithoutImports(viewModel.code)) },
                    onSave: { showExporter = true }
                )
                ScrollView(.vertical, showsIndicators: true) {
                    SwiftCodeView(source: viewModel.code)
                        .padding(12)
                }
            }
        } else {
            LockedCodePanel(access: access) {
                if access == .needsSignIn { showAuth = true }
                else { showPaywall = true }
            }
        }
    }

    // MARK: About tab

    private var aboutTabContent: some View {
        AboutPanel(item: viewModel.item)
    }
}

// MARK: - Tab enum

private enum DetailTab: String, CaseIterable {
    case code  = "Code"
    case about = "About"
}

// MARK: - Subviews

// ── Live pill ──────────────────────────────────────────────────────────────────

private struct LivePill: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "#34D399"))
                .frame(width: 6, height: 6)
            Text("LIVE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.45), in: Capsule())
    }
}

// ── Close button ───────────────────────────────────────────────────────────────

private struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// ── Name row ───────────────────────────────────────────────────────────────────

private struct NameRow: View {
    let item: AnimationItem
    var body: some View {
        HStack(spacing: 8) {
            Text(item.name)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(.white)
            if item.isPro {
                ProBadgeInline()
            }
        }
    }
}

private struct ProBadgeInline: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
    }
}

// ── Stats row ──────────────────────────────────────────────────────────────────

private struct StatsRow: View {
    let item: AnimationItem
    var body: some View {
        HStack(spacing: 0) {
            Group {
                Text(item.author)
                    .foregroundStyle(.white.opacity(0.7))
                dot
                Text("★ \(String(format: "%.1f", item.rating))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                dot
                Text("\(item.downloads / 1000)k ↓")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 12))

            Spacer()

            if item.isFree {
                Text("Free")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#34D399"))
            } else {
                Text(item.price.map { "$\(String(format: "%.2f", $0))" } ?? "Pro")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
    }

    private var dot: some View {
        Text(" · ")
            .foregroundStyle(.white.opacity(0.35))
            .font(.system(size: 12))
    }
}

// ── Chips row ─────────────────────────────────────────────────────────────────

private struct ChipsRow: View {
    let item: AnimationItem
    var body: some View {
        HStack(spacing: 6) {
            MetaChip(label: "iOS \(item.iosVersion)")
            MetaChip(label: item.category.displayName)
            MetaChip(label: item.difficulty.rawValue.capitalized)
        }
    }
}

private struct MetaChip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

private struct DetailTabBar: View {
    @Binding var tab: DetailTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { t in
                TabButton(title: t.rawValue, isActive: tab == t) {
                    withAnimation(.easeInOut(duration: 0.15)) { tab = t }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#111115"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
        .padding(.horizontal, 18)
    }
}

private struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 10)
                Rectangle()
                    .fill(isActive ? Theme.Palette.accent : .clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// ── Action bar ────────────────────────────────────────────────────────────────

private struct ActionBar: View {
    let onCopy: () -> Void
    let onCopyBody: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ActionBarButton(label: "Copy", icon: "doc.on.doc", action: onCopy)
            ActionBarButton(label: "Copy w/o imports", icon: "doc.on.clipboard", action: onCopyBody)
            ActionBarButton(label: "Save .swift", icon: "square.and.arrow.down", action: onSave)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#111115"))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }
}

private struct ActionBarButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11.5))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// ── Locked code panel ─────────────────────────────────────────────────────────

private struct LockedCodePanel: View {
    let access: CodeAccess
    let onCTA: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Button(action: onCTA) {
                Text(access == .needsPro ? "Unlock with Pro" : "Sign in to view the code")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ── About panel ───────────────────────────────────────────────────────────────

private struct AboutPanel: View {
    let item: AnimationItem
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.description)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                StatsGrid(item: item)
            }
            .padding(16)
        }
    }
}

private struct StatsGrid: View {
    let item: AnimationItem
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(label: "Rating",     value: "★ \(String(format: "%.1f", item.rating))")
            StatCard(label: "Downloads",  value: "\(item.downloads / 1000)k")
            StatCard(label: "Category",   value: item.category.displayName)
            StatCard(label: "Difficulty", value: item.difficulty.rawValue.capitalized)
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#endif
