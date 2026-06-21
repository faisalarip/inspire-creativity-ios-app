// catalog-id: mi-punchout-check
import SwiftUI

// MARK: - Punch-Out Check
// A filled chip flips on its Y axis and a checkmark appears as negative space
// punched THROUGH the card (blendMode(.destinationOut) inside a compositingGroup),
// with light leaking through the cut edges via a gradient stroke layered on top.
//
// demo == true  -> a self-driving TimelineView loop: flips front -> punched (with a
//                  legible dwell so the check can be read) -> back, forever.
// demo == false -> tap toggles the flip with a spring settle (interaction == tap).
//
// The back face is counter-mirrored (scaleEffect(x:-1)) so the asymmetric checkmark
// reads FORWARD at the resting punched state rather than backwards.
struct PunchoutCheckView: View {
    var demo: Bool = false

    @State private var flipped: Bool = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            let chip = max(40, side)

            ZStack {
                if demo {
                    autoDrivenChip(size: chip)
                } else {
                    interactiveChip(size: chip)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backdrop)
    }

    // MARK: Backdrop (persistent so the hole has something to leak through, and the
    // tile is never truly empty even at the edge-on flip frame).
    private var backdrop: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.10, green: 0.09, blue: 0.16),
                    Color(red: 0.05, green: 0.05, blue: 0.09)
                ],
                center: .center,
                startRadius: 2,
                endRadius: 260
            )
            // Faint glow that shows through the punched check.
            Circle()
                .fill(Color(red: 0.45, green: 0.85, blue: 0.62).opacity(0.10))
                .blur(radius: 40)
                .frame(width: 120, height: 120)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Auto-driven (demo) loop
private extension PunchoutCheckView {
    func autoDrivenChip(size: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = loopAngle(at: t)
            chipFace(size: size, angle: angle)
        }
    }

    // Time -> angle in degrees over a ~4s loop with flat dwells so each
    // legible state (solid front, punched back) holds long enough to read.
    //
    // Segments (period = 4.0s):
    //   0.00 .. 0.60  hold front (angle 0)
    //   0.60 .. 1.50  flip to punched (0 -> 180), easeInOut
    //   1.50 .. 2.60  dwell punched (angle 180)   <- check is legible here
    //   2.60 .. 3.50  flip back (180 -> 0), easeInOut
    //   3.50 .. 4.00  hold front (angle 0)
    func loopAngle(at time: TimeInterval) -> Double {
        let period: Double = 4.0
        let p = time.truncatingRemainder(dividingBy: period)

        if p < 0.60 {
            return 0
        } else if p < 1.50 {
            let local = (p - 0.60) / 0.90
            return 180.0 * easeInOut(local)
        } else if p < 2.60 {
            return 180
        } else if p < 3.50 {
            let local = (p - 2.60) / 0.90
            return 180.0 * (1.0 - easeInOut(local))
        } else {
            return 0
        }
    }

    func easeInOut(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3.0 - 2.0 * c)
    }
}

// MARK: - Interactive (tap) variant
private extension PunchoutCheckView {
    func interactiveChip(size: CGFloat) -> some View {
        let angle: Double = flipped ? 180 : 0
        return chipFace(size: size, angle: angle)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                    flipped.toggle()
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: flipped)
    }
}

// MARK: - The flipping chip (shared)
private extension PunchoutCheckView {
    /// Renders the chip at a given Y-rotation. Two faces:
    ///  - Front (angle < 90): a solid, un-punched chip.
    ///  - Back  (angle >= 90): the punched chip, counter-mirrored so the check reads forward.
    func chipFace(size: CGFloat, angle: Double) -> some View {
        let showingBack = angle >= 90
        // How far "settled" into the back state we are (0 at edge-on, 1 fully punched)
        // used to ramp the edge light leaking through the cut.
        let settle = backSettle(angle: angle)

        return ZStack {
            // Soft drop shadow / pad behind the card so depth reads during the flip.
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(width: size, height: size)
                .blur(radius: 14)
                .offset(y: size * 0.08)
                .opacity(0.9)

            // FRONT FACE — solid chip, visible on the first half of the flip.
            frontFace(size: size)
                .opacity(showingBack ? 0 : 1)

            // BACK FACE — punched chip + leaking edge light, counter-mirrored
            // so the asymmetric check is not reversed at rest.
            backFace(size: size, settle: settle)
                .scaleEffect(x: -1, y: 1) // un-mirror the back of a Y-flip
                .opacity(showingBack ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
    }

    /// 0 at the 90-degree edge-on frame, ramping to 1 by ~150 degrees, so the
    /// light through the cut edges fades in as the card settles into the check.
    func backSettle(angle: Double) -> Double {
        guard angle > 90 else { return 0 }
        let v = (angle - 90.0) / 60.0
        return min(max(v, 0), 1)
    }
}

// MARK: - Faces
private extension PunchoutCheckView {
    func frontFace(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(chipGradient)
            // Glossy top sheen for a tactile, physical card feel.
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }

    func backFace(size: CGFloat, settle: Double) -> some View {
        ZStack {
            // The punched card: fill + check-shaped hole, composited flat BEFORE
            // it sits in the rotated context. The hole clears alpha so the tile
            // background (and glow) leaks through.
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(chipGradientBack)
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                PunchoutCheckView_CheckShape()
                    .path(in: checkRect(size: size))
                    .fill(Color.black)
                    .blendMode(.destinationOut) // punch the hole
            }
            .compositingGroup() // REQUIRED for destinationOut to cut the layers above
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )

            // Light leaking through the CUT EDGES — layered OUTSIDE the
            // compositingGroup (otherwise destinationOut would erase it too).
            PunchoutCheckView_CheckShape()
                .path(in: checkRect(size: size))
                .stroke(edgeLightGradient, lineWidth: max(1.5, size * 0.018))
                .blur(radius: 0.6)
                .opacity(0.35 + 0.65 * settle)
                .shadow(color: Color(red: 0.55, green: 1.0, blue: 0.72).opacity(0.5 * settle), radius: 4)
        }
        .frame(width: size, height: size)
    }

    func checkRect(size: CGFloat) -> CGRect {
        let inset = size * 0.26
        return CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    }
}

// MARK: - Palette
private extension PunchoutCheckView {
    var chipGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.32, green: 0.78, blue: 0.55),
                Color(red: 0.16, green: 0.55, blue: 0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var chipGradientBack: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.28, green: 0.72, blue: 0.52),
                Color(red: 0.12, green: 0.46, blue: 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var edgeLightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.75, green: 1.0, blue: 0.85),
                Color(red: 0.40, green: 0.95, blue: 0.70),
                Color(red: 0.85, green: 1.0, blue: 0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Checkmark shape (asymmetric — the counter-mirror correctness gate)
private struct PunchoutCheckView_CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // Three points of a tick, expressed as fractions of the rect.
        let p1 = CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.55)
        let p2 = CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.84)
        let p3 = CGPoint(x: rect.minX + w * 0.92, y: rect.minY + h * 0.18)
        p.move(to: p1)
        p.addLine(to: p2)
        p.addLine(to: p3)
        // Give the punched hole real thickness by tracing back with an offset,
        // so destinationOut clears a band rather than a hairline.
        let t = min(w, h) * 0.16
        let p3b = CGPoint(x: p3.x, y: p3.y + t)
        let p2b = CGPoint(x: p2.x, y: p2.y + t * 0.55)
        let p1b = CGPoint(x: p1.x, y: p1.y + t)
        p.addLine(to: p3b)
        p.addLine(to: p2b)
        p.addLine(to: p1b)
        p.closeSubpath()
        return p
    }
}
