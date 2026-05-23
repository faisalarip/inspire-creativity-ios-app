//
//  DetailView.swift
//  StaggerApp
//
//  Drag-up code sheet detail. Three snap states: peek, half, full.
//

import SwiftUI

struct DetailView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: DetailViewModel

    @State private var sheet: SheetState = .peek
    @State private var dragOffset: CGFloat = 0
    @State private var replayId = UUID()

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
        GeometryReader { proxy in
            let h = proxy.size.height
            let sheetHeight = max(56, sheet.height(in: h) + dragOffset)
            let previewHeight = max(180, h * 0.42)

            ZStack(alignment: .bottom) {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ZStack {
                            Color(hex: viewModel.item.tintHex)
                            AnimationPreviewRegistry.view(for: viewModel.item.id)
                                .id(replayId)

                            VStack {
                                Spacer()
                                replayPill
                                    .padding(.bottom, 12)
                            }
                        }
                        .frame(height: previewHeight)
                        .onTapGesture { replayId = UUID() }

                        meta
                            .padding(.bottom, sheetHeight + 20)
                    }
                }

                // Top floating nav controls
                VStack {
                    HStack {
                        IconButton("chevron.left") { router.pop() }
                        Spacer()
                        HStack(spacing: 8) {
                            IconButton("square.and.arrow.up") {}
                            IconButton(viewModel.isFavorited ? "heart.fill" : "heart",
                                       tint: viewModel.isFavorited ? Theme.Palette.accent : .white) {
                                viewModel.toggleFavorite()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    Spacer()
                }

                // Bottom code sheet
                CodeSheet(
                    state: $sheet,
                    dragOffset: $dragOffset,
                    height: sheetHeight,
                    fileName: filename + ".swift",
                    source: viewModel.item.swiftCode,
                    locked: !viewModel.isOwned,
                    onUnlock: { router.push(.paywall) }
                )
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var filename: String {
        viewModel.item.name.replacingOccurrences(of: "[^A-Za-z0-9]+",
                                                  with: "",
                                                  options: .regularExpression)
    }

    private var replayPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
            Text("Tap to replay")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
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

            HStack(spacing: 10) {
                Avatar(viewModel.item.author, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.item.author)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(viewModel.item.handle)
                        .font(Theme.Typo.mono(12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button("Follow") {}
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            HStack(spacing: 6) {
                Badge("iOS \(viewModel.item.iosVersion)",
                      icon: "iphone",
                      foreground: Theme.Palette.iosBlue,
                      background: Theme.Palette.iosBlue.opacity(0.18))
                DifficultyBadge(level: viewModel.item.difficulty)
                Badge(viewModel.item.category.displayName)
            }

            statsBar

            Text(viewModel.item.description)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)

            LiveParametersPanel(
                response: $viewModel.paramResponse,
                damping: $viewModel.paramDamping,
                scale: $viewModel.paramScale,
                onReset: { viewModel.resetParams() }
            )

            ctaButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private var statsBar: some View {
        HStack(spacing: 18) {
            statCell(label: "RATING",
                     value: String(format: "%.1f", viewModel.item.rating),
                     subtitle: AnyView(RatingView(value: viewModel.item.rating, size: 9)))
            Divider().frame(height: 38).background(Color.white.opacity(0.08))
            statCell(label: "DOWNLOADS",
                     value: "\(viewModel.item.downloads / 1000)k",
                     subtitle: nil)
            Divider().frame(height: 38).background(Color.white.opacity(0.08))
            statCell(label: "PRICE",
                     value: viewModel.item.priceLabel,
                     subtitle: nil,
                     highlight: !viewModel.item.isFree)
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
            Button {} label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text(viewModel.item.isFree ? "Add to Library — Free" : "Owned")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 8) {
                Button { viewModel.purchase() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Unlock for $\(viewModel.item.price ?? 0, specifier: "%.2f")")
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

                Button { router.push(.paywall) } label: {
                    HStack(spacing: 4) {
                        Text("Or unlock everything with")
                            .foregroundStyle(.white)
                        Text("Stagger Pro")
                            .foregroundStyle(Theme.Palette.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
