//
//  RatingView.swift
//  InspireCreativityApp
//

import SwiftUI

struct RatingView: View {
    let value: Double
    let count: Int?
    let size: CGFloat

    init(value: Double, count: Int? = nil, size: CGFloat = 11) {
        self.value = value
        self.count = count
        self.size = size
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Theme.Palette.proGoldStart)
            Text(String(format: "%.1f", value))
                .font(.system(size: size + 1, weight: .semibold))
                .foregroundStyle(.white)
            if let count {
                Text("(\(count.formatted()))")
                    .font(.system(size: size + 1))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
