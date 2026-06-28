//
//  MacDetailView.swift
//  InspireCreativityApp
//
//  macOS detail column: live animation preview on the left, selectable
//  syntax-highlighted source on the right, gated by CodeAccess.
//

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacDetailView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel: DetailViewModel
    @State private var showExporter = false

    init(viewModel: DetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var access: CodeAccess {
        CodeAccess.evaluate(itemIsPro: viewModel.item.isPro,
                            hasProEntitlement: viewModel.hasPro,
                            isAuthenticated: authStore.isAuthenticated)
    }

    private var canViewCode: Bool { access == .granted }

    var body: some View {
        HSplitView {
            // ── Left: live animation preview ──────────────────────────────
            ZStack {
                Color(hex: viewModel.item.tintHex)
                AnimationPreviewRegistry.interactiveView(for: viewModel.item.id)
            }
            .frame(minWidth: 280)

            // ── Right: code pane ──────────────────────────────────────────
            Group {
                if canViewCode {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Button {
                                Clipboard.copy(viewModel.code)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            Button {
                                Clipboard.copy(SwiftSource.bodyWithoutImports(viewModel.code))
                            } label: {
                                Label("Copy w/o imports", systemImage: "doc.on.clipboard")
                            }
                            Button {
                                showExporter = true
                            } label: {
                                Label("Save .swift", systemImage: "square.and.arrow.down")
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.top, 10)
                        .buttonStyle(.bordered)

                        ScrollView {
                            SwiftCodeView(source: viewModel.code)
                                .padding(12)
                        }
                    }
                } else {
                    lockedPanel
                }
            }
            .frame(minWidth: 360)
            .background(Theme.Palette.background)
            .fileExporter(
                isPresented: $showExporter,
                document: SwiftFileDocument(text: viewModel.code),
                contentType: .swiftSource,
                defaultFilename: SwiftSnippet.fileName(for: viewModel.item.name)
            ) { _ in }
        }
        .navigationTitle(viewModel.item.name)
    }

    // MARK: - Locked panel (inline; wiring to paywall/auth arrives in Task 10)

    @ViewBuilder
    private var lockedPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(access == .needsPro ? "Unlock with Pro" : "Sign in to view the code")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
