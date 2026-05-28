//
//  LiveParametersPanel.swift
//  InspireCreativityApp
//
//  Slider panel for live-tweaking spring/scale params. Visual only.
//

import SwiftUI

struct LiveParametersPanel: View {

    @Binding var response: Double
    @Binding var damping: Double
    @Binding var scale: Double
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live parameters", systemImage: "wave.3.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Reset", action: onReset)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .buttonStyle(.plain)
            }
            Slider(name: "response", value: $response, range: 0.1...1.0, suffix: "s")
            Slider(name: "dampingFraction", value: $damping, range: 0.2...1.0, suffix: "")
            Slider(name: "scaleEffect", value: $scale, range: 0.5...1.5, suffix: "×")
        }
        .padding(14)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private struct Slider: View {
        let name: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        let suffix: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(Theme.Typo.mono(11.5))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text(String(format: "%.2f%@", value, suffix))
                        .font(Theme.Typo.mono(11.5, weight: .semibold))
                        .foregroundStyle(Theme.Palette.accent)
                }
                SwiftUI.Slider(value: $value, in: range)
                    .tint(Theme.Palette.accent)
            }
        }
    }
}
