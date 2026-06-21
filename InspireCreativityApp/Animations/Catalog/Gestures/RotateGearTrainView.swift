// catalog-id: ges-rotate-gear-train
import SwiftUI

// MARK: - Public View

/// Meshed Gear Train — rotate the drive gear and a train of meshed gears turns
/// in alternating directions at tooth-ratio-scaled speeds, with a brief backlash
/// jiggle on direction reversal.
///
/// - `demo == true`  : self-driving auto-crank loop (forward → pause → reverse).
/// - `demo == false` : one-finger interactive crank (atan2 DragGesture on the drive gear).
struct RotateGearTrainView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            GearTrainStage(size: proxy.size, demo: demo)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Gear specification (tooth counts chosen so the middle gear is ODD,
// which is the parity condition for both meshes to align by construction).

private enum GearTrainConfig {
    /// Tooth counts. Index 0 is the drive gear. Middle (index 1) MUST be odd.
    static let teeth: [Int] = [12, 15, 9]
    /// Sum of tooth counts — drives pitch-radius packing along the train axis.
    static var teethSum: CGFloat { CGFloat(teeth.reduce(0, +)) }
    static var maxTeeth: CGFloat { CGFloat(teeth.max() ?? 12) }
    /// Addendum in module units (tooth tip extends 1 module beyond pitch radius).
    static let addendum: CGFloat = 1.0
}

// MARK: - Stage: lays out the train, owns the crank state, hosts both drivers.

private struct GearTrainStage: View {
    let size: CGSize
    let demo: Bool

    // Interactive crank state.
    @State private var driveAngle: Double = 0          // accumulated drive rotation (radians)
    @State private var lastTouchAngle: Double? = nil    // atan2 of previous drag sample
    @State private var reverseTrigger: Int = 0          // backlash impulse source
    @State private var backlashSign: Double = 1         // direction of the last jiggle
    @State private var meshTick: Int = 0                // haptic per tooth-mesh crossing

    // Backlash transient: a decaying spring offset added to downstream gears.
    @State private var backlash: Double = 0

    var body: some View {
        let layout = GearLayout(size: size)

        ZStack {
            backdrop
            if demo {
                demoContent(layout: layout)
            } else {
                interactiveContent(layout: layout)
            }
        }
        .compositingGroup()
        // Subtle haptics where supported; harmless no-op elsewhere.
        .sensoryFeedback(.selection, trigger: meshTick)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: reverseTrigger)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.11),
                        Color(red: 0.10, green: 0.11, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.05), lineWidth: 1)
            )
    }

    // MARK: Interactive (demo == false)

    private func interactiveContent(layout: GearLayout) -> some View {
        trainBody(layout: layout, drive: driveAngle, backlash: backlash)
            .contentShape(Rectangle())
            .gesture(crankGesture(layout: layout))
    }

    private func crankGesture(layout: GearLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let c = layout.center(of: 0)
                let current = atan2(value.location.y - c.y, value.location.x - c.x)
                guard let previous = lastTouchAngle else {
                    lastTouchAngle = current
                    return
                }
                var delta = current - previous
                // Unwrap across the ±π seam so a continuous crank stays continuous.
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                lastTouchAngle = current

                let newAngle = driveAngle + delta
                detectReversalAndMesh(old: driveAngle, new: newAngle)
                driveAngle = newAngle
            }
            .onEnded { _ in
                lastTouchAngle = nil
            }
    }

    /// Fires a backlash impulse on drive-direction reversal and a mesh tick per
    /// tooth crossing of the drive gear. Kept additive + clamped so teeth never
    /// appear to unmesh.
    private func detectReversalAndMesh(old: Double, new: Double) {
        let movement = new - old
        if movement != 0 {
            let dir = movement > 0 ? 1.0 : -1.0
            if dir != backlashSign {
                backlashSign = dir
                fireBacklash(direction: dir)
            }
        }
        // One tick per tooth of the drive gear passing the mesh point.
        let pitch = 2 * Double.pi / Double(GearTrainConfig.teeth[0])
        let oldTooth = Int((old / pitch).rounded(.down))
        let newTooth = Int((new / pitch).rounded(.down))
        if oldTooth != newTooth { meshTick &+= 1 }
    }

    private func fireBacklash(direction: Double) {
        reverseTrigger &+= 1
        // Peak amplitude is a small fraction of one tooth pitch on the SMALLEST
        // downstream gear, so the jiggle never reads as the mesh letting go.
        let smallestDownstream = GearTrainConfig.teeth.dropFirst().min() ?? 9
        let cap = (Double.pi / Double(smallestDownstream)) * 0.28
        backlash = direction * cap
        withAnimation(.interpolatingSpring(stiffness: 220, damping: 7)) {
            backlash = 0
        }
    }

    // MARK: Demo (demo == true) — self-driving crank loop.

    private func demoContent(layout: GearLayout) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = DemoCrank.drive(at: t)
            trainBody(layout: layout, drive: phase.angle, backlash: phase.backlash)
        }
    }

    // MARK: Shared train rendering

    private func trainBody(layout: GearLayout, drive: Double, backlash: Double) -> some View {
        ZStack {
            // Connecting baseplate "shaft rail" for mechanical grounding.
            shaftRail(layout: layout)
            ForEach(GearTrainConfig.teeth.indices, id: \.self) { index in
                gearView(index: index, layout: layout, drive: drive, backlash: backlash)
            }
            crankHint(layout: layout, drive: drive)
        }
    }

    private func shaftRail(layout: GearLayout) -> some View {
        let c0 = layout.center(of: 0)
        let cN = layout.center(of: GearTrainConfig.teeth.count - 1)
        return Path { p in
            p.move(to: c0)
            p.addLine(to: cN)
        }
        .stroke(Color(red: 0.18, green: 0.20, blue: 0.27).opacity(0.7),
                style: StrokeStyle(lineWidth: max(2, layout.module * 0.5), lineCap: .round))
    }

    @ViewBuilder
    private func gearView(index: Int, layout: GearLayout, drive: Double, backlash: Double) -> some View {
        let teeth = GearTrainConfig.teeth[index]
        let center = layout.center(of: index)
        let pitchR = layout.pitchRadius(of: index)
        let angle = gearAngle(index: index, drive: drive, backlash: backlash)

        Gear(teeth: teeth, pitchRadius: pitchR, module: layout.module)
            .fill(gearFill(index: index))
            .overlay(
                Gear(teeth: teeth, pitchRadius: pitchR, module: layout.module)
                    .stroke(Color(red: 0.02, green: 0.03, blue: 0.05).opacity(0.55),
                            lineWidth: max(0.6, layout.module * 0.12))
            )
            .overlay(hubDecoration(index: index, pitchR: pitchR, layout: layout))
            .rotationEffect(.radians(angle))
            .position(center)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.35),
                    radius: layout.module * 0.6, x: 0, y: layout.module * 0.35)
    }

    /// Closed-form rotation. Telescopes — no per-frame chaining, so no drift.
    /// rot_i = (-1)^i * (N0 / Ni) * drive + restPhase_i  (+ backlash for i >= 1)
    private func gearAngle(index: Int, drive: Double, backlash: Double) -> Double {
        let n0 = Double(GearTrainConfig.teeth[0])
        let ni = Double(GearTrainConfig.teeth[index])
        let sign: Double = (index % 2 == 0) ? 1 : -1
        let ratioRotation = sign * (n0 / ni) * drive
        let rest = restPhase(index: index)
        // Backlash only on downstream gears, scaled with ratio so the visual
        // jiggle magnitude stays roughly uniform across the train.
        let jiggle = (index == 0) ? 0 : backlash * (n0 / ni)
        return ratioRotation + rest + jiggle
    }

    /// Rest (mesh) phase, written against the Path convention that a TOOTH TIP
    /// sits at local angle 0. Drive gear has zero offset; each downstream gear is
    /// offset so a VALLEY faces its left neighbor (angle π). Middle-gear odd-parity
    /// guarantees a tooth TIP simultaneously faces the right neighbor.
    private func restPhase(index: Int) -> Double {
        guard index > 0 else { return 0 }
        let ni = Double(GearTrainConfig.teeth[index])
        return Double.pi - Double.pi / ni
    }

    // MARK: Decoration

    private func gearFill(index: Int) -> RadialGradient {
        let palettes: [(Color, Color)] = [
            (Color(red: 0.55, green: 0.78, blue: 0.95), Color(red: 0.16, green: 0.34, blue: 0.55)),
            (Color(red: 0.96, green: 0.74, blue: 0.45), Color(red: 0.55, green: 0.30, blue: 0.12)),
            (Color(red: 0.62, green: 0.86, blue: 0.66), Color(red: 0.18, green: 0.44, blue: 0.30))
        ]
        let pair = palettes[index % palettes.count]
        return RadialGradient(
            colors: [pair.0, pair.1],
            center: .init(x: 0.38, y: 0.34),
            startRadius: 1,
            endRadius: 120
        )
    }

    @ViewBuilder
    private func hubDecoration(index: Int, pitchR: CGFloat, layout: GearLayout) -> some View {
        let hubR = pitchR * 0.42
        ZStack {
            Circle()
                .fill(Color(red: 0.10, green: 0.11, blue: 0.15))
                .frame(width: hubR * 2, height: hubR * 2)
            Circle()
                .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.10),
                              lineWidth: max(0.8, layout.module * 0.18))
                .frame(width: hubR * 2, height: hubR * 2)
            // A spoke marker so rotation is visually unambiguous.
            Capsule()
                .fill(Color(red: 1, green: 1, blue: 1).opacity(0.75))
                .frame(width: max(1.5, layout.module * 0.32), height: pitchR * 0.72)
                .offset(y: -pitchR * 0.34)
            Circle()
                .fill(Color(red: 0.45, green: 0.47, blue: 0.55))
                .frame(width: hubR * 0.7, height: hubR * 0.7)
        }
    }

    /// A faint rotating arc on the drive gear to read as "this is the one you turn".
    @ViewBuilder
    private func crankHint(layout: GearLayout, drive: Double) -> some View {
        let c0 = layout.center(of: 0)
        let r = layout.outerRadius(of: 0) + layout.module * 0.7
        Circle()
            .trim(from: 0, to: 0.16)
            .stroke(Color(red: 1, green: 1, blue: 1).opacity(0.22),
                    style: StrokeStyle(lineWidth: max(1, layout.module * 0.25), lineCap: .round))
            .frame(width: r * 2, height: r * 2)
            .rotationEffect(.radians(drive))
            .position(c0)
    }
}

// MARK: - Layout: derives module + centers from the available size.

private struct GearLayout {
    let size: CGSize
    let module: CGFloat
    private let centers: [CGPoint]

    init(size: CGSize) {
        self.size = size

        // Train extent along X = first gear outer radius + Σ center distances +
        // last gear outer radius. Center distance between meshed gears i,i+1 =
        // (Ni + N(i+1))/2 * module. Bound module by BOTH width and height.
        let teeth = GearTrainConfig.teeth
        var widthUnits: CGFloat = 0
        widthUnits += CGFloat(teeth.first ?? 12) / 2 + GearTrainConfig.addendum    // first outer
        widthUnits += CGFloat(teeth.last ?? 9) / 2 + GearTrainConfig.addendum      // last outer
        for i in 0..<(teeth.count - 1) {
            widthUnits += CGFloat(teeth[i] + teeth[i + 1]) / 2                      // center gaps
        }
        let widthSlack: CGFloat = 2.4
        let moduleByWidth = size.width / (widthUnits + widthSlack)

        // Height bound: tallest gear diameter = (maxN/2 + addendum) * 2 * module.
        let heightUnits = (GearTrainConfig.maxTeeth / 2 + GearTrainConfig.addendum) * 2
        let heightSlack: CGFloat = 1.6
        let moduleByHeight = size.height / (heightUnits + heightSlack)

        self.module = max(0.5, min(moduleByWidth, moduleByHeight))

        // Build centers, colinear along the mid-height line, centered horizontally.
        let m = self.module
        let radii: [CGFloat] = teeth.map { CGFloat($0) / 2 * m }    // pitch radii
        let add = GearTrainConfig.addendum * m
        var xs: [CGFloat] = []
        var cursor: CGFloat = 0
        for i in radii.indices {
            if i == 0 {
                cursor = add + radii[0]
            } else {
                cursor += radii[i - 1] + radii[i]                   // center distance
            }
            xs.append(cursor)
        }
        let trainWidth = (xs.last ?? 0) + (radii.last ?? 0) + add
        let leftPad = (size.width - trainWidth) / 2
        let midY = size.height / 2
        self.centers = xs.map { CGPoint(x: leftPad + $0, y: midY) }
    }

    func center(of index: Int) -> CGPoint {
        guard centers.indices.contains(index) else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        return centers[index]
    }

    func pitchRadius(of index: Int) -> CGFloat {
        CGFloat(GearTrainConfig.teeth[index]) / 2 * module
    }

    func outerRadius(of index: Int) -> CGFloat {
        pitchRadius(of: index) + GearTrainConfig.addendum * module
    }
}

// MARK: - Gear shape (Path convention: a TOOTH TIP is centered at local angle 0).

private struct Gear: Shape {
    let teeth: Int
    let pitchRadius: CGFloat
    let module: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let n = max(4, teeth)
        let rPitch = pitchRadius
        let rOuter = rPitch + module * GearTrainConfig.addendum                       // tip radius
        let rRoot = max(module, rPitch - module * GearTrainConfig.addendum * 1.05)     // dedendum

        // Each tooth spans one pitch = 2π/n. Per pitch we draw, in order:
        // [tip-flat | down-flank | root-flat | up-flank], with the TIP centered at
        // the tooth's nominal angle so tooth k=0's tip sits exactly at local angle 0.
        let pitch = (2 * Double.pi) / Double(n)
        let tipHalf = pitch * 0.20      // half-width of the flat tooth tip
        let rootHalf = pitch * 0.20     // half-width of the flat valley

        var path = Path()
        for k in 0..<n {
            let toothCenter = pitch * Double(k)     // tip centered here (k=0 → angle 0)

            let aTipStart = toothCenter - tipHalf
            let aTipEnd = toothCenter + tipHalf
            let aRootStart = toothCenter + tipHalf + (pitch / 2 - tipHalf - rootHalf)
            let aRootEnd = aRootStart + 2 * rootHalf

            let pTipStart = point(center, rOuter, aTipStart)
            if k == 0 {
                path.move(to: pTipStart)
            } else {
                path.addLine(to: pTipStart)         // up-flank from previous valley
            }
            path.addLine(to: point(center, rOuter, aTipEnd))    // tip flat
            path.addLine(to: point(center, rRoot, aRootStart))  // down flank
            path.addLine(to: point(center, rRoot, aRootEnd))    // root flat
            // Up-flank to the next tip start is drawn by the next iteration
            // (or by closeSubpath for the final tooth back to k == 0).
        }
        path.closeSubpath()
        return path
    }

    private func point(_ c: CGPoint, _ r: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: c.x + r * CGFloat(cos(angle)),
                y: c.y + r * CGFloat(sin(angle)))
    }
}

// MARK: - Demo crank script (forward → dwell → reverse → dwell), firing a backlash
// impulse at each reversal. Period ~3.4s. Never blank: gears are always visible.

private enum DemoCrank {
    static let period: Double = 3.4

    struct Phase { let angle: Double; let backlash: Double }

    static func drive(at time: Double) -> Phase {
        let t = time.truncatingRemainder(dividingBy: period)
        let u = t / period                      // 0..1

        let span: Double = 2.6 * .pi            // total forward sweep in radians

        let angle: Double
        let pulse: Double
        if u < 0.40 {
            let p = u / 0.40
            angle = span * easeInOut(p)
            pulse = 0
        } else if u < 0.50 {
            angle = span
            pulse = reversalPulse((u - 0.40) / 0.10)   // top dwell → jiggle in
        } else if u < 0.90 {
            let p = (u - 0.50) / 0.40
            angle = span * (1 - easeInOut(p))
            pulse = 0
        } else {
            angle = 0
            pulse = reversalPulse((u - 0.90) / 0.10)   // bottom dwell → jiggle in
        }

        // Backlash transient expressed in DRIVE units (gearAngle re-scales by ratio).
        let n0 = Double(GearTrainConfig.teeth[0])
        let smallest = Double(GearTrainConfig.teeth.dropFirst().min() ?? 9)
        let cap = (Double.pi / smallest) * 0.26 / (n0 / smallest)
        let dir: Double = (u >= 0.40 && u < 0.50) ? -1 : 1
        let backlash = dir * cap * pulse

        return Phase(angle: angle, backlash: backlash)
    }

    /// A decaying oscillation over a 0..1 window (1 at start, ringing down to 0).
    private static func reversalPulse(_ x: Double) -> Double {
        let clamped = min(max(x, 0), 1)
        let decay = exp(-4.0 * clamped)
        let ring = cos(clamped * 2 * Double.pi * 1.5)
        return decay * ring
    }

    private static func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
