// catalog-id: ges-pinch-origami-crane
import SwiftUI

// MARK: - Public View

/// Pinch a flat square and it folds along crease lines through intermediate
/// origami states into a standing crane, each facet catching directional light.
/// Pinch (magnification < 1) folds toward the crane; spread unfolds it.
/// All APIs used are iOS 17+: MagnifyGesture, TimelineView, rotation3DEffect,
/// and a manual keyframed vertex lerp on an Animatable Shape.
struct PinchOrigamiCraneView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                background
                if demo {
                    DemoFoldStage(side: side)
                } else {
                    InteractiveFoldStage(side: side)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.09),
                Color(red: 0.10, green: 0.11, blue: 0.17)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Demo (self-driving loop)

private struct DemoFoldStage: View {
    let side: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let progress = triangleWave(t)
            CraneFigure(progress: progress, side: side)
        }
    }

    /// 0 -> 1 -> 0 triangle wave on a ~3.4s loop. Never rests at a blank state:
    /// both endpoints are legible (flat square / standing crane).
    private func triangleWave(_ t: TimeInterval) -> CGFloat {
        let period: Double = 3.4
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        let raw = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0
        // ease in/out so the dwell at flat / crane reads as a held pose
        let eased = raw * raw * (3.0 - 2.0 * raw)
        return CGFloat(eased)
    }
}

// MARK: - Interactive (real pinch)

private struct InteractiveFoldStage: View {
    let side: CGFloat

    @State private var committedFold: CGFloat = 0.0
    @State private var liveFold: CGFloat = 0.0

    var body: some View {
        CraneFigure(progress: liveFold, side: side)
            .gesture(pinch)
            .accessibilityLabel("Origami crane. Pinch to fold, spread to unfold.")
    }

    private var pinch: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.0)
            .onChanged { value in
                // pinch closed (magnification < 1) folds toward crane.
                let delta = (1.0 - CGFloat(value.magnification)) * 1.4
                liveFold = clamp(committedFold + delta)
            }
            .onEnded { _ in
                let snapped = nearestKeyframe(liveFold)
                committedFold = snapped
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                    liveFold = snapped
                }
            }
    }

    private func clamp(_ v: CGFloat) -> CGFloat {
        min(1.0, max(0.0, v))
    }

    /// Snap to one of the three keyframe poses: flat, kite base, crane.
    private func nearestKeyframe(_ v: CGFloat) -> CGFloat {
        let stops: [CGFloat] = [0.0, 0.5, 1.0]
        var best: CGFloat = 0.0
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for s in stops {
            let d = abs(s - v)
            if d < bestDist {
                bestDist = d
                best = s
            }
        }
        return best
    }
}

// MARK: - Crane figure (composes all facets)

private struct CraneFigure: View {
    let progress: CGFloat
    let side: CGFloat

    var body: some View {
        ZStack {
            ground
            ForEach(CraneFacet.all) { facet in
                FacetView(facet: facet, progress: progress, side: side)
            }
        }
        .frame(width: side, height: side)
        // gentle settle so the standing crane feels alive at full fold
        .rotation3DEffect(
            .degrees(Double(progress) * 8.0),
            axis: (x: 1.0, y: 0.0, z: 0.0),
            perspective: 0.6
        )
    }

    /// Soft contact shadow that tightens as the crane stands up.
    private var ground: some View {
        let w = side * (0.62 - 0.18 * progress)
        let h = side * 0.10
        return Ellipse()
            .fill(Color.black.opacity(0.32))
            .frame(width: w, height: h)
            .blur(radius: 9)
            .offset(y: side * 0.34)
            .opacity(0.55 + 0.3 * Double(progress))
    }
}

// MARK: - Single facet rendering

private struct FacetView: View {
    let facet: CraneFacet
    let progress: CGFloat
    let side: CGFloat

    var body: some View {
        FacetShape(facet: facet, progress: progress, side: side)
            .fill(gradient)
            .overlay(creaseStroke)
            .rotation3DEffect(
                .degrees(tiltAngle),
                axis: facet.axis,
                anchor: .center,
                perspective: 0.5
            )
            .compositingGroup()
    }

    // Crease lines on the paper edges sell the fold geometry.
    private var creaseStroke: some View {
        FacetShape(facet: facet, progress: progress, side: side)
            .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
    }

    /// Directional light: brightness keys off the facet's fold tilt so each
    /// plane catches the light differently as it rotates.
    private var gradient: LinearGradient {
        let lit = facet.brightness(progress: progress)
        let base = facet.tone
        let top = shade(base, by: 0.55 + 0.45 * lit)
        let bottom = shade(base, by: 0.30 + 0.35 * lit)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tiltAngle: Double {
        // facets lean out of plane as the fold completes
        Double(progress) * facet.maxTilt
    }

    private func shade(_ c: PaperTone, by k: CGFloat) -> Color {
        let f = min(1.0, max(0.0, k))
        return Color(red: c.r * f, green: c.g * f, blue: c.b * f)
    }
}

// MARK: - Animatable Shape (vertex lerp lives here for spring morphing)

private struct FacetShape: Shape {
    let facet: CraneFacet
    var progress: CGFloat
    let side: CGFloat

    // Lets the onEnded .spring actually interpolate the path, not snap it.
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let pts = facet.vertices(progress: progress)
        var path = Path()
        guard let first = pts.first else { return path }
        let s: CGFloat = side
        let cx: CGFloat = rect.midX
        let cy: CGFloat = rect.midY
        path.move(to: project(first, s: s, cx: cx, cy: cy))
        for i in 1..<pts.count {
            path.addLine(to: project(pts[i], s: s, cx: cx, cy: cy))
        }
        path.closeSubpath()
        return path
    }

    /// Map a normalized point in [-0.5, 0.5] space to view coordinates.
    private func project(_ p: CGPoint, s: CGFloat, cx: CGFloat, cy: CGFloat) -> CGPoint {
        let x: CGFloat = cx + p.x * s
        let y: CGFloat = cy + p.y * s
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Paper tone

private struct PaperTone {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
}

// MARK: - Facet model (keyframed vertex sets + lighting key)

private struct CraneFacet: Identifiable {
    let id: Int
    /// Three keyframe poses in normalized [-0.5, 0.5] space:
    /// 0 = flat square region, 1 = kite/diamond base, 2 = standing crane.
    let flat: [CGPoint]
    let base: [CGPoint]
    let crane: [CGPoint]
    let tone: PaperTone
    let maxTilt: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    /// Phase of the fold lighting sweep so facets brighten at different times.
    let litPhase: CGFloat

    /// Piecewise lerp: flat -> base over [0, 0.5], base -> crane over [0.5, 1].
    func vertices(progress: CGFloat) -> [CGPoint] {
        if progress <= 0.5 {
            let t = progress / 0.5
            return lerp(flat, base, smooth(t))
        } else {
            let t = (progress - 0.5) / 0.5
            return lerp(base, crane, smooth(t))
        }
    }

    func brightness(progress: CGFloat) -> CGFloat {
        // a moving highlight band that travels across facets during the fold
        let center = progress
        let d = abs(litPhase - center)
        let lit = max(0.0, 1.0 - d * 1.8)
        return 0.35 + 0.65 * lit
    }

    private func smooth(_ t: CGFloat) -> CGFloat {
        let c = min(1.0, max(0.0, t))
        return c * c * (3.0 - 2.0 * c)
    }

    private func lerp(_ a: [CGPoint], _ b: [CGPoint], _ t: CGFloat) -> [CGPoint] {
        let n = min(a.count, b.count)
        var out: [CGPoint] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let x: CGFloat = a[i].x + (b[i].x - a[i].x) * t
            let y: CGFloat = a[i].y + (b[i].y - a[i].y) * t
            out.append(CGPoint(x: x, y: y))
        }
        return out
    }
}

// MARK: - Facet keyframe data

private extension CraneFacet {
    /// Bounded set of facets (8) forming a bird-like silhouette: body, two
    /// wings, neck, head, tail. Each carries flat / kite-base / crane poses.
    static let all: [CraneFacet] = [
        // 0 — left body panel
        CraneFacet(
            id: 0,
            flat:  [p(-0.40, -0.40), p(0.0, -0.40), p(0.0, 0.40), p(-0.40, 0.40)],
            base:  [p(-0.30, -0.05), p(0.0, -0.22), p(0.0, 0.30), p(-0.22, 0.20)],
            crane: [p(-0.18, -0.02), p(0.0, -0.10), p(0.0, 0.28), p(-0.20, 0.20)],
            tone:  PaperTone(r: 0.93, g: 0.42, b: 0.38),
            maxTilt: -14.0,
            axis: (x: 0.0, y: 1.0, z: 0.0),
            litPhase: 0.20
        ),
        // 1 — right body panel
        CraneFacet(
            id: 1,
            flat:  [p(0.0, -0.40), p(0.40, -0.40), p(0.40, 0.40), p(0.0, 0.40)],
            base:  [p(0.0, -0.22), p(0.30, -0.05), p(0.22, 0.20), p(0.0, 0.30)],
            crane: [p(0.0, -0.10), p(0.18, -0.02), p(0.20, 0.20), p(0.0, 0.28)],
            tone:  PaperTone(r: 0.97, g: 0.55, b: 0.46),
            maxTilt: 14.0,
            axis: (x: 0.0, y: 1.0, z: 0.0),
            litPhase: 0.35
        ),
        // 2 — left wing
        CraneFacet(
            id: 2,
            flat:  [p(-0.40, -0.18), p(-0.05, -0.06), p(-0.10, 0.18)],
            base:  [p(-0.46, -0.30), p(-0.04, -0.10), p(-0.18, 0.10)],
            crane: [p(-0.50, -0.40), p(-0.02, -0.06), p(-0.16, 0.08)],
            tone:  PaperTone(r: 0.99, g: 0.78, b: 0.50),
            maxTilt: -34.0,
            axis: (x: 0.30, y: 1.0, z: 0.0),
            litPhase: 0.62
        ),
        // 3 — right wing
        CraneFacet(
            id: 3,
            flat:  [p(0.40, -0.18), p(0.05, -0.06), p(0.10, 0.18)],
            base:  [p(0.46, -0.30), p(0.04, -0.10), p(0.18, 0.10)],
            crane: [p(0.50, -0.40), p(0.02, -0.06), p(0.16, 0.08)],
            tone:  PaperTone(r: 0.99, g: 0.84, b: 0.58),
            maxTilt: 34.0,
            axis: (x: 0.30, y: 1.0, z: 0.0),
            litPhase: 0.74
        ),
        // 4 — neck
        CraneFacet(
            id: 4,
            flat:  [p(-0.06, -0.30), p(0.06, -0.30), p(0.04, 0.02), p(-0.04, 0.02)],
            base:  [p(-0.05, -0.40), p(0.03, -0.40), p(0.06, -0.04), p(-0.02, -0.02)],
            crane: [p(-0.04, -0.50), p(0.04, -0.52), p(0.08, -0.10), p(0.0, -0.06)],
            tone:  PaperTone(r: 0.90, g: 0.36, b: 0.34),
            maxTilt: 18.0,
            axis: (x: 1.0, y: 0.2, z: 0.0),
            litPhase: 0.85
        ),
        // 5 — head / beak
        CraneFacet(
            id: 5,
            flat:  [p(-0.05, -0.40), p(0.05, -0.40), p(0.0, -0.30)],
            base:  [p(-0.04, -0.46), p(0.06, -0.42), p(0.02, -0.36)],
            crane: [p(-0.02, -0.56), p(0.14, -0.50), p(0.04, -0.46)],
            tone:  PaperTone(r: 0.86, g: 0.30, b: 0.30),
            maxTilt: 22.0,
            axis: (x: 1.0, y: 0.4, z: 0.0),
            litPhase: 0.95
        ),
        // 6 — tail
        CraneFacet(
            id: 6,
            flat:  [p(-0.04, 0.30), p(0.04, 0.30), p(0.0, 0.42)],
            base:  [p(-0.06, 0.30), p(0.06, 0.30), p(0.16, 0.46)],
            crane: [p(-0.06, 0.24), p(0.06, 0.24), p(0.34, 0.40)],
            tone:  PaperTone(r: 0.95, g: 0.50, b: 0.42),
            maxTilt: -20.0,
            axis: (x: 1.0, y: 0.3, z: 0.0),
            litPhase: 0.50
        ),
        // 7 — center crease highlight panel (keeps figure cohesive when flat)
        CraneFacet(
            id: 7,
            flat:  [p(-0.40, -0.40), p(0.40, -0.40), p(0.0, 0.0)],
            base:  [p(-0.30, -0.18), p(0.30, -0.18), p(0.0, 0.06)],
            crane: [p(-0.16, -0.08), p(0.16, -0.08), p(0.0, 0.10)],
            tone:  PaperTone(r: 0.99, g: 0.66, b: 0.50),
            maxTilt: 8.0,
            axis: (x: 1.0, y: 0.0, z: 0.0),
            litPhase: 0.10
        )
    ]

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }
}
