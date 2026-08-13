//
//  CollectionDetailView.swift
//  InspireCreativityApp
//
//  A single user collection: its animations, an add-picker, and delete.
//

import Combine
import SwiftUI

struct CollectionDetailView: View {

    let collectionId: UUID

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    @State private var collection: AnimationCollection?
    @State private var showPicker = false
    @State private var confirmDelete = false

    private var items: [AnimationItem] {
        (collection?.animationIds ?? []).compactMap { container.animationRepository.find(id: $0) }
    }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if items.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                            spacing: 14
                        ) {
                            ForEach(items) { item in
                                AnimationCard(item) {
                                    router.push(.detail(animationId: item.id))
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        container.collectionsRepository.remove(item.id, from: collectionId)
                                    } label: {
                                        Label("Remove from collection", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 110)
            }
        }
        .onReceive(container.collectionsRepository.collectionsPublisher) { collections in
            collection = collections.first { $0.id == collectionId }
        }
        .sheet(isPresented: $showPicker) {
            CollectionPickerSheet(collectionId: collectionId)
                .environmentObject(container)
        }
        .confirmationDialog(
            "Delete “\(collection?.name ?? "collection")”?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete collection", role: .destructive) {
                container.collectionsRepository.delete(collectionId)
                router.pop()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            IconButton("chevron.left") { router.pop() }
            VStack(alignment: .leading, spacing: 0) {
                Text(collection?.name ?? "")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text("\(items.count) animation\(items.count == 1 ? "" : "s")")
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            IconButton("plus") { showPicker = true }
            IconButton("trash", tint: Theme.Palette.textSecondary) { confirmDelete = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nothing in this collection yet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            Button("Add animations") { showPicker = true }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.Palette.accent, in: Capsule())
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

// MARK: - Add picker

private struct CollectionPickerSheet: View {

    let collectionId: UUID

    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var memberIds: Set<String> = []

    /// Default suggestions lead with the hand-crafted flagship set in its
    /// curated order — the bespoke long tail's synthetic download counts
    /// would otherwise bury it. Search still spans the whole catalog.
    private var results: [AnimationItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty else { return container.animationRepository.search(trimmed) }

        let all = container.animationRepository.all()
        let handcraftedIds = AnimationCatalogSeed.handcrafted.map(\.id)
        let handcraftedSet = Set(handcraftedIds)
        let handcrafted = handcraftedIds.compactMap { id in all.first { $0.id == id } }
        let rest = all.filter { !handcraftedSet.contains($0.id) } // already popularity-sorted
        return handcrafted + Array(rest.prefix(max(0, 50 - handcrafted.count)))
    }

    var body: some View {
        NavigationStack {
            List(results) { item in
                Button {
                    if memberIds.contains(item.id) {
                        container.collectionsRepository.remove(item.id, from: collectionId)
                    } else {
                        container.collectionsRepository.add(item.id, to: collectionId)
                    }
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: item.tintHex))
                            .frame(width: 34, height: 34)
                            .overlay(
                                AnimationPreviewRegistry.view(for: item.id)
                                    .allowsHitTesting(false)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Text(item.category.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        if memberIds.contains(item.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Palette.accent)
                        }
                    }
                }
                .listRowBackground(Theme.Palette.background)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background)
            .searchable(text: $query, prompt: "Search animations")
            .navigationTitle("Add animations")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(container.collectionsRepository.collectionsPublisher) { collections in
            memberIds = Set(collections.first { $0.id == collectionId }?.animationIds ?? [])
        }
    }
}
