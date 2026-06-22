//
//  CodeSheet.swift
//  InspireCreativityApp
//
//  Drag-up code viewer with 3 snap states (peek / half / full).
//

import SwiftUI
import UIKit

struct CodeSheet: View {

    @Binding var state: DetailView.SheetState
    @Binding var dragOffset: CGFloat
    let height: CGFloat
    /// Total height of the detail container, used for snap-point math so it's
    /// correct on iPad / split-screen (not the full physical screen).
    let containerHeight: CGFloat
    let fileName: String
    let source: String
    let locked: Bool
    /// Headline shown over the blurred code when locked (differs for the
    /// sign-in gate vs the Pro gate).
    var lockTitle: String = "Preview is limited"
    /// Label for the unlock button in the locked overlay.
    var lockCTA: String = "Unlock to view full code"
    let onUnlock: () -> Void
    /// Fired when the user copies the (unlocked) code. Lets the owning view
    /// log analytics without this leaf knowing about the tracker or the item id.
    var onCopy: () -> Void = {}

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            ScrollView {
                SwiftCodeView(source: source)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                    .blur(radius: locked ? 3 : 0)
                    .allowsHitTesting(!locked)
            }
            .overlay {
                if locked {
                    ZStack {
                        // Dim the blurred code further so the unlock CTA is the focus.
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.09).opacity(0.4),
                                Color(red: 0.05, green: 0.07, blue: 0.09).opacity(0.85)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        VStack {
                            Spacer()
                            lockedOverlay
                        }
                    }
                    .allowsHitTesting(true)
                }
            }
        }
        .frame(height: height, alignment: .top)
        .background(Color(red: 0.05, green: 0.07, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: -8)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    dragOffset = -value.translation.height
                }
                .onEnded { value in
                    snap(translation: value.translation.height,
                         velocity: value.predictedEndTranslation.height)
                }
        )
        .onTapGesture {
            // Tap anywhere on the bar expands one step (easy alternative to dragging).
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                state = stepUp(from: state)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state)
    }

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            // Enlarge the touch target well beyond the thin pill so it's easy
            // to grab and drag up.
            .contentShape(Rectangle())
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Text(fileName)
                    .font(Theme.Typo.mono(12))
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(source.split(separator: "\n").count) lines")
                    .font(Theme.Typo.mono(10.5))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
            copyButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            if state != .peek {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private var copyButton: some View {
        Button {
            if locked { onUnlock() }
            else { copy() }
        } label: {
            HStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text("Locked")
                } else if copied {
                    Image(systemName: "checkmark").font(.system(size: 10))
                    Text("Copied")
                } else {
                    Image(systemName: "doc.on.doc").font(.system(size: 10))
                    Text("Copy Code")
                }
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(locked ? .white.opacity(0.65) :
                             copied ? Theme.Palette.success : .white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                locked ? Color.white.opacity(0.08) :
                copied ? Theme.Palette.success.opacity(0.18) :
                Theme.Palette.accent,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func copy() {
        UIPasteboard.general.string = source
        onCopy()
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copied = false
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 8) {
            Text(lockTitle)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
            Button(action: onUnlock) {
                Text(lockCTA)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.bottom, 24)
    }

    private static let order: [DetailView.SheetState] = [.peek, .half, .full]

    private func stepUp(from s: DetailView.SheetState) -> DetailView.SheetState {
        let i = Self.order.firstIndex(of: s) ?? 0
        return Self.order[min(i + 1, Self.order.count - 1)]
    }

    private func stepDown(from s: DetailView.SheetState) -> DetailView.SheetState {
        let i = Self.order.firstIndex(of: s) ?? 0
        return Self.order[max(i - 1, 0)]
    }

    /// Direction-aware snapping: any upward drag/flick expands one step, any
    /// downward one collapses one step. Combining translation with the
    /// velocity-projected end makes even a short swipe register reliably —
    /// far easier than snapping to the nearest absolute height.
    private func snap(translation: CGFloat, velocity: CGFloat) {
        let threshold: CGFloat = 24
        let intent = (translation + velocity) / 2   // negative = upward
        var target = state
        if intent < -threshold {
            target = stepUp(from: state)
        } else if intent > threshold {
            target = stepDown(from: state)
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            state = target
            dragOffset = 0
        }
    }
}
