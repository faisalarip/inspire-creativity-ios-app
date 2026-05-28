//
//  Avatar.swift
//  InspireCreativityApp
//

import SwiftUI

/// Initials-based avatar with a deterministic gradient color per name.
struct Avatar: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat = 28) {
        self.name = name
        self.size = size
    }

    var body: some View {
        let initials = computeInitials(name)
        let hue = stableHue(for: name)
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.70, brightness: 0.55),
                        Color(hue: (hue + 30 / 360).truncatingRemainder(dividingBy: 1),
                              saturation: 0.65, brightness: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }

    private func computeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    private func stableHue(for name: String) -> Double {
        let hues: [Double] = [12, 280, 200, 160, 40, 320]
        let idx = name.count % hues.count
        return hues[idx] / 360.0
    }
}
