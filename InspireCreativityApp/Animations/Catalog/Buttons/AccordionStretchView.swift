// catalog-id: btn-accordion-stretch
import SwiftUI

// MARK: - Accordion Stretch
// Pinch the button to concertina it open into a bellows of accordion pleats that
// spread apart revealing nested options, collapsing back when released.
//
// demo == true  -> a self-driving TimelineView loops the expansion 0->1->0 on a
//                  ~3.2s sine so the pleats keep folding open/closed and each fold's
//                  gradient glints as its angle changes. Never blank: progress=0 is a
//                  fully legible button face.
// demo == false -> the real interactive component: a MagnifyGesture maps the live
//                  magnification to expansion progress (clamped 0-1); fold angles and
//                  gaps interpolate per frame; release springs to fully open or
//                  collapsed with impact feedback.
//
// iOS 17. SwiftUI only. No external dependencies.

struct AccordionStretchView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if demo {
                    AutoDrivenAccordion(size: geo.size)
                } else {
                    InteractiveAccordion(size: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Auto-driven (demo) container

private struct AutoDrivenAccordion: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let progress = AccordionMath.loopProgress(at: t)
            AccordionBellows(progress: progress, size: size)
        }
    }
}

// MARK: - Interactive container

private struct InteractiveAccordion: View {
    let size: CGSize

    @State private var base: Double = 0          // committed open amount (0 or 1)
    @State private var live: Double = 0          // live progress while pinching
    @State private var pinching: Bool = false
    @State private var snapTick: Int = 0         // drives sensory feedback on snap

    private var progress: Double { pinching ? live : base }

    var body: some View {
        AccordionBellows(progress: progress, size: size)
            .contentShape(Rectangle())
            .gesture(magnify)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: snapTick)
    }

    private var magnify: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                pinching = true
                // (magnification - 1) is ~0 at rest; scale it so a comfortable
                // pinch range maps across the full 0...1 expansion.
                let delta = (value.magnification - 1.0) * 1.4
                live = AccordionMath.clamp(base + delta)
            }
            .onEnded { _ in
                pinching = false
                let target: Double = live > 0.5 ? 1 : 0
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    base = target
                }
                snapTick &+= 1
            }
    }
}

// MARK: - The bellows itself

private struct AccordionBellows: View {
    let progress: Double          // 0 = closed button, 1 = fully spread
    let size: CGSize

    private let pleatCount = 6    // capped for perf (spec risk: <= ~8)

    private let options: [PleatOption] = [
        PleatOption(title: "Share",     systemImage: "square.and.arrow.up"),
        PleatOption(title: "Duplicate", systemImage: "plus.square.on.square"),
        PleatOption(title: "Favorite",  systemImage: "star"),
        PleatOption(title: "Archive",   systemImage: "archivebox"),
        PleatOption(title: "Delete",    systemImage: "trash")
    ]

    var body: some View {
        // Geometry-relative sizing so it works in a 120pt tile AND a big detail area.
        let unit = min(size.width, size.height)
        let pleatHeight = unit * 0.115
        let maxGap = unit * 0.085
        let gap = maxGap * progress
        let pleatWidth = min(size.width * 0.78, unit * 1.4)

        VStack(spacing: gap) {
            ForEach(0..<pleatCount, id: \.self) { i in
                pleat(index: i, width: pleatWidth, height: pleatHeight)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func pleat(index i: Int, width: CGFloat, height: CGFloat) -> some View {
        let downward = i % 2 == 0
        // Fold angle opens up as progress grows. Zigzag: even pleats hinge on their
        // top edge, odd pleats on their bottom edge -> a true concertina.
        let angle = AccordionMath.foldAngle(progress)
        let signed = downward ? angle : -angle
        let anchor: UnitPoint = downward ? .top : .bottom

        ZStack {
            PleatShape()
                .fill(AccordionMath.pleatGradient(angle: signed, index: i))
                .overlay(
                    PleatShape()
                        .stroke(Color.white.opacity(0.10 + 0.18 * progress), lineWidth: 0.8)
                )
                .overlay(glint(angle: signed))

            pleatLabel(index: i)
                .opacity(labelOpacity(for: i))
        }
        .frame(width: width, height: height)
        .rotation3DEffect(
            .degrees(signed),
            axis: (x: 1, y: 0, z: 0),
            anchor: anchor,
            perspective: 0.55
        )
        .shadow(color: .black.opacity(0.28 * progress), radius: 3 * progress, y: 2 * progress)
    }

    // The center pleat carries the resting button label; flanking pleats reveal
    // nested option rows as the gaps widen.
    @ViewBuilder
    private func pleatLabel(index i: Int) -> some View {
        if i == pleatCount / 2 {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                Text("Actions")
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        } else {
            let option = options[optionIndex(for: i)]
            HStack(spacing: 6) {
                Image(systemName: option.systemImage)
                Text(option.title)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    private func optionIndex(for i: Int) -> Int {
        let mid = pleatCount / 2
        let distance = i < mid ? (mid - i) : (i - mid)
        return (distance - 1 + options.count) % options.count
    }

    // The middle (button) label is always legible; option labels fade in with the spread.
    private func labelOpacity(for i: Int) -> Double {
        if i == pleatCount / 2 { return 1 }
        let reveal = AccordionMath.smoothstep(0.18, 0.85, progress)
        return reveal
    }

    // A travelling specular streak whose brightness tracks the absolute fold angle,
    // so each pleat catches light as it opens.
    @ViewBuilder
    private func glint(angle: Double) -> some View {
        let strength = AccordionMath.smoothstep(2, 30, abs(angle))
        LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.45 * strength),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

// MARK: - Pleat option model

private struct PleatOption {
    let title: String
    let systemImage: String
}

// MARK: - Trapezoidal pleat shape

private struct PleatShape: Shape {
    func path(in rect: CGRect) -> Path {
        // A soft trapezoid (narrower top) gives the strip a bellows-panel silhouette.
        let inset = rect.width * 0.06
        let r = min(rect.height, rect.width) * 0.16
        var p = Path()

        let tl = CGPoint(x: rect.minX + inset, y: rect.minY)
        let tr = CGPoint(x: rect.maxX - inset, y: rect.minY)
        let br = CGPoint(x: rect.maxX, y: rect.maxY)
        let bl = CGPoint(x: rect.minX, y: rect.maxY)

        p.move(to: CGPoint(x: tl.x + r, y: tl.y))
        p.addLine(to: CGPoint(x: tr.x - r, y: tr.y))
        p.addQuadCurve(to: CGPoint(x: tr.x, y: tr.y + r), control: tr)
        p.addLine(to: CGPoint(x: br.x, y: br.y - r))
        p.addQuadCurve(to: CGPoint(x: br.x - r, y: br.y), control: br)
        p.addLine(to: CGPoint(x: bl.x + r, y: bl.y))
        p.addQuadCurve(to: CGPoint(x: bl.x, y: bl.y - r), control: bl)
        p.addLine(to: CGPoint(x: tl.x, y: tl.y + r))
        p.addQuadCurve(to: CGPoint(x: tl.x + r, y: tl.y), control: tl)
        p.closeSubpath()
        return p
    }
}

// MARK: - Math + palette helpers

private enum AccordionMath {

    static func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double {
        min(hi, max(lo, v))
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = clamp((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    // ~3.2s sine loop, eased, oscillating 0 -> 1 -> 0. Never parks at a degenerate 0.
    static func loopProgress(at t: TimeInterval) -> Double {
        let period = 3.2
        let phase = (t.truncatingRemainder(dividingBy: period)) / period   // 0..1
        let raw = 0.5 - 0.5 * cos(phase * 2 * Double.pi)                    // 0..1..0
        // ease so it dwells a touch at the open and closed ends
        return smoothstep(0, 1, raw)
    }

    // Max fold opening in degrees at full progress.
    static func foldAngle(_ progress: Double) -> Double {
        38.0 * progress
    }

    // Per-pleat gradient whose brightness shifts with the (signed) fold angle to fake
    // light catching each fold. Warm amber base keyed to the tile tint (#16120e).
    static func pleatGradient(angle: Double, index: Int) -> LinearGradient {
        let lift = clamp(0.5 + angle / 60.0)            // 0..1, brighter as it tilts open
        let top = Color(hexCode: 0xF2B45A).opacity(0.55 + 0.4 * lift)
        let bottom = Color(hexCode: 0x6E3D14).opacity(0.85 - 0.25 * lift)
        return LinearGradient(
            colors: [top, bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Hex color (self-contained)

private extension Color {
    init(hexCode hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Preview
