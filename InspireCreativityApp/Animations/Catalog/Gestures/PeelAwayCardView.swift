// catalog-id: ges-peel-away-card
import SwiftUI
import Foundation

// MARK: - Peel-Away Sticker
//
// Drag the bottom-right corner of the card and it peels up like a sticker:
// a curling, lit underside is revealed, a soft drop shadow trails the lifted
// edge, and the corner snaps flat or tears free depending on release velocity.
//
// Implementation: a pure 2D reflection-fold rendered in a single Canvas.
// Folding corner `c` so it lands at lifted point `c'` means the crease is the
// perpendicular bisector of the segment c -> c'. The lifted flap is the mirror
// of the corner triangle across that crease; the "3D curl" is sold by a
// LinearGradient sheen, brightest at the bend. Renders identically at any size.

public struct PeelAwayCardView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            let box = cardRect(in: geo.size)
            if demo {
                demoCanvas(box: box)
            } else {
                interactiveCanvas(box: box)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Demo (self-driving) branch

    @ViewBuilder
    private func demoCanvas(box: CGRect) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = demoProgress(at: t)
            let lifted = demoLiftedPoint(box: box, progress: progress)
            peelCanvas(box: box, lifted: lifted, flapOpacity: 1.0)
        }
    }

    /// Eases peel progress 0 -> 0.6 -> 0 on a ~3.2s loop. Never reaches a blank
    /// state: progress 0 is simply the flat, fully-legible card.
    private func demoProgress(at time: TimeInterval) -> CGFloat {
        let period: Double = 3.2
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0..1
        // Smooth up-and-down: half a sine so it dwells gently at both ends.
        let wave = sin(phase * .pi) // 0 -> 1 -> 0
        let eased = wave * wave * (3.0 - 2.0 * wave) // smoothstep for softer ease
        return CGFloat(eased) * 0.6
    }

    private func demoLiftedPoint(box: CGRect, progress: CGFloat) -> CGPoint {
        let corner = CGPoint(x: box.maxX, y: box.maxY)
        // Lift along the diagonal toward the card's top-left.
        let diag = CGPoint(x: box.minX - corner.x, y: box.minY - corner.y)
        let liftFraction = progress // up to 0.6 of the way across
        return CGPoint(x: corner.x + diag.x * liftFraction,
                       y: corner.y + diag.y * liftFraction)
    }

    // MARK: Interactive branch

    @ViewBuilder
    private func interactiveCanvas(box: CGRect) -> some View {
        InteractivePeel(box: box, drawFlat: { ctx, size in
            drawFlatCard(in: &ctx, box: box)
        }, drawPeel: { ctx, size, lifted, opacity in
            drawPeel(in: &ctx, size: size, box: box, lifted: lifted, flapOpacity: opacity)
        })
    }

    // MARK: Shared canvas wrapper

    @ViewBuilder
    private func peelCanvas(box: CGRect, lifted: CGPoint, flapOpacity: Double) -> some View {
        Canvas { ctx, size in
            drawPeel(in: &ctx, size: size, box: box, lifted: lifted, flapOpacity: flapOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Interactive container

private struct InteractivePeel: View {
    let box: CGRect
    let drawFlat: (inout GraphicsContext, CGSize) -> Void
    let drawPeel: (inout GraphicsContext, CGSize, CGPoint, Double) -> Void

    /// Current lifted-corner location (the destination of the folded corner).
    @State private var lifted: CGPoint?
    @State private var flapOpacity: Double = 1.0
    @State private var torn: Bool = false

    var body: some View {
        Canvas { ctx, size in
            if let lifted, !torn {
                drawPeel(&ctx, size, lifted, flapOpacity)
            } else if torn {
                // Briefly empty while torn free; restored shortly after.
                ctx.opacity = flapOpacity
                drawFlat(&ctx, size)
            } else {
                drawFlat(&ctx, size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: torn) { _, now in now }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                torn = false
                flapOpacity = 1.0
                lifted = clampLifted(value.location, box: box)
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation
                let velocityMag = hypot(predicted.width - value.translation.width,
                                        predicted.height - value.translation.height)
                let pulled = pullDistance(value.location, box: box)
                // Fast flick OR pulled most of the way across -> tear free.
                if velocityMag > 220 || pulled > tearThreshold(box: box) {
                    tearFree()
                } else {
                    snapFlat()
                }
            }
    }

    private func snapFlat() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            lifted = CGPoint(x: box.maxX, y: box.maxY)
            flapOpacity = 1.0
        }
        // Once settled flat, drop the flap so we render the clean flat card.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let l = lifted, hypot(l.x - box.maxX, l.y - box.maxY) < 2 {
                lifted = nil
            }
        }
    }

    private func tearFree() {
        torn = true
        // Fling the corner away and fade out.
        withAnimation(.easeOut(duration: 0.35)) {
            flapOpacity = 0.0
        }
        // Reset to a fresh flat card so the component stays reusable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            lifted = nil
            torn = false
            withAnimation(.easeIn(duration: 0.4)) {
                flapOpacity = 1.0
            }
        }
    }

    private func tearThreshold(box: CGRect) -> CGFloat {
        hypot(box.width, box.height) * 0.62
    }

    private func pullDistance(_ point: CGPoint, box: CGRect) -> CGFloat {
        hypot(point.x - box.maxX, point.y - box.maxY)
    }

    /// Keep the lifted point inside a sane region so the crease stays a clean
    /// diagonal across the bottom-right corner.
    private func clampLifted(_ raw: CGPoint, box: CGRect) -> CGPoint {
        let corner = CGPoint(x: box.maxX, y: box.maxY)
        let maxReach = hypot(box.width, box.height) * 0.9
        var dx = raw.x - corner.x
        var dy = raw.y - corner.y
        let d = hypot(dx, dy)
        if d > maxReach, d > 0 {
            let s = maxReach / d
            dx *= s
            dy *= s
        }
        // Bias toward the top-left half-plane so it reads as a lift, not a poke.
        if dx > 0 { dx = 0 }
        if dy > 0 { dy = 0 }
        return CGPoint(x: corner.x + dx, y: corner.y + dy)
    }
}

// MARK: - Geometry & drawing (pure, shared by both modes)

private extension PeelAwayCardView {

    /// Centered card rect that scales with the available size.
    fileprivate func cardRect(in size: CGSize) -> CGRect {
        let inset = min(size.width, size.height) * 0.14
        let side = min(size.width, size.height) - inset * 2
        let w = side
        let h = side
        let x = (size.width - w) / 2
        let y = (size.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    fileprivate func drawFlatCard(in ctx: inout GraphicsContext, box: CGRect) {
        let rounded = Path(roundedRect: box, cornerRadius: box.width * 0.06)
        ctx.fill(rounded, with: .linearGradient(cardFaceGradient(),
                                                startPoint: box.origin,
                                                endPoint: CGPoint(x: box.maxX, y: box.maxY)))
        // Subtle face emblem so the card reads as content, not a blank slab.
        drawFaceEmblem(in: &ctx, box: box)
        // Hairline border for crispness.
        ctx.stroke(rounded, with: .color(Color(red: 1, green: 1, blue: 1, opacity: 0.10)),
                   lineWidth: 1)
    }

    fileprivate func drawPeel(in ctx: inout GraphicsContext,
                              size: CGSize,
                              box: CGRect,
                              lifted: CGPoint,
                              flapOpacity: Double) {
        let corner = CGPoint(x: box.maxX, y: box.maxY)
        let dist = hypot(lifted.x - corner.x, lifted.y - corner.y)

        // Degenerate / near-flat: just draw the flat card.
        if dist < 1.5 {
            drawFlatCard(in: &ctx, box: box)
            return
        }

        // Crease = perpendicular bisector of corner -> lifted.
        guard let (p1, p2) = creaseIntersections(corner: corner, lifted: lifted, box: box) else {
            drawFlatCard(in: &ctx, box: box)
            return
        }

        // 1) Card face with the triangular hole removed.
        drawFaceWithHole(in: &ctx, box: box, hole: [p1, corner, p2])

        // 2) Revealed surface under the lifted corner (the sticker backing).
        drawRevealedHole(in: &ctx, p1: p1, p2: p2, corner: corner)

        // 3) Soft drop shadow of the flap, offset toward the lift direction.
        drawFlapShadow(in: &ctx, p1: p1, p2: p2, lifted: lifted, corner: corner, opacity: flapOpacity)

        // 4) The lifted flap with its lit, curling underside.
        drawFlap(in: &ctx, p1: p1, p2: p2, lifted: lifted, corner: corner, opacity: flapOpacity)
    }

    // MARK: helpers

    /// Reflect `point` across the line that is the perpendicular bisector of
    /// segment a..b (i.e. the crease for folding `a` onto `b` reflects across it).
    fileprivate func reflect(_ point: CGPoint, acrossBisectorOf a: CGPoint, and b: CGPoint) -> CGPoint {
        // The bisector passes through midpoint m with normal n = (b - a).
        let mx = (a.x + b.x) / 2
        let my = (a.y + b.y) / 2
        let nx = b.x - a.x
        let ny = b.y - a.y
        let nLen2 = nx * nx + ny * ny
        if nLen2 == 0 { return point }
        // Signed distance along normal from the line.
        let d = ((point.x - mx) * nx + (point.y - my) * ny) / nLen2
        return CGPoint(x: point.x - 2 * d * nx, y: point.y - 2 * d * ny)
    }

    /// Where the crease (perp. bisector of corner->lifted) crosses the two card
    /// edges meeting at the bottom-right corner: the right edge (x = maxX) and
    /// the bottom edge (y = maxY).
    fileprivate func creaseIntersections(corner: CGPoint, lifted: CGPoint, box: CGRect) -> (CGPoint, CGPoint)? {
        let mx = (corner.x + lifted.x) / 2
        let my = (corner.y + lifted.y) / 2
        let nx = lifted.x - corner.x   // crease normal direction
        let ny = lifted.y - corner.y
        // Crease line: nx*(x-mx) + ny*(y-my) = 0.

        // Intersect with right edge x = box.maxX  -> solve for y.
        var pRight: CGPoint?
        if abs(ny) > 0.0001 {
            let y = my - (nx * (box.maxX - mx)) / ny
            if y >= box.minY - 0.5 && y <= box.maxY + 0.5 {
                pRight = CGPoint(x: box.maxX, y: min(max(y, box.minY), box.maxY))
            }
        }

        // Intersect with bottom edge y = box.maxY -> solve for x.
        var pBottom: CGPoint?
        if abs(nx) > 0.0001 {
            let x = mx - (ny * (box.maxY - my)) / nx
            if x >= box.minX - 0.5 && x <= box.maxX + 0.5 {
                pBottom = CGPoint(x: min(max(x, box.minX), box.maxX), y: box.maxY)
            }
        }

        guard let r = pRight, let b = pBottom else { return nil }
        return (r, b)
    }

    fileprivate func drawFaceWithHole(in ctx: inout GraphicsContext, box: CGRect, hole: [CGPoint]) {
        let rounded = Path(roundedRect: box, cornerRadius: box.width * 0.06)
        // Clip the face drawing to the card minus the hole triangle.
        ctx.drawLayer { layer in
            layer.clip(to: rounded)
            // Subtract the hole by clipping with inverse of the triangle.
            var holePath = Path()
            holePath.move(to: hole[0])
            holePath.addLine(to: hole[1])
            holePath.addLine(to: hole[2])
            holePath.closeSubpath()
            layer.clip(to: holePath, options: .inverse)

            layer.fill(rounded, with: .linearGradient(self.cardFaceGradient(),
                                                      startPoint: box.origin,
                                                      endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            self.drawFaceEmblem(in: &layer, box: box)
        }
        ctx.stroke(rounded, with: .color(Color(red: 1, green: 1, blue: 1, opacity: 0.10)), lineWidth: 1)
    }

    fileprivate func drawRevealedHole(in ctx: inout GraphicsContext, p1: CGPoint, p2: CGPoint, corner: CGPoint) {
        var hole = Path()
        hole.move(to: p1)
        hole.addLine(to: corner)
        hole.addLine(to: p2)
        hole.closeSubpath()
        // Darker backing surface revealed where the sticker lifted off.
        let backing = Color(red: 0.07, green: 0.08, blue: 0.11)
        ctx.fill(hole, with: .color(backing))
        // A faint inner shading near the crease so the cavity has depth.
        ctx.fill(hole, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0, green: 0, blue: 0, opacity: 0.0),
                Color(red: 0, green: 0, blue: 0, opacity: 0.35)
            ]),
            startPoint: midpoint(p1, p2),
            endPoint: corner))
    }

    fileprivate func drawFlapShadow(in ctx: inout GraphicsContext,
                                    p1: CGPoint, p2: CGPoint,
                                    lifted: CGPoint, corner: CGPoint,
                                    opacity: Double) {
        let liftedCorner = lifted
        var shadow = Path()
        shadow.move(to: p1)
        shadow.addLine(to: liftedCorner)
        shadow.addLine(to: p2)
        shadow.closeSubpath()

        // Offset the shadow toward the lift direction for a floating feel.
        let dir = normalize(CGPoint(x: lifted.x - corner.x, y: lifted.y - corner.y))
        let lift = hypot(lifted.x - corner.x, lifted.y - corner.y)
        let offset = min(lift * 0.10, 14)
        ctx.drawLayer { layer in
            layer.opacity = opacity * 0.5
            layer.translateBy(x: dir.x * offset + 3, y: dir.y * offset + 4)
            layer.addFilter(.blur(radius: max(4, offset)))
            layer.fill(shadow, with: .color(Color(red: 0, green: 0, blue: 0, opacity: 0.55)))
        }
    }

    fileprivate func drawFlap(in ctx: inout GraphicsContext,
                              p1: CGPoint, p2: CGPoint,
                              lifted: CGPoint, corner: CGPoint,
                              opacity: Double) {
        var flap = Path()
        flap.move(to: p1)
        flap.addLine(to: lifted)
        flap.addLine(to: p2)
        flap.closeSubpath()

        // Underside sheen runs from the crease (bright bend) to the lifted tip.
        let creaseMid = midpoint(p1, p2)
        ctx.drawLayer { layer in
            layer.opacity = opacity
            // Backside paper color with a curl gradient — brightest at the bend.
            layer.fill(flap, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.96, green: 0.95, blue: 0.99), location: 0.0),
                    .init(color: Color(red: 0.82, green: 0.83, blue: 0.90), location: 0.45),
                    .init(color: Color(red: 0.60, green: 0.62, blue: 0.72), location: 1.0)
                ]),
                startPoint: creaseMid,
                endPoint: lifted))

            // A glossy specular streak across the curl.
            layer.fill(flap, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 1, green: 1, blue: 1, opacity: 0.0), location: 0.0),
                    .init(color: Color(red: 1, green: 1, blue: 1, opacity: 0.55), location: 0.30),
                    .init(color: Color(red: 1, green: 1, blue: 1, opacity: 0.0), location: 0.55)
                ]),
                startPoint: creaseMid,
                endPoint: lifted))
        }

        // Bright highlight line along the crease (the catching bend).
        var crease = Path()
        crease.move(to: p1)
        crease.addLine(to: p2)
        ctx.drawLayer { layer in
            layer.opacity = opacity
            layer.addFilter(.blur(radius: 0.6))
            layer.stroke(crease, with: .color(Color(red: 1, green: 1, blue: 1, opacity: 0.75)),
                         lineWidth: 1.8)
        }

        // Crisp flap outline for definition.
        ctx.stroke(flap, with: .color(Color(red: 0.45, green: 0.47, blue: 0.56, opacity: opacity * 0.6)),
                   lineWidth: 0.8)
    }

    // MARK: face content & palette

    fileprivate func cardFaceGradient() -> Gradient {
        Gradient(colors: [
            Color(red: 0.36, green: 0.42, blue: 0.95),
            Color(red: 0.58, green: 0.30, blue: 0.92),
            Color(red: 0.92, green: 0.40, blue: 0.66)
        ])
    }

    /// A simple radial bloom + ring emblem so the card face is visually alive.
    fileprivate func drawFaceEmblem(in ctx: inout GraphicsContext, box: CGRect) {
        let c = CGPoint(x: box.midX, y: box.midY)
        let r = box.width * 0.30
        let bloom = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.fill(bloom, with: .radialGradient(
            Gradient(colors: [
                Color(red: 1, green: 1, blue: 1, opacity: 0.28),
                Color(red: 1, green: 1, blue: 1, opacity: 0.0)
            ]),
            center: c, startRadius: 0, endRadius: r))

        let ringR = box.width * 0.20
        let ring = Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2))
        ctx.stroke(ring, with: .color(Color(red: 1, green: 1, blue: 1, opacity: 0.30)),
                   lineWidth: box.width * 0.012)
    }

    // MARK: tiny math helpers

    fileprivate func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    fileprivate func normalize(_ v: CGPoint) -> CGPoint {
        let len = hypot(v.x, v.y)
        if len == 0 { return CGPoint(x: 0, y: 0) }
        return CGPoint(x: v.x / len, y: v.y / len)
    }
}
