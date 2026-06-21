// catalog-id: nav-magnetic-grab-drawer
import SwiftUI

// MARK: - Magnetic Grab Drawer
// A thin edge handle that leans toward your finger with a magnetic pull,
// stretches a rubbery neck as you drag the drawer out, and recoils with a
// velocity-aware spring on release.
struct MagneticGrabDrawerView: View {
    var demo: Bool = false

    // Single source of truth shared by interactive + demo render paths.
    // openProgress: 0 = drawer tucked at edge, 1 = fully pulled out.
    // handleLeanY:  0 = handle resting at its rail center,
    //              ±1 = handle leaned fully toward the touch (vertical offset).
    @State private var openProgress: CGFloat = 0
    @State private var handleLeanY: CGFloat = 0

    // Haptic latch: flips when the magnetic attraction first "grabs".
    @State private var snapLatch: Int = 0
    @State private var isGrabbed: Bool = false

    var body: some View {
        GeometryReader { geo in
            if demo {
                demoBody(in: geo.size)
            } else {
                interactiveBody(in: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.063, green: 0.078, blue: 0.094))
        .sensoryFeedback(.impact(weight: .medium), trigger: snapLatch)
    }

    // MARK: Demo (self-driving synthetic finger)

    private func demoBody(in size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = MagneticGrabDrawerView_DemoFinger.sample(at: t)
            MagneticGrabDrawerView_DrawerStage(
                size: size,
                openProgress: phase.open,
                handleLeanY: phase.lean
            )
            .onChange(of: phase.grabbed) { _, grabbed in
                if grabbed { snapLatch &+= 1 }
            }
        }
    }

    // MARK: Interactive

    private func interactiveBody(in size: CGSize) -> some View {
        MagneticGrabDrawerView_DrawerStage(
            size: size,
            openProgress: openProgress,
            handleLeanY: handleLeanY
        )
        .contentShape(Rectangle())
        .gesture(drawerDrag(in: size))
    }

    private func drawerDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let metrics = MagneticGrabDrawerView_DrawerMetrics(size: size)
                // Pull-out distance maps drag.x onto open progress.
                let raw = value.translation.width / metrics.travel
                openProgress = clamp(raw, 0, 1.08) // small overscroll headroom

                // Handle leans toward the finger's vertical position.
                let railCenterY = metrics.railCenterY
                let dy = value.location.y - railCenterY
                let lean = attractionCurve(dy / (metrics.height * 0.5))
                handleLeanY = lean

                // Magnetic "grab": fire haptic once when lean first exceeds threshold.
                let grabbing = abs(lean) > 0.35 || openProgress > 0.06
                if grabbing && !isGrabbed {
                    isGrabbed = true
                    snapLatch &+= 1
                } else if !grabbing {
                    isGrabbed = false
                }
            }
            .onEnded { value in
                let metrics = MagneticGrabDrawerView_DrawerMetrics(size: size)
                // Velocity-aware: blend release point + predicted travel.
                let predicted = value.predictedEndTranslation.width / metrics.travel
                let projected = (openProgress + predicted) * 0.5
                let shouldOpen = projected > 0.5
                // Normalized initial velocity seed (kept reasonable, not exact physics).
                let v = value.velocity.width / metrics.travel
                let seedVelocity = clamp(v, -6, 6)

                isGrabbed = false
                withAnimation(.interpolatingSpring(
                    mass: 0.9,
                    stiffness: 140,
                    damping: 13,
                    initialVelocity: seedVelocity
                )) {
                    openProgress = shouldOpen ? 1 : 0
                    handleLeanY = 0
                }
            }
    }

    private func attractionCurve(_ x: CGFloat) -> CGFloat {
        // Eager near center, eases off near the rail ends so the handle
        // lunges to meet the finger without overshooting the edge.
        let c = clamp(x, -1, 1)
        let eased = c * (1.6 - 0.6 * abs(c))
        return clamp(eased, -1, 1)
    }
}

// MARK: - Demo finger script

private enum MagneticGrabDrawerView_DemoFinger {
    struct Phase {
        var open: CGFloat
        var lean: CGFloat
        var grabbed: Bool
    }

    // ~3.0s loop: approach (handle reaches) -> grab -> stretch out -> recoil.
    static func sample(at time: TimeInterval) -> Phase {
        let period: Double = 3.0
        let u = (time.truncatingRemainder(dividingBy: period)) / period // 0..1

        // Lean: finger sweeps in, handle lunges to meet it, then releases.
        // Stays non-zero through the active window; rests near 0 otherwise.
        let lean: CGFloat
        if u < 0.18 {
            // approach: lean ramps up toward finger
            lean = ease(CGFloat(u / 0.18)) * 0.85
        } else if u < 0.72 {
            // held: gentle sinusoidal sway while drawer is out
            let s = CGFloat((u - 0.18) / 0.54)
            lean = 0.85 - 0.45 * (1 - cos(s * .pi * 2)) * 0.5
        } else {
            // recoil: lean settles back to neutral
            let s = CGFloat((u - 0.72) / 0.28)
            lean = (1 - ease(s)) * 0.4
        }

        // Open: closed -> stretch out -> hold -> spring recoil closed.
        let open: CGFloat
        if u < 0.18 {
            open = ease(CGFloat(u / 0.18)) * 0.12 // handle nudges as it grabs
        } else if u < 0.55 {
            // stretch the drawer out
            open = 0.12 + ease(CGFloat((u - 0.18) / 0.37)) * 0.88
        } else if u < 0.72 {
            open = 1.0 // hold open
        } else {
            // recoil with a little overshoot then settle closed
            let s = CGFloat((u - 0.72) / 0.28)
            let settle = 1 - ease(s)
            let overshoot = sin(s * .pi * 3) * 0.06 * (1 - s)
            open = max(0, settle - overshoot)
        }

        // Grab moment: just after approach completes.
        let grabbed = u >= 0.16 && u < 0.20
        return Phase(open: open, lean: clamp(lean, -1, 1), grabbed: grabbed)
    }

    static func ease(_ t: CGFloat) -> CGFloat {
        let c = clamp(t, 0, 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Layout metrics

private struct MagneticGrabDrawerView_DrawerMetrics {
    let size: CGSize

    init(size: CGSize) { self.size = size }

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }

    // Handle is a thin pill anchored to the left edge.
    var handleWidth: CGFloat { max(8, min(width, height) * 0.07) }
    var handleHeight: CGFloat { height * 0.34 }
    var handleRestX: CGFloat { handleWidth * 0.5 + width * 0.02 }
    var railCenterY: CGFloat { height * 0.5 }

    // How far the drawer body travels from tucked to fully open.
    var travel: CGFloat { width * 0.62 }

    // Drawer body geometry.
    var bodyWidth: CGFloat { max(28, width * 0.30) }
    var bodyHeight: CGFloat { height * 0.74 }
    // Tucked just off the left edge; pulled out by openProgress * travel.
    var bodyTuckedX: CGFloat { -bodyWidth * 0.62 }

    // Shared geometry resolvers so the stage AND the animatable neck compute
    // the handle/body anchor points from identical formulas. This keeps the
    // tether endpoints locked to the handle/body during the release spring.
    func clampedOpen(_ open: CGFloat) -> CGFloat { min(max(open, 0), 1.08) }

    func handleCenter(open: CGFloat, lean: CGFloat) -> CGPoint {
        let co = clampedOpen(open)
        let leanMax = height * 0.30
        let x = handleRestX + co * (handleWidth * 0.6)
        let y = railCenterY + lean * leanMax
        return CGPoint(x: x, y: y)
    }

    func bodyCenter(open: CGFloat, lean: CGFloat) -> CGPoint {
        let co = clampedOpen(open)
        let x = bodyTuckedX + bodyWidth * 0.5 + co * travel
        // Body lags slightly toward the handle's lean (tether drag).
        let y = railCenterY + lean * (height * 0.10) * co
        return CGPoint(x: x, y: y)
    }
}

// MARK: - The composed stage (shared by demo + interactive)

private struct MagneticGrabDrawerView_DrawerStage: View {
    let size: CGSize
    let openProgress: CGFloat
    let handleLeanY: CGFloat

    private var m: MagneticGrabDrawerView_DrawerMetrics { MagneticGrabDrawerView_DrawerMetrics(size: size) }

    // Resolved geometry from the two driving values.
    private var clampedOpen: CGFloat { m.clampedOpen(openProgress) }
    private var handleCenter: CGPoint { m.handleCenter(open: openProgress, lean: handleLeanY) }
    private var bodyCenter: CGPoint { m.bodyCenter(open: openProgress, lean: handleLeanY) }

    var body: some View {
        ZStack {
            railGuide
            neck
            drawerBody
            handle
        }
    }

    // Faint rail showing the handle's vertical track.
    private var railGuide: some View {
        Capsule()
            .fill(Color(red: 1, green: 1, blue: 1).opacity(0.05))
            .frame(width: m.handleWidth * 0.5, height: m.height * 0.62)
            .position(x: m.handleRestX, y: m.railCenterY)
    }

    // Rubbery tether connecting handle tip to the drawer body edge.
    // MagneticGrabDrawerView_NeckShape owns its geometry (resolves endpoints from open/lean internally)
    // so its endpoints animate on the same spring as the handle/body positions.
    private var neck: some View {
        MagneticGrabDrawerView_NeckShape(
            size: size,
            open: openProgress,
            lean: handleLeanY,
            thickness: m.handleWidth * 0.9
        )
        .fill(
            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.58, blue: 0.98),
                    Color(red: 0.24, green: 0.40, blue: 0.86)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .opacity(0.92)
    }

    private var drawerBody: some View {
        RoundedRectangle(cornerRadius: min(m.bodyWidth, m.bodyHeight) * 0.18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.35, blue: 0.80),
                        Color(red: 0.14, green: 0.24, blue: 0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: min(m.bodyWidth, m.bodyHeight) * 0.18, style: .continuous)
                    .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.14), lineWidth: 1)
            )
            .overlay(drawerContent)
            .frame(width: m.bodyWidth, height: m.bodyHeight)
            .shadow(color: Color(red: 0, green: 0, blue: 0).opacity(0.35),
                    radius: 10 * clampedOpen + 2, x: 6 * clampedOpen, y: 4)
            .position(bodyCenter)
    }

    private var drawerContent: some View {
        VStack(spacing: m.bodyHeight * 0.08) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color(red: 1, green: 1, blue: 1).opacity(0.22))
                    .frame(height: max(3, m.bodyHeight * 0.05))
            }
        }
        .padding(.horizontal, m.bodyWidth * 0.18)
        .opacity(Double(min(1, clampedOpen * 1.6)))
    }

    private var handle: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.78, blue: 1.0),
                        Color(red: 0.40, green: 0.60, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color(red: 1, green: 1, blue: 1).opacity(0.30), lineWidth: 1)
            )
            .frame(width: m.handleWidth, height: m.handleHeight)
            .shadow(color: Color(red: 0.2, green: 0.4, blue: 1).opacity(0.45),
                    radius: 6, x: 0, y: 0)
            .position(handleCenter)
    }
}

// MARK: - Animatable rubber neck

private struct MagneticGrabDrawerView_NeckShape: Shape {
    var size: CGSize         // stage size, used to resolve endpoint geometry
    var open: CGFloat        // openProgress  (animated on release)
    var lean: CGFloat        // handleLeanY   (animated on release)
    var thickness: CGFloat

    // BOTH open + lean are animated on release so the spring returns the
    // drawer AND handle endpoints together, in lockstep with the handle/body
    // .position(...) — no detachment, no kink.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(open, lean) }
        set {
            open = newValue.first
            lean = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let m = MagneticGrabDrawerView_DrawerMetrics(size: size)
        // Resolve endpoints from the SAME formulas the stage uses, at the
        // currently-interpolated open/lean — so the tether tracks the spring.
        let handleTip = m.handleCenter(open: open, lean: lean)
        let body = m.bodyCenter(open: open, lean: lean)
        let bodyEdge = CGPoint(x: body.x - m.bodyWidth * 0.5, y: body.y)

        let co = max(0, m.clampedOpen(open))
        // A bowed band from handle tip to body edge. As it stretches, the waist
        // pinches (rubbery tether) and the midline bows toward the handle lean.
        let p0 = handleTip
        let p1 = bodyEdge

        // Endpoint half-thicknesses: full at the handle, slightly fuller at body.
        let h0 = thickness * 0.5
        let h1 = thickness * 0.62
        // Waist thins as the neck stretches out.
        let waist = thickness * 0.5 * (1 - min(0.6, co * 0.6))

        // Control-point bow: sag toward the lean direction so it doesn't kink.
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let midX = (p0.x + p1.x) * 0.5
        let midYTop = (p0.y + p1.y) * 0.5 - waist
        let midYBot = (p0.y + p1.y) * 0.5 + waist
        let bow = lean * (abs(dx) * 0.10 + 6)

        var path = Path()
        // Top edge: handle-top -> waist-top -> body-top
        path.move(to: CGPoint(x: p0.x, y: p0.y - h0))
        path.addQuadCurve(
            to: CGPoint(x: midX, y: midYTop + bow),
            control: CGPoint(x: p0.x + dx * 0.30, y: p0.y - h0 + dy * 0.15)
        )
        path.addQuadCurve(
            to: CGPoint(x: p1.x, y: p1.y - h1),
            control: CGPoint(x: p0.x + dx * 0.70, y: p1.y - h1)
        )
        // Body cap (down its left edge)
        path.addLine(to: CGPoint(x: p1.x, y: p1.y + h1))
        // Bottom edge: body-bottom -> waist-bottom -> handle-bottom
        path.addQuadCurve(
            to: CGPoint(x: midX, y: midYBot + bow),
            control: CGPoint(x: p0.x + dx * 0.70, y: p1.y + h1)
        )
        path.addQuadCurve(
            to: CGPoint(x: p0.x, y: p0.y + h0),
            control: CGPoint(x: p0.x + dx * 0.30, y: p0.y + h0 + dy * 0.15)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Utility

private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    min(max(v, lo), hi)
}
