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
    let onUnlock: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            if state != .peek {
                ScrollView {
                    SwiftCodeView(source: source)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .padding(.bottom, 32)
                        .blur(radius: locked ? 8 : 0)
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
            } else {
                Spacer(minLength: 0)
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
            DragGesture()
                .onChanged { value in
                    dragOffset = -value.translation.height
                }
                .onEnded { _ in
                    snap()
                }
        )
        .onTapGesture {
            if state == .peek {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    state = .half
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state)
    }

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
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
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copied = false
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 8) {
            Text("Preview is limited")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
            Button(action: onUnlock) {
                Text("Unlock to view full code")
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

    private func snap() {
        let candidates: [DetailView.SheetState] = [.peek, .half, .full]
        // Pick nearest snap point based on current height
        let best = candidates.min(by: { a, b in
            abs(a.height(in: containerHeight) - height) <
            abs(b.height(in: containerHeight) - height)
        }) ?? .peek
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            state = best
            dragOffset = 0
        }
    }
}
