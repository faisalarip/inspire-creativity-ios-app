// catalog-id: ld-gear-train
import SwiftUI

/// A train of three meshed gears with mathematically correct tooth counts,
/// pitch radii and inverse-ratio rotation. Gear 1 drives gear 2 (counter-
/// rotating) which drives gear 3. In `demo` mode a TimelineView cranks the
/// drive gear automatically; otherwise a RotationGesture (or drag around the
/// hub) lets you turn the whole mechanism by hand and the spin resumes on
/// release.
struct GearTrainView: View {
    var demo: Bool = false

    // Tooth counts for the three meshed gears (the "train").
    private let teeth: [Int] = [12, 20, 14]

    // Idle spin rate: ~1 revolution every 3 seconds for the drive gear.
    private let speed: CGFloat = 2 * .pi / 3

    // Committed drive-gear angle (radians) + the live gesture delta layered on
    // top while cranking. Splitting them keeps the release handoff seamless.
    @State private var committedAngle: CGFloat = 0
    @State private var liveDelta: CGFloat = 0
    @State private var isCranking: Bool = false
    @State private var startAngle: CGFloat = 0
    // Reference time the idle spin is anchored to; re-anchored on release so
    // the gear never teleports when the auto-spin resumes.
    @State private var spinAnchor: TimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            let layout = GearTrainView_GearLayout(size: geo.size, teeth: teeth)
            ZStack {
                backdrop
                if demo {
                    autoDrivenTrain(layout)
                } else {
                    interactiveTrain(layout)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.039, green: 0.063, blue: 0.078))
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.13, blue: 0.16),
                Color(red: 0.039, green: 0.063, blue: 0.078)
            ],
            center: .center,
            startRadius: 2,
            endRadius: 260
        )
    }

    // MARK: - Demo (self-driving) variant

    private func autoDrivenTrain(_ layout: GearTrainView_GearLayout) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let theta = CGFloat(t) * speed
            trainBody(layout: layout, driveAngle: theta)
        }
    }

    // MARK: - Interactive variant

    private func interactiveTrain(_ layout: GearTrainView_GearLayout) -> some View {
        // The gesture lives on the stable container (outside TimelineView) so
        // the in-flight recognizer is preserved across frames; the timeline
        // only reads state to draw.
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idle = isCranking ? 0 : CGFloat(t - spinAnchor) * speed
            let theta = committedAngle + liveDelta + idle
            trainBody(layout: layout, driveAngle: theta)
        }
        .contentShape(Rectangle())
        .gesture(crankGesture(layout: layout))
    }

    private func crankGesture(layout: GearTrainView_GearLayout) -> some Gesture {
        // Drag around the drive hub: the angle swept from the hub to the finger
        // becomes the live crank delta. minimumDistance 0 so the piece wins
        // inside a ScrollView.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isCranking {
                    // Fold the idle spin accrued so far into committed so the
                    // gear does not jump when the crank engages.
                    let now = Date().timeIntervalSinceReferenceDate
                    committedAngle += CGFloat(now - spinAnchor) * speed
                    isCranking = true
                    startAngle = hubAngle(of: value.startLocation, hub: layout.center(0))
                }
                let current = hubAngle(of: value.location, hub: layout.center(0))
                liveDelta = angularDifference(from: startAngle, to: current)
            }
            .onEnded { _ in
                committedAngle += liveDelta
                liveDelta = 0
                // Re-anchor the idle clock so the auto-spin resumes from the
                // current angle instead of teleporting.
                spinAnchor = Date().timeIntervalSinceReferenceDate
                isCranking = false
            }
    }

    private func hubAngle(of point: CGPoint, hub: CGPoint) -> CGFloat {
        atan2(point.y - hub.y, point.x - hub.x)
    }

    /// Smallest signed difference so crossing the ±π seam does not snap.
    private func angularDifference(from a: CGFloat, to b: CGFloat) -> CGFloat {
        var d = b - a
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    // MARK: - Shared train body

    private func trainBody(layout: GearTrainView_GearLayout, driveAngle theta: CGFloat) -> some View {
        let r2 = layout.rotation(forGear: 1, driveAngle: theta)
        let r3 = layout.rotation(forGear: 2, driveAngle: theta)
        return ZStack {
            gearView(index: 1, layout: layout, angle: r2,
                     body: Color(red: 0.36, green: 0.44, blue: 0.52),
                     edge: Color(red: 0.52, green: 0.62, blue: 0.70))
            gearView(index: 2, layout: layout, angle: r3,
                     body: Color(red: 0.78, green: 0.55, blue: 0.28),
                     edge: Color(red: 0.92, green: 0.70, blue: 0.40))
            gearView(index: 0, layout: layout, angle: theta,
                     body: Color(red: 0.20, green: 0.62, blue: 0.74),
                     edge: Color(red: 0.42, green: 0.84, blue: 0.94))
        }
    }

    // MARK: - One gear

    private func gearView(index: Int, layout: GearTrainView_GearLayout, angle: CGFloat,
                          body: Color, edge: Color) -> some View {
        let center = layout.center(index)
        let outer = layout.tipRadius(index)
        let count = teeth[index]
        return ZStack {
            GearTrainView_GearShape(toothCount: count, geometry: layout.geometry(index))
                .fill(
                    LinearGradient(
                        colors: [edge, body],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    GearTrainView_GearShape(toothCount: count, geometry: layout.geometry(index))
                        .stroke(edge.opacity(0.9), lineWidth: 1)
                )
            hubDetail(outer: outer, body: body, edge: edge)
        }
        .frame(width: outer * 2, height: outer * 2)
        .rotationEffect(.radians(Double(angle)))
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
        .position(center)
    }

    private func hubDetail(outer: CGFloat, body: Color, edge: Color) -> some View {
        let hub = outer * 0.34
        let bore = outer * 0.16
        return ZStack {
            Circle()
                .fill(body.opacity(0.55))
                .frame(width: hub * 2, height: hub * 2)
            Circle()
                .stroke(edge.opacity(0.8), lineWidth: 1.5)
                .frame(width: hub * 2, height: hub * 2)
            // Three spoke lightening holes for mechanical detail.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.039, green: 0.063, blue: 0.078).opacity(0.5))
                    .frame(width: bore, height: bore)
                    .offset(y: -(hub + bore) * 0.95)
                    .rotationEffect(.degrees(Double(i) * 120))
            }
            Circle()
                .fill(Color(red: 0.039, green: 0.063, blue: 0.078))
                .frame(width: bore * 1.1, height: bore * 1.1)
        }
    }
}

// MARK: - Per-gear pitch geometry

/// Radii (in the gear's own local frame, centered at 0,0) describing the tooth
/// profile of a single gear, scaled by the shared module.
private struct GearTrainView_GearGeometry {
    let pitchRadius: CGFloat   // pitch circle (where teeth mesh)
    let tipRadius: CGFloat     // outer tip of teeth
    let rootRadius: CGFloat    // inner valley of teeth
}

// MARK: - Layout: positions, sizing, ratios, phases

/// Computes a centered, colinear (diagonally tilted) gear train that fits the
/// available rect, plus the correct rotation for each dependent gear.
private struct GearTrainView_GearLayout {
    let teeth: [Int]
    let module: CGFloat          // pitch diameter per tooth
    let centers: [CGPoint]
    let geometries: [GearTrainView_GearGeometry]
    let lineAngle: CGFloat       // angle of the colinear center line

    init(size: CGSize, teeth: [Int]) {
        self.teeth = teeth

        // Tilt the train diagonally to fill a square tile.
        let angle: CGFloat = -0.42 // radians, gentle upward-right diagonal
        self.lineAngle = angle

        // Pitch radius is proportional to tooth count: r_i = module * t_i / 2.
        // Consecutive centers sit r_i + r_{i+1} apart along the line. The full
        // tip-to-tip span (in module units) is the center run plus the two
        // outer addendum tips:
        //   tip0 + (r0 + 2*r1 + r2) + tip2
        // = (t0 + 2*t1 + t2)/2 + 2   (addendum = 1 module on each end)
        let centerRun = CGFloat(teeth[0] + 2 * teeth[1] + teeth[2]) / 2
        let denom = centerRun + 2
        let span = max(size.width, size.height)
        let rawModule = (span * 0.86) / denom
        self.module = max(rawModule, 1)

        let m = self.module
        let pitch = teeth.map { m * CGFloat($0) / 2 }
        let addendum = m              // tip = pitch + addendum
        let dedendum = m * 1.25       // root = pitch - dedendum

        var geos: [GearTrainView_GearGeometry] = []
        for i in teeth.indices {
            geos.append(
                GearTrainView_GearGeometry(
                    pitchRadius: pitch[i],
                    tipRadius: pitch[i] + addendum,
                    rootRadius: max(pitch[i] - dedendum, pitch[i] * 0.45)
                )
            )
        }
        self.geometries = geos

        // Lay centers along the line: c0 at origin, then accumulate r_i+r_{i+1}.
        let dir = CGPoint(x: cos(angle), y: sin(angle))
        var local: [CGPoint] = [CGPoint(x: 0, y: 0)]
        var dist: CGFloat = 0
        for i in 1..<teeth.count {
            dist += pitch[i - 1] + pitch[i]
            local.append(CGPoint(x: dir.x * dist, y: dir.y * dist))
        }

        // Bounding box of the tip circles, so we can center the whole train.
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for i in teeth.indices {
            let tip = geos[i].tipRadius
            minX = min(minX, local[i].x - tip); maxX = max(maxX, local[i].x + tip)
            minY = min(minY, local[i].y - tip); maxY = max(maxY, local[i].y + tip)
        }
        let boxCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let target = CGPoint(x: size.width / 2, y: size.height / 2)
        self.centers = local.map {
            CGPoint(x: $0.x - boxCenter.x + target.x,
                    y: $0.y - boxCenter.y + target.y)
        }
    }

    func center(_ i: Int) -> CGPoint { centers[i] }
    func tipRadius(_ i: Int) -> CGFloat { geometries[i].tipRadius }
    func geometry(_ i: Int) -> GearTrainView_GearGeometry { geometries[i] }

    /// Angle (radians) from the center of gear `i` to gear `j`, in the same
    /// y-down coordinate space rotationEffect uses.
    private func meshAngle(from i: Int, to j: Int) -> CGFloat {
        atan2(centers[j].y - centers[i].y, centers[j].x - centers[i].x)
    }

    /// Correct rotation for a dependent gear so its teeth interlock with its
    /// driver. Gear 1 meshes gear 0 (counter-rotating); gear 2 meshes gear 1.
    ///
    ///   R_j = -(t_i/t_j)*R_i + (1 + t_i/t_j)*phi_ij + pi + pi/t_j
    ///
    /// where phi_ij is the line angle between the two hubs. The half-tooth
    /// (pi/t_j) term seats gear i's tooth into gear j's valley.
    func rotation(forGear j: Int, driveAngle theta: CGFloat) -> CGFloat {
        if j == 1 {
            return meshedRotation(driver: 0, drivee: 1, driverAngle: theta)
        } else {
            let r1 = meshedRotation(driver: 0, drivee: 1, driverAngle: theta)
            return meshedRotation(driver: 1, drivee: 2, driverAngle: r1)
        }
    }

    private func meshedRotation(driver i: Int, drivee j: Int, driverAngle Ri: CGFloat) -> CGFloat {
        let ratio = CGFloat(teeth[i]) / CGFloat(teeth[j])
        let phi = meshAngle(from: i, to: j)
        let halfTooth = CGFloat.pi / CGFloat(teeth[j])
        return -ratio * Ri + (1 + ratio) * phi + .pi + halfTooth
    }
}

// MARK: - Gear shape

/// A static involute-ish gear outline built from radial trapezoid teeth.
/// All motion comes from `rotationEffect`, so no animatableData is needed.
private struct GearTrainView_GearShape: Shape {
    let toothCount: Int
    let geometry: GearTrainView_GearGeometry

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let count = max(toothCount, 4)
        let tip = geometry.tipRadius
        let root = geometry.rootRadius

        let pitchAngle = (2 * CGFloat.pi) / CGFloat(count)
        // Generous gap: tooth occupies ~0.42 of the pitch angle, valley ~0.58.
        // This absorbs any half-tooth phase sign error so teeth still read as
        // meshed rather than interpenetrating.
        let toothFraction: CGFloat = 0.42
        let toothWidth = pitchAngle * toothFraction
        // Taper: tooth is narrower at the tip than at the root (trapezoid).
        let tipTaper: CGFloat = 0.6

        for i in 0..<count {
            let center = CGFloat(i) * pitchAngle
            let rootStart = center - pitchAngle / 2
            let rootBeforeTooth = center - toothWidth / 2
            let rootAfterTooth = center + toothWidth / 2
            let tipStart = center - (toothWidth * tipTaper) / 2
            let tipEnd = center + (toothWidth * tipTaper) / 2

            if i == 0 {
                path.move(to: point(c, root, rootStart))
            }
            // Along the root valley up to the rising flank.
            path.addLine(to: point(c, root, rootBeforeTooth))
            // Up the rising flank to the tip.
            path.addLine(to: point(c, tip, tipStart))
            // Across the tip.
            path.addLine(to: point(c, tip, tipEnd))
            // Down the falling flank back to the root.
            path.addLine(to: point(c, root, rootAfterTooth))
            // Along the root to the next tooth's start.
            path.addLine(to: point(c, root, center + pitchAngle / 2))
        }
        path.closeSubpath()
        return path
    }

    private func point(_ c: CGPoint, _ r: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
    }
}
