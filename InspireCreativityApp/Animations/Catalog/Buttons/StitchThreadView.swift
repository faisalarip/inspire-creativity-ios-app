// catalog-id: btn-stitch-thread
import SwiftUI

// MARK: - Stitch Thread Button
//
// Tapping animates a needle drawing thread stitch-by-stitch around the
// button's border, sewing a dashed seam that completes into a confirmed
// outline. The seam and the needle share ONE Path so they stay perfectly
// aligned: the needle rides `trimmedPath(...).currentPoint` — the exact
// leading edge of the revealed dashes — with no arc-length math.

struct StitchThreadView: View {
    var demo: Bool = false

    @State private var progress: CGFloat = 0
    @State private var didComplete: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                autoDrivenContent(size: geo.size)
            } else {
                interactiveContent(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving)

    private func autoDrivenContent(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = triangleWave(at: timeline.date, period: 3.4)
            // Ease the linear triangle wave for a more hand-sewn cadence.
            let eased = easeInOut(t)
            sewingStage(size: size, progress: eased, sewn: eased > 0.985)
        }
    }

    // MARK: Interactive (real component)

    private func interactiveContent(size: CGSize) -> some View {
        sewingStage(size: size, progress: progress, sewn: didComplete)
            .contentShape(Rectangle())
            .onTapGesture {
                if progress >= 0.999 {
                    // Tap again to unstitch and reset.
                    didComplete = false
                    withAnimation(.easeInOut(duration: 0.9)) { progress = 0 }
                } else {
                    withAnimation(.easeInOut(duration: 1.2)) { progress = 1 }
                    // Mark completion slightly after the seam closes so the
                    // success haptic + state land on the final stitch.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if progress >= 0.999 { didComplete = true }
                    }
                }
            }
            .sensoryFeedback(.success, trigger: didComplete) { _, now in now }
    }

    // MARK: Shared stage

    private func sewingStage(size: CGSize, progress: CGFloat, sewn: Bool) -> some View {
        let side = min(size.width, size.height)
        let pad = max(8, side * 0.12)
        let rect = CGRect(
            x: (size.width - (size.width - pad * 2)) / 2,
            y: (size.height - (size.height - pad * 2)) / 2,
            width: max(1, size.width - pad * 2),
            height: max(1, size.height - pad * 2)
        )
        let corner = min(rect.width, rect.height) * 0.30
        let line = max(2.0, side * 0.030)

        return ZStack {
            baseButton(rect: rect, corner: corner, sewn: sewn, side: side)
            guideOutline(rect: rect, corner: corner, line: line)
            seam(rect: rect, corner: corner, line: line, progress: progress)
            needleLayer(rect: rect, corner: corner, progress: progress, side: side)
            label(in: rect, sewn: sewn)
        }
    }

    // MARK: Base filled button

    private func baseButton(rect: CGRect, corner: CGFloat, sewn: Bool, side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return shape
            .fill(buttonFill(sewn: sewn))
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: Color.black.opacity(0.35), radius: side * 0.04, x: 0, y: side * 0.02)
            .animation(.easeInOut(duration: 0.5), value: sewn)
    }

    private func buttonFill(sewn: Bool) -> LinearGradient {
        // Warm fabric tone, deepening once the seam is sewn shut.
        let top: Color = sewn
            ? Color(red: 0.16, green: 0.13, blue: 0.10)
            : Color(red: 0.13, green: 0.11, blue: 0.09)
        let bottom: Color = sewn
            ? Color(red: 0.10, green: 0.08, blue: 0.06)
            : Color(red: 0.09, green: 0.075, blue: 0.06)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    // MARK: Faint "unsewn" guide so the tile is never blank

    private func guideOutline(rect: CGRect, corner: CGFloat, line: CGFloat) -> some View {
        StitchThreadView_SeamShape(cornerRadius: corner)
            .stroke(
                Color(red: 0.78, green: 0.70, blue: 0.55).opacity(0.18),
                style: StrokeStyle(lineWidth: max(1, line * 0.55), dash: [line * 1.4, line * 1.4])
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: The sewn dashed seam (the thread)

    private func seam(rect: CGRect, corner: CGFloat, line: CGFloat, progress: CGFloat) -> some View {
        let dash = line * 1.4
        let thread = Color(red: 0.95, green: 0.83, blue: 0.55)
        return ZStack {
            // Soft halo of the thread for depth.
            StitchThreadView_SeamShape(cornerRadius: corner)
                .trim(from: 0, to: progress)
                .stroke(
                    thread.opacity(0.35),
                    style: StrokeStyle(lineWidth: line * 1.9, lineCap: .round, dash: [dash, dash])
                )
                .blur(radius: line * 0.5)
            // The crisp stitch line.
            StitchThreadView_SeamShape(cornerRadius: corner)
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [thread, Color(red: 0.85, green: 0.66, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: line, lineCap: .butt, dash: [dash, dash])
                )
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    // MARK: Needle riding the leading edge of the seam

    private func needleLayer(rect: CGRect, corner: CGFloat, progress: CGFloat, side: CGFloat) -> some View {
        // Translate the seam path into the rect's coordinate space, then read
        // the EXACT endpoint of the revealed segment — identical geometry to
        // the dashed stroke above, so the needle can never drift.
        let localRect = CGRect(origin: .zero, size: rect.size)
        let basePath = seamPath(in: localRect, cornerRadius: corner)
        let tip = pointOnPath(basePath, at: progress) ?? CGPoint(x: localRect.midX, y: localRect.minY)
        let prior = pointOnPath(basePath, at: max(0, progress - 0.012)) ?? tip
        let angle = tangentAngle(from: prior, to: tip)
        let visible = progress > 0.002 && progress < 0.999

        return needle(side: side, angle: angle)
            .position(x: rect.minX + tip.x, y: rect.minY + tip.y)
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.18), value: visible)
    }

    private func needle(side: CGFloat, angle: Angle) -> some View {
        let len = side * 0.34
        let w = max(2.0, side * 0.030)
        return ZStack {
            // Trailing thread tail from the eye of the needle.
            Capsule()
                .fill(Color(red: 0.95, green: 0.83, blue: 0.55).opacity(0.9))
                .frame(width: len * 0.55, height: max(1, w * 0.35))
                .offset(x: -len * 0.55)
            StitchThreadView_NeedleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.93, blue: 0.96),
                            Color(red: 0.62, green: 0.64, blue: 0.70)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: len, height: w)
                .shadow(color: Color.black.opacity(0.35), radius: w * 0.4, x: 0, y: w * 0.2)
        }
        .rotationEffect(angle)
    }

    // MARK: Centered label

    private func label(in rect: CGRect, sewn: Bool) -> some View {
        let fontSize = min(rect.width, rect.height) * 0.20
        return Group {
            if sewn {
                HStack(spacing: fontSize * 0.3) {
                    Image(systemName: "checkmark")
                    Text("Sewn")
                }
            } else {
                Text("Confirm")
            }
        }
        .font(.system(size: max(9, fontSize), weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.96, green: 0.92, blue: 0.84))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(width: rect.width * 0.8)
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeInOut(duration: 0.4), value: sewn)
    }

    // MARK: Timing helpers

    private func triangleWave(at date: Date, period: Double) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        let phase = t / period            // 0 ..< 1
        let v = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return CGFloat(min(1, max(0, v)))
    }

    private func easeInOut(_ x: CGFloat) -> CGFloat {
        // Smoothstep — softens the linear triangle into a hand-sewn cadence.
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Seam geometry: ONE source of truth

/// Builds the perimeter as a rounded rectangle with a known start point
/// (top edge, just right of the top-left corner) winding clockwise, so the
/// dashed stroke and the needle endpoint are guaranteed to agree.
private func seamPath(in rect: CGRect, cornerRadius: CGFloat) -> Path {
    let r = min(cornerRadius, min(rect.width, rect.height) / 2)
    let minX = rect.minX, minY = rect.minY
    let maxX = rect.maxX, maxY = rect.maxY
    var p = Path()

    // Start at top edge after the top-left corner arc.
    p.move(to: CGPoint(x: minX + r, y: minY))
    // Top edge -> top-right corner.
    p.addLine(to: CGPoint(x: maxX - r, y: minY))
    p.addArc(center: CGPoint(x: maxX - r, y: minY + r), radius: r,
             startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
    // Right edge -> bottom-right corner.
    p.addLine(to: CGPoint(x: maxX, y: maxY - r))
    p.addArc(center: CGPoint(x: maxX - r, y: maxY - r), radius: r,
             startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
    // Bottom edge -> bottom-left corner.
    p.addLine(to: CGPoint(x: minX + r, y: maxY))
    p.addArc(center: CGPoint(x: minX + r, y: maxY - r), radius: r,
             startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
    // Left edge -> top-left corner.
    p.addLine(to: CGPoint(x: minX, y: minY + r))
    p.addArc(center: CGPoint(x: minX + r, y: minY + r), radius: r,
             startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
    p.closeSubpath()
    return p
}

/// Endpoint of the revealed segment of the seam at `progress` — the exact
/// leading edge of the dashes, used to anchor the needle.
private func pointOnPath(_ path: Path, at progress: CGFloat) -> CGPoint? {
    let p = min(1, max(0, progress))
    if p <= 0 { return nil }
    let trimmed = path.trimmedPath(from: 0, to: p)
    return trimmed.currentPoint
}

private func tangentAngle(from a: CGPoint, to b: CGPoint) -> Angle {
    let dx = b.x - a.x
    let dy = b.y - a.y
    if abs(dx) < 0.0001 && abs(dy) < 0.0001 { return .zero }
    return Angle(radians: atan2(Double(dy), Double(dx)))
}

// MARK: - Shapes

/// The seam shape — delegates to the shared `seamPath` so the trimmed stroke
/// matches the needle's anchor exactly.
private struct StitchThreadView_SeamShape: Shape {
    var cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        seamPath(in: rect, cornerRadius: cornerRadius)
    }
}

/// A simple sewing needle: a tapered body with an eye, drawn pointing right
/// (it is rotated to follow the seam tangent by the caller).
private struct StitchThreadView_NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let midY = rect.midY
        let tipX = rect.maxX
        let bluntX = rect.minX

        // Pointed tip on the right.
        p.move(to: CGPoint(x: tipX, y: midY))
        p.addLine(to: CGPoint(x: tipX - w * 0.18, y: midY - h * 0.5))
        p.addLine(to: CGPoint(x: bluntX + w * 0.10, y: midY - h * 0.32))
        // Rounded blunt (eye) end on the left.
        p.addQuadCurve(
            to: CGPoint(x: bluntX + w * 0.10, y: midY + h * 0.32),
            control: CGPoint(x: bluntX, y: midY)
        )
        p.addLine(to: CGPoint(x: tipX - w * 0.18, y: midY + h * 0.5))
        p.closeSubpath()
        return p
    }
}
