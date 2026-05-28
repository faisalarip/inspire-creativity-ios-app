//
//  HexColor.swift
//  InspireCreativityApp
//

import SwiftUI

extension Color {
    /// Initialize a Color from a `#RRGGBB` or `RRGGBB` hex string.
    /// Falls back to `Theme.Palette.surface` on malformed input.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else {
            self = Theme.Palette.surface
            return
        }
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
