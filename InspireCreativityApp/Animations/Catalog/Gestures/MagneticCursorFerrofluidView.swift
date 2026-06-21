// catalog-id: ges-magnetic-cursor-ferrofluid
import SwiftUI

// MARK: - Ferrofluid Magnet Pull
// Drag a magnet over a pool of dark fluid: spiky tendrils rise and lean toward it,
// merging and splitting via a metaball (alphaThreshold + blur) Canvas, slumping flat
// when the magnet leaves. demo == true self-drives a slow figure-eight.

public struct MagneticCursorFerrofluidView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            FerrofluidStage(demo: demo, size: geo.size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stage

private struct FerrofluidStage: View {
    let demo: Bool
    let size: CGSize

    // Interactive state: where the magnet currently is (in points), whether it is engaged,
    // and the reference time used for the closed-form springy slump after release.
    @State private var dragPoint: CGPoint? = nil
    @State private var lastPoint: CGPoint = .zero
    @State private var releaseTime: Double? = nil
    @State private var engagedSince: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let resolved = resolveMagnet(now: now)
            ZStack {
                background
                fluidCanvas(magnet: resolved.point,
                            strength: resolved.strength)
                magnetIndicator(at: resolved.point,
                                strength: resolved.strength)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(now: now))
        }
        .clipped()
    }

    // MARK: Layers

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.08, blue: 0.13),
                Color(red: 0.03, green: 0.03, blue: 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func fluidCanvas(magnet: CGPoint, strength: Double) -> some View {
        let unit = min(size.width, size.height)
        let blur = max(unit * 0.045, 2.0)
        let threshold = 0.55
        let fluid = Color(red: 0.10, green: 0.11, blue: 0.20)

        return Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: threshold, color: fluid))
            context.addFilter(.blur(radius: blur))
            context.drawLayer { layer in
                let blobs = buildBlobs(magnet: magnet, strength: strength, unit: unit)
                for blob in blobs {
                    let rect = CGRect(
                        x: blob.center.x - blob.radius,
                        y: blob.center.y - blob.radius,
                        width: blob.radius * 2,
                        height: blob.radius * 2
                    )
                    layer.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        // A subtle sheen highlight overlaid via blend so the fluid reads metallic.
        .overlay(sheenOverlay(unit: unit))
    }

    private func sheenOverlay(unit: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.50, blue: 0.75).opacity(0.0),
                Color(red: 0.55, green: 0.62, blue: 0.90).opacity(0.18),
                Color(red: 0.10, green: 0.12, blue: 0.22).opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .mask(
            Rectangle()
                .frame(height: unit * 0.55)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    private func magnetIndicator(at point: CGPoint, strength: Double) -> some View {
        let unit = min(size.width, size.height)
        let r = unit * 0.085
        let glow = 0.25 + 0.55 * strength
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.55, blue: 0.35).opacity(glow),
                            Color(red: 0.85, green: 0.30, blue: 0.25).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: r * 2.4
                    )
                )
                .frame(width: r * 4, height: r * 4)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.72, blue: 0.45),
                            Color(red: 0.80, green: 0.28, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: r * 1.5, height: r * 1.5)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: max(unit * 0.006, 0.6))
                )
                .shadow(color: .black.opacity(0.4), radius: r * 0.3, y: r * 0.15)
        }
        .position(point)
        .allowsHitTesting(false)
    }

    // MARK: Blob field

    private struct Blob {
        var center: CGPoint
        var radius: CGFloat
    }

    /// Builds the base pool slab plus a row of spikes leaning toward the magnet.
    private func buildBlobs(magnet: CGPoint, strength: Double, unit: CGFloat) -> [Blob] {
        var blobs: [Blob] = []
        let w = size.width
        let h = size.height
        guard w > 1, h > 1 else { return blobs }

        // Base pool: a thick row of overlapping circles along the bottom so the
        // metaball never disappears — guarantees a legible state on every frame.
        let baseY = h * 0.82
        let baseRadius = unit * 0.16
        let baseCount = max(Int((w / (baseRadius * 0.9)).rounded(.up)) + 1, 3)
        for i in 0..<baseCount {
            let frac = baseCount > 1 ? CGFloat(i) / CGFloat(baseCount - 1) : 0.5
            let x = frac * w
            blobs.append(Blob(center: CGPoint(x: x, y: baseY), radius: baseRadius))
        }

        // Spikes: evenly spaced anchors rising from the pool surface.
        let spikeCount = 11
        let surfaceY = baseY - baseRadius * 0.35
        let maxSpike = h * 0.62
        let reach = unit * 1.05

        for i in 0..<spikeCount {
            let frac = CGFloat(i) / CGFloat(spikeCount - 1)
            let anchorX = w * (0.06 + 0.88 * frac)
            let anchor = CGPoint(x: anchorX, y: surfaceY)

            let d = distance(anchor, magnet)
            let falloff = falloffCurve(distance: d, reach: reach)
            let rise = maxSpike * falloff * CGFloat(strength)

            guard rise > unit * 0.02 else { continue }

            // Lean the tip toward the magnet, proportional to height.
            let dirX = magnet.x - anchorX
            let lean = clamp(dirX, -reach, reach) / reach
            let tipLean = lean * rise * 0.55

            // Stack shrinking circles from base to tip.
            let segments = 6
            for s in 0..<segments {
                let t = CGFloat(s) / CGFloat(segments - 1)
                let y = surfaceY - rise * t
                let x = anchorX + tipLean * t * t
                // Radius tapers from fat base to thin tip.
                let baseR = unit * 0.085
                let tipR = unit * 0.018
                let radius = baseR + (tipR - baseR) * t
                blobs.append(Blob(center: CGPoint(x: x, y: y), radius: radius))
            }
        }

        return blobs
    }

    /// Smooth falloff in [0,1]: full strength at the magnet, fading to 0 past `reach`.
    private func falloffCurve(distance: CGFloat, reach: CGFloat) -> CGFloat {
        guard reach > 0 else { return 0 }
        let x = clamp(distance / reach, 0, 1)
        // Smoothstep-ish: emphasizes a sharp local pull.
        let v = 1 - x
        return v * v
    }

    // MARK: Magnet resolution (closed-form so Canvas slump is smooth)

    private struct ResolvedMagnet {
        var point: CGPoint
        var strength: Double
    }

    private func resolveMagnet(now: Double) -> ResolvedMagnet {
        if demo {
            return demoMagnet(now: now)
        }

        if let p = dragPoint {
            // Actively dragging: full strength, smoothly ramping up after engage.
            let t = now - engagedSince
            let s = 1 - exp(-t / 0.18)
            return ResolvedMagnet(point: p, strength: min(1.0, 0.2 + 0.8 * s))
        }

        if let rel = releaseTime {
            // Released: spring-decaying field strength (damped oscillation 1 -> 0).
            let t = now - rel
            let strength = dampedRelease(t)
            return ResolvedMagnet(point: lastPoint, strength: max(0, strength))
        }

        // Idle, untouched: park the magnet just off-pool so a gentle base wobble shows.
        let idle = CGPoint(x: size.width * 0.5, y: size.height * 0.32)
        let pulse = 0.12 + 0.05 * (1 + sin(now * 1.4)) / 2
        return ResolvedMagnet(point: idle, strength: pulse)
    }

    /// Damped spring envelope: starts near 1, overshoots toward 0, settles flat.
    private func dampedRelease(_ t: Double) -> Double {
        guard t >= 0 else { return 1 }
        let decay = exp(-t * 3.2)
        let osc = cos(t * 7.0)
        // Keep it positive-ish but let it wobble as it slumps.
        let env = decay * (0.5 + 0.5 * osc)
        return env
    }

    /// demo mode: slow figure-eight (lemniscate) over the pool surface.
    private func demoMagnet(now: Double) -> ResolvedMagnet {
        let period: Double = 3.4
        let phase = (now.truncatingRemainder(dividingBy: period)) / period
        let theta = phase * 2 * .pi

        // Lemniscate of Gerono: x = sin, y = sin*cos — stays inside bounds when scaled.
        let nx = sin(theta)
        let ny = sin(theta) * cos(theta)

        let cx = size.width * 0.5
        let cy = size.height * 0.40
        let ampX = size.width * 0.34
        let ampY = size.height * 0.22

        let point = CGPoint(x: cx + CGFloat(nx) * ampX,
                            y: cy + CGFloat(ny) * ampY)
        // Pulse strength a little so the fluid breathes; never below a legible floor.
        let strength = 0.78 + 0.22 * (1 + sin(now * 2.1)) / 2
        return ResolvedMagnet(point: point, strength: strength)
    }

    // MARK: Gesture

    private func dragGesture(now: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragPoint == nil {
                    engagedSince = Date().timeIntervalSinceReferenceDate
                }
                dragPoint = value.location
                lastPoint = value.location
                releaseTime = nil
            }
            .onEnded { value in
                lastPoint = value.location
                dragPoint = nil
                releaseTime = Date().timeIntervalSinceReferenceDate
            }
    }

    // MARK: Math helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}
