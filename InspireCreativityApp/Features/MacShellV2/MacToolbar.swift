//
//  MacToolbar.swift
//  InspireCreativityApp
//
//  52-pt top toolbar for the macOS redesigned shell (MacShellV2).
//  Brand mark · centered search field · profile button.
//  Reserves a ~76pt left inset for the real macOS traffic lights
//  (window uses .hiddenTitleBar — we never draw fake dots).
//  Matches the `MacToolbar` component in the Claude Design macos-app.jsx.
//  macOS-only — wrapped in #if os(macOS).
//

#if os(macOS)
import SwiftUI

// MARK: - MacMark

/// Three accent diamonds staggered diagonally up-right with increasing opacity,
/// matching the `MacMark` brand component in the Claude Design reference.
struct MacMark: View {
    var size: CGFloat = 20

    var body: some View {
        let unit = size / 3.4
        let cr = unit * 0.28
        ZStack(alignment: .topLeading) {
            // Diamond A — bottom-left, lowest opacity
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(Theme.Palette.accent)
                .frame(width: unit, height: unit)
                .rotationEffect(.degrees(45))
                .offset(x: 0, y: size * 0.32)
                .opacity(0.45)

            // Diamond B — middle
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(Theme.Palette.accent)
                .frame(width: unit, height: unit)
                .rotationEffect(.degrees(45))
                .offset(x: size * 0.28, y: size * 0.16)
                .opacity(0.72)

            // Diamond C — top-right, full opacity
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(Theme.Palette.accent)
                .frame(width: unit, height: unit)
                .rotationEffect(.degrees(45))
                .offset(x: size * 0.56, y: 0)
                .opacity(1.0)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - MacToolbar

struct MacToolbar: View {

    @Binding var query: String
    let onProfile: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: traffic-light inset + brand ─────────────────────────
            // The real macOS window controls sit in this region (hidden title
            // bar), so reserve ~76pt before drawing the brand.
            brand
                .padding(.leading, 76)

            Spacer(minLength: 16)

            // ── Center: search field ──────────────────────────────────────
            searchField
                .frame(width: 320)

            Spacer(minLength: 16)

            // ── Right: profile button ─────────────────────────────────────
            profileButton
                .padding(.trailing, 18)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            Color(hex: "#101013").opacity(0.6)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    // MARK: - Brand

    private var brand: some View {
        HStack(spacing: 8) {
            // Three-diamond cascade brand mark.
            MacMark(size: 20)
            HStack(spacing: 0) {
                Text("Inspire")
                    .foregroundStyle(.white)
                Text("Creativity")
                    .foregroundStyle(Theme.Palette.accent)
            }
            .font(.system(size: 15, weight: .heavy))
            .tracking(-0.3)
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))

            TextField("", text: $query, prompt: searchPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($searchFocused)

            if query.isEmpty {
                Text("⌘K")
                    .font(Theme.Typo.mono(11))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            } else {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    searchFocused ? Theme.Palette.accent.opacity(0.6) : Color.white.opacity(0.08),
                    lineWidth: searchFocused ? 1 : 0.5
                )
        )
    }

    private var searchPrompt: Text {
        Text("Search animations, authors, themes…")
            .foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Profile button

    private var profileButton: some View {
        Button(action: onProfile) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.accent, Color(hex: "#FB7185")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("YO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .help("Account & Settings")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var query = ""
    return MacToolbar(query: $query, onProfile: {})
        .frame(width: 1100)
        .background(Color(hex: "#0a0a0c"))
}
#endif
