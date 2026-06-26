//
//  DetailView.swift
//  InspireCreativityApp
//
//  Drag-up code sheet detail. Three snap states: peek, half, full.
//

import SwiftUI

struct DetailView: View {

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel: DetailViewModel

    @State private var sheet: SheetState = .peek
    @State private var dragOffset: CGFloat = 0
    @State private var showAuthSheet = false
    /// True while a finger is on the interactive preview, so the enclosing
    /// ScrollView stops scrolling and the preview's own gesture wins.
    @State private var previewInteracting = false
    /// Drives the one-time "tap & drag to interact" hint shown over the preview
    /// for genuinely interactive (bespoke) animations.
    @State private var showInteractHint = false

    /// Whether this animation's Detail preview responds to touch.
    private var previewIsInteractive: Bool {
        AnimationPreviewRegistry.isInteractive(viewModel.item.id)
    }

    /// Three-way gate (see `CodeAccess`): the Pro entitlement unlocks code in
    /// any auth state, Pro items route to the paywall, and free items ask
    /// signed-out users for the (free) sign-in.
    private var access: CodeAccess {
        CodeAccess.evaluate(itemIsPro: viewModel.item.isPro,
                            hasProEntitlement: viewModel.hasPro,
                            isAuthenticated: authStore.isAuthenticated)
    }
    private var canViewCode: Bool { access == .granted }

    init(viewModel: DetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    enum SheetState {
        case peek, half, full
        func height(in containerHeight: CGFloat) -> CGFloat {
            switch self {
            case .peek: return 56
            case .half: return containerHeight * 0.55
            case .full: return containerHeight - 64
            }
        }
    }

    var body: some View {
        // The ZStack itself respects safe area — so the floating nav lands
        // just below the status bar with no manual inset math. Only the
        // background fill and the ScrollView extend behind the status bar,
        // each opting in to ignore safe area on their own layer.
        ZStack(alignment: .top) {
            Theme.Palette.background.ignoresSafeArea()

            GeometryReader { proxy in
                let h = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                let sheetHeight = max(256, sheet.height(in: h) + dragOffset)
                let previewHeight = max(180, h * 0.42)

                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ZStack {
                                Color(hex: viewModel.item.tintHex)
                                AnimationPreviewRegistry.interactiveView(for: viewModel.item.id)
                            }
                            .frame(height: previewHeight)
                            // Claim the touch at touch-down (minimumDistance 0) and
                            // disable the ScrollView while the finger is on the preview,
                            // so an interactive piece's own vertical drag isn't stolen
                            // by scrolling. Taps elsewhere scroll normally.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in previewInteracting = true }
                                    .onEnded { _ in previewInteracting = false }
                            )
                            // One-time hint for interactive previews. Fades out
                            // on its own and the moment the user starts touching.
                            .overlay(alignment: .bottom) {
                                if showInteractHint {
                                    InteractHintToast()
                                        .padding(.bottom, 14)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                        .allowsHitTesting(false)
                                }
                            }
                            .onAppear {
                                guard previewIsInteractive else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showInteractHint = true
                                }
                                // Auto-dismiss after a few seconds if untouched.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        showInteractHint = false
                                    }
                                }
                            }
                            .onChange(of: previewInteracting) { _, touching in
                                if touching && showInteractHint {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showInteractHint = false
                                    }
                                }
                            }

                            meta
                                .padding(.bottom, sheetHeight + 20)
                        }
                    }
                    .scrollDisabled(previewInteracting)
                    .ignoresSafeArea(edges: .top)

                    CodeSheet(
                        state: $sheet,
                        dragOffset: $dragOffset,
                        height: sheetHeight,
                        containerHeight: h,
                        fileName: filename + ".swift",
                        source: viewModel.code,
                        locked: !canViewCode,
                        lockTitle: access == .needsSignIn
                            ? "Sign in to view the full code"
                            : "Preview is limited",
                        lockCTA: access == .needsSignIn
                            ? "Sign in"
                            : "Unlock to view full code",
                        onUnlock: {
                            switch access {
                            case .needsPro: router.push(.paywall(source: "detail"))
                            case .needsSignIn: showAuthSheet = true
                            case .granted: break
                            }
                        },
                        onCopy: { viewModel.logCodeCopied() }
                    )
                }
            }

            // Floating nav row — sits in the safe area by default.
            HStack {
                IconButton("chevron.left") { router.pop() }
                Spacer()
                HStack(spacing: 8) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .accessibilityLabel("Share")
                    IconButton(viewModel.isFavorited ? "heart.fill" : "heart",
                               tint: viewModel.isFavorited ? Theme.Palette.accent : .white) {
                        viewModel.toggleFavorite()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAuthSheet) {
            AuthGateView()
                .environmentObject(authStore)
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuth in
            if isAuth { showAuthSheet = false }
        }
    }

    /// Share payload. Only includes the source when the signed-in user can
    /// view it, so sharing can't bypass the sign-in gate or the Pro paywall.
    private var shareText: String {
        if canViewCode {
            return "\(viewModel.item.name) — a SwiftUI animation from InspireCreativity\n\n\(viewModel.code)"
        } else {
            return "Check out \"\(viewModel.item.name)\" — a hand-crafted SwiftUI animation in InspireCreativity."
        }
    }

    private var filename: String {
        viewModel.item.name.replacingOccurrences(of: "[^A-Za-z0-9]+",
                                                  with: "",
                                                  options: .regularExpression)
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(viewModel.item.name)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                if viewModel.item.isPro { ProBadge() }
                Spacer()
            }

            statsBar

            Text(viewModel.item.description)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)

            ctaButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var statsBar: some View {
        HStack(spacing: 18) {
            statCell(label: "CATEGORY",
                     value: viewModel.item.category.displayName,
                     subtitle: nil)
            Divider().frame(height: 38).background(Color.white.opacity(0.08))
            statCell(label: "LEVEL",
                     value: viewModel.item.difficulty.rawValue.capitalized,
                     subtitle: nil)
            Divider().frame(height: 38).background(Color.white.opacity(0.08))
            statCell(label: "ACCESS",
                     value: viewModel.item.isPro ? "Pro" : "Free",
                     subtitle: nil,
                     highlight: viewModel.item.isPro)
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private func statCell(
        label: String,
        value: String,
        subtitle: AnyView?,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(highlight ? Theme.Palette.accent : .white)
            if let subtitle { subtitle }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var ctaButton: some View {
        if viewModel.isOwned {
            // No dead button — the code lives in the sheet below. Just a hint.
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.success)
                Text(viewModel.item.isFree
                     ? "Free — drag up for the code"
                     : "Unlocked — drag up for the code")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        } else {
            Button { router.push(.paywall(source: "detail")) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Unlock everything with Pro")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0x1A / 255, green: 0x0E / 255, blue: 0))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Theme.Palette.proGoldStart, Theme.Palette.proGoldEnd],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

/// Transient hint shown over an interactive Detail preview, letting the user
/// know the animation responds to touch (not just a passive loop).
private struct InteractHintToast: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Tap & drag to interact")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .accessibilityLabel("This preview is interactive. Tap and drag to play with the animation.")
    }
}
