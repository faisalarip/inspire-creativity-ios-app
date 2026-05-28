//
//  FlowLayout.swift
//  InspireCreativityApp
//
//  Wrap-around horizontal layout for chips/tags.
//  iOS 16+ uses the native `Layout` protocol.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowMaxH: CGFloat = 0
        var totalH: CGFloat = 0
        var totalW: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if rowWidth + sz.width > maxWidth {
                totalH += rowMaxH + spacing
                totalW = max(totalW, rowWidth - spacing)
                rowWidth = sz.width + spacing
                rowMaxH = sz.height
            } else {
                rowWidth += sz.width + spacing
                rowMaxH = max(rowMaxH, sz.height)
            }
        }
        totalH += rowMaxH
        totalW = max(totalW, rowWidth - spacing)
        return CGSize(width: totalW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowMaxH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + sz.width > maxWidth {
                x = bounds.minX
                y += rowMaxH + spacing
                rowMaxH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowMaxH = max(rowMaxH, sz.height)
        }
    }
}
