// catalog-id: mi-tactile-counter-flip
import SwiftUI

// MARK: - Tactile Like Counter Flip
// A reaction count where the new digit slides up on a hinged flap from behind
// the old one with a split-flap snap and a tiny dust puff.
//
// demo == true  -> self-driving TimelineView loop auto-increments the count,
//                  playing the single hinged flap snap + dust puff on each tick.
// demo == false -> a tappable like button increments the count, driving the same flip.

struct TactileCounterFlipView: View {

    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let unit = min(size.width, size.height)

            ZStack {
                backdrop
                Group {
                    if demo {
                        TactileCounterFlipView_DemoLoop(unit: unit)
                    } else {
                        TactileCounterFlipView_Interactive(unit: unit)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.08, blue: 0.13),
                Color(red: 0.05, green: 0.04, blue: 0.07)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Demo (self-driving)

private struct TactileCounterFlipView_DemoLoop: View {
    let unit: CGFloat

    // Loop timing: a full cycle is `cycle` seconds; the flip happens in the
    // last `flipDur` seconds. The count increments once per cycle.
    private let cycle: Double = 3.0
    private let flipDur: Double = 0.7
    private let baseCount: Int = 1247

    // Anchor the loop to when this view appeared so the count starts near
    // `baseCount` instead of being derived from absolute reference time
    // (which would render a ~9-digit number).
    @State private var epoch: Double = Date().timeIntervalSinceReferenceDate

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = max(0, now - epoch)
            let phase = elapsed.truncatingRemainder(dividingBy: cycle)
            let completed = Int(elapsed / cycle)

            // Flip window sits at the end of the cycle.
            let flipStart = cycle - flipDur
            let inFlip = phase >= flipStart
            let rawProgress = inFlip ? (phase - flipStart) / flipDur : 0.0
            let progress = flipEase(rawProgress)

            // Before the flip lands the card still reads the "from" value;
            // once we cross into a new cycle the increment is already baked in.
            let fromValue = baseCount + completed
            let toValue = fromValue + 1

            // Time since the flap snapped to 90 degrees (mid-cycle), for the puff.
            let landPhase = flipStart + flipDur * 0.5
            let sinceLand = phase - landPhase

            TactileCounterFlipView_FlipCounter(
                unit: unit,
                fromValue: fromValue,
                toValue: toValue,
                progress: progress,
                puffSinceLand: sinceLand,
                pressGlow: inFlip ? 1.0 : 0.0
            )
        }
    }

    // Mechanical ease: quick fall, then a tiny settle handled by the card itself.
    private func flipEase(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return 1 - pow(1 - c, 2.4)
    }
}

// MARK: - TactileCounterFlipView_Interactive (tap to like)

private struct TactileCounterFlipView_Interactive: View {
    let unit: CGFloat

    @State private var value: Int = 1247
    @State private var fromValue: Int = 1247
    @State private var progress: Double = 0
    @State private var puffSinceLand: Double = -1
    @State private var pressGlow: Double = 0
    @State private var liked: Bool = false
    @State private var puffTrigger: Int = 0

    var body: some View {
        ZStack {
            TactileCounterFlipView_FlipCounter(
                unit: unit,
                fromValue: fromValue,
                toValue: fromValue + 1,
                progress: progress,
                puffSinceLand: puffSinceLand,
                pressGlow: pressGlow
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { trigger() }
        .sensoryFeedback(.impact(weight: .light), trigger: puffTrigger)
    }

    private func trigger() {
        // Don't stack flips on top of one another mid-animation.
        guard progress == 0 || progress >= 1 else { return }

        liked.toggle()
        fromValue = value
        progress = 0
        pressGlow = 1

        // Drop the flap (0 -> 1) with a snappy mechanical curve.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
            progress = 1
        }

        // Fire the dust puff at the mid-point when the flap "lands".
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            value += 1
            puffTrigger += 1
            animatePuff()
        }

        // Reset for the next tap once the settle finishes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            progress = 0
            withAnimation(.easeOut(duration: 0.3)) { pressGlow = 0 }
        }
    }

    private func animatePuff() {
        puffSinceLand = 0
        let start = Date()
        // Drive the puff fade with a short manual ticker.
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { tmr in
            let elapsed = Date().timeIntervalSince(start)
            puffSinceLand = elapsed
            if elapsed > 0.55 {
                tmr.invalidate()
                puffSinceLand = -1
            }
        }
    }
}

// MARK: - Shared flip card

/// Renders the split-flap counter for a given flip `progress` (0...1).
/// At rest (progress 0 or 1) the flap and background read the same digit so it
/// looks static; mid-flip the background already shows the NEW value while the
/// flap (the OLD value's top half) hinges down to reveal it.
private struct TactileCounterFlipView_FlipCounter: View {
    let unit: CGFloat
    let fromValue: Int
    let toValue: Int
    let progress: Double        // 0 = closed (shows from), 1 = open (shows to)
    let puffSinceLand: Double    // seconds since flap snapped; < 0 = no puff
    let pressGlow: Double        // 0...1 extra glow while active

    var body: some View {
        let cardW = unit * 0.62
        let cardH = unit * 0.56
        let corner = cardH * 0.16

        // Once the flap passes the half-way point the new value is committed.
        let committed = progress >= 0.5
        let backgroundValue = committed ? toValue : fromValue
        let flapShowsValue = fromValue

        // Flap rotation 0 -> 90 degrees, clamped so the backface never mirrors.
        let angle = min(progress, 1.0) * 90.0
        let flapHidden = progress >= 0.999

        VStack(spacing: cardH * 0.18) {
            heart(size: unit * 0.16)
            ZStack {
                // The static back card painting the current/destination digit.
                cardFace(value: backgroundValue, w: cardW, h: cardH, corner: corner)

                // Center seam.
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: cardW, height: max(1, cardH * 0.012))

                // The falling flap: OLD value's TOP half hinging down from the top.
                // The flap view is half-card-height; rotate it about its OWN bottom
                // edge (the card's center seam), then pin it to the top of the card.
                if !flapHidden {
                    topHalf(value: flapShowsValue, w: cardW, h: cardH, corner: corner)
                        .rotation3DEffect(
                            .degrees(angle),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .bottom,
                            perspective: 0.55
                        )
                        .shadow(color: .black.opacity(0.35 * progress), radius: 4, y: 3)
                        // Pin the half-height flap to the top half of the card.
                        .frame(width: cardW, height: cardH, alignment: .top)
                }

                // Dust puff at the hinge line on snap.
                TactileCounterFlipView_DustPuff(since: puffSinceLand, width: cardW)
                    .frame(width: cardW, height: cardH * 0.5, alignment: .bottom)
                    .offset(y: -cardH * 0.02)
            }
            .frame(width: cardW, height: cardH)
            .shadow(color: warmGlow.opacity(0.45 * pressGlow), radius: 14)
            .compositingGroup()

            label(size: unit * 0.085)
        }
    }

    // MARK: card faces

    private func cardFace(value: Int, w: CGFloat, h: CGFloat, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .overlay(digitText(value).frame(width: w, height: h))
            .frame(width: w, height: h)
    }

    /// The top half of a card showing `value`: a full card clipped to its upper half.
    private func topHalf(value: Int, w: CGFloat, h: CGFloat, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(flapGradient)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(digitText(value).frame(width: w, height: h))
            .frame(width: w, height: h)
            // Keep only the upper half.
            .frame(height: h * 0.5, alignment: .top)
            .clipped()
    }

    private func digitText(_ value: Int) -> some View {
        Text(formatted(value))
            .font(.system(size: unit * 0.30, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.97, blue: 0.92),
                             Color(red: 0.86, green: 0.83, blue: 0.80)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .minimumScaleFactor(0.3)
            .lineLimit(1)
    }

    // Show the full integer (with grouping) so a single +1 visibly flips the
    // last digit. A "k"-rounded format would make consecutive counts identical.
    private func formatted(_ value: Int) -> String {
        var result = ""
        let digits = Array(String(abs(value)))
        let count = digits.count
        for (i, ch) in digits.enumerated() {
            if i > 0 && (count - i) % 3 == 0 {
                result.append(",")
            }
            result.append(ch)
        }
        return value < 0 ? "-" + result : result
    }

    // MARK: chrome

    private func heart(size: CGFloat) -> some View {
        let beat = 1.0 + 0.12 * pressGlow
        return Image(systemName: "heart.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.42, blue: 0.52),
                             Color(red: 0.95, green: 0.25, blue: 0.42)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .scaleEffect(beat)
            .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.45).opacity(0.6 * pressGlow),
                    radius: 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pressGlow)
    }

    private func label(size: CGFloat) -> some View {
        Text("LIKES")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(size * 0.35)
            .foregroundStyle(Color.white.opacity(0.4))
    }

    // MARK: palettes

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.20, green: 0.17, blue: 0.24),
                     Color(red: 0.12, green: 0.10, blue: 0.15)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var flapGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.24, green: 0.21, blue: 0.28),
                     Color(red: 0.17, green: 0.14, blue: 0.20)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var warmGlow: Color {
        Color(red: 1.0, green: 0.55, blue: 0.45)
    }
}

// MARK: - Dust puff (Canvas, fully derived from `since`)

private struct TactileCounterFlipView_DustPuff: View {
    let since: Double   // seconds since the flap landed; < 0 means inactive
    let width: CGFloat

    // Fixed particle directions so the puff is deterministic and cheap.
    private let dirs: [CGPoint] = [
        CGPoint(x: -1.0, y: -0.2), CGPoint(x: -0.6, y: -0.6),
        CGPoint(x: -0.2, y: -0.9), CGPoint(x:  0.2, y: -0.9),
        CGPoint(x:  0.6, y: -0.6), CGPoint(x:  1.0, y: -0.2),
        CGPoint(x: -0.85, y: 0.1), CGPoint(x:  0.85, y: 0.1)
    ]

    var body: some View {
        Canvas { ctx, size in
            guard since >= 0 else { return }
            let life = 0.5
            let p = min(max(since / life, 0), 1)
            guard p < 1 else { return }

            let opacity = (1.0 - p) * 0.8
            let spread = width * 0.42 * p
            let originX = size.width * 0.5
            let originY = size.height          // hinge line at the bottom of this band
            let r = max(0.6, width * 0.018 * (1.0 - 0.4 * p))

            for d in dirs {
                let cx = originX + CGFloat(d.x) * spread
                let cy = originY + CGFloat(d.y) * spread
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.86, green: 0.82, blue: 0.78).opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
