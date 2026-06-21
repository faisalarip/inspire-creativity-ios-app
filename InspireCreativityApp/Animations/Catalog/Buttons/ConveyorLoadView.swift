// catalog-id: btn-conveyor-load
import SwiftUI

/// Conveyor Load — a loading button whose progress is a literal assembly line:
/// crates ride a scrolling belt across the face and drop into a bin, incrementing
/// a counter until the run completes and the belt halts.
///
/// - `demo == true`  : self-driving TimelineView loop (~3.2s) that endlessly ferries
///                      crates and resets, never blank on any frame.
/// - `demo == false` : tap starts a real loading run for N crates; tapping again
///                      while complete resets to idle. `sensoryFeedback(.success)`
///                      fires when the count finishes (interactive path only).
struct ConveyorLoadView: View {
    var demo: Bool = false

    // MARK: Tunables
    private let crateCount: Int = 6
    private let runDuration: Double = 3.2          // seconds for a full N-crate run
    private let demoLoopDuration: Double = 3.2     // self-driving loop period
    private let beltSpeed: CGFloat = 64            // points / second of belt scroll

    // MARK: Interactive state
    @State private var startDate: Date? = nil      // nil == idle / resting

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            demoBody(in: size)
        } else {
            interactiveBody(in: size)
        }
    }

    // MARK: - Demo (self-driving, visual only — no haptics)

    private func demoBody(in size: CGSize) -> some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let loop = (t.truncatingRemainder(dividingBy: demoLoopDuration)) / demoLoopDuration
            let elapsed = loop * runDuration
            machine(in: size, elapsed: elapsed, runProgress: loop)
        }
    }

    // MARK: - Interactive

    private func interactiveBody(in size: CGSize) -> some View {
        TimelineView(.animation) { context in
            let elapsed = elapsedTime(now: context.date)
            let progress = min(elapsed / runDuration, 1.0)
            let complete = progress >= 1.0
            machine(in: size, elapsed: elapsed, runProgress: progress)
                .contentShape(Rectangle())
                .onTapGesture { handleTap(complete: complete) }
                .sensoryFeedback(.success, trigger: complete) { old, new in
                    // Only the false -> true edge of a real run fires.
                    !old && new && startDate != nil
                }
        }
    }

    private func elapsedTime(now: Date) -> Double {
        guard let start = startDate else { return 0 }
        return max(0, now.timeIntervalSince(start))
    }

    private func handleTap(complete: Bool) {
        if startDate == nil {
            startDate = Date()            // begin a run
        } else if complete {
            startDate = nil               // reset to idle
        }
        // taps mid-run are ignored — belt keeps running
    }

    // MARK: - Shared scene

    private func machine(in size: CGSize, elapsed: Double, runProgress: Double) -> some View {
        let m = Metrics(size: size, crateCount: crateCount)
        let beltOffset = -CGFloat((elapsed * Double(beltSpeed)))
            .truncatingRemainder(dividingBy: m.crateSpacing)
        let dropped = min(crateCount, Int(floor(runProgress * Double(crateCount) + 0.0001)))
        let idle = !demo && startDate == nil
        let complete = runProgress >= 1.0

        return ZStack {
            housing(m: m)
            beltSurface(m: m, beltOffset: beltOffset)
            crates(m: m, beltOffset: beltOffset, runProgress: runProgress)
                .mask(beltWindow(m: m))
            bin(m: m, dropped: dropped, pulse: complete && !idle)
            label(m: m, idle: idle, complete: complete, dropped: dropped)
        }
        .compositingGroup()
    }

    // MARK: - Housing

    private func housing(m: Metrics) -> some View {
        RoundedRectangle(cornerRadius: m.corner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.13, blue: 0.10),
                        Color(red: 0.10, green: 0.08, blue: 0.06)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: m.corner, style: .continuous)
                    .strokeBorder(Color(red: 0.42, green: 0.35, blue: 0.26).opacity(0.55),
                                  lineWidth: max(1, m.unit * 0.4))
            )
            .shadow(color: .black.opacity(0.35), radius: m.unit, y: m.unit * 0.4)
    }

    // MARK: - Belt

    private func beltWindow(m: Metrics) -> some View {
        RoundedRectangle(cornerRadius: m.beltCorner, style: .continuous)
            .frame(width: m.beltWidth, height: m.beltHeight)
            .position(x: m.beltMidX, y: m.beltY)
    }

    private func beltSurface(m: Metrics, beltOffset: CGFloat) -> some View {
        let tread = 6
        return ZStack {
            RoundedRectangle(cornerRadius: m.beltCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.20, blue: 0.22),
                            Color(red: 0.11, green: 0.11, blue: 0.13)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: m.beltWidth, height: m.beltHeight)
                .position(x: m.beltMidX, y: m.beltY)

            // Moving tread chevrons so the belt visibly runs.
            ForEach(0..<tread, id: \.self) { i in
                let span = m.beltWidth + m.crateSpacing
                let step = span / CGFloat(tread)
                let raw = CGFloat(i) * step + beltOffset
                let x = m.beltLeading + raw.truncatingRemainder(dividingBy: span)
                let wrapped = x < m.beltLeading ? x + span : x
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: max(1.5, m.unit * 0.55), height: m.beltHeight * 0.7)
                    .rotationEffect(.degrees(20))
                    .position(x: wrapped, y: m.beltY)
            }
        }
        .mask(beltWindow(m: m))
    }

    // MARK: - Crates

    private func crates(m: Metrics, beltOffset: CGFloat, runProgress: Double) -> some View {
        // Render enough crates to cover the belt plus a buffer each side.
        let visible = Int(ceil(m.beltWidth / m.crateSpacing)) + 3
        return ForEach(0..<visible, id: \.self) { i in
            crate(index: i, m: m, beltOffset: beltOffset, runProgress: runProgress)
        }
    }

    @ViewBuilder
    private func crate(index i: Int, m: Metrics, beltOffset: CGFloat, runProgress: Double) -> some View {
        // Base x as crates march left; wrap into the belt span.
        let span = m.crateSpacing * CGFloat(Int(ceil(m.beltWidth / m.crateSpacing)) + 3)
        let base = m.beltLeading + CGFloat(i) * m.crateSpacing + m.crateSpacing * 0.5
        let raw = (base + beltOffset - m.beltLeading).truncatingRemainder(dividingBy: span)
        let x = m.beltLeading + (raw < 0 ? raw + span : raw)

        // Drop zone: when a crate's center passes the bin mouth, it tips into the bin.
        let dropStart = m.binMouthX
        let dropEnd = m.binMouthX - m.crateSpacing * 0.85
        let dropT = clamp((dropStart - x) / max(1, dropStart - dropEnd))
        let dropping = x <= dropStart && x >= dropEnd - m.crateSpacing
        let drop = easeIn(dropT)

        // Past the bin entirely -> hidden (already collected).
        let collected = x < dropEnd - 2

        let yOffset = drop * m.dropDistance
        let scale = 1.0 - drop * 0.55
        let opacity = collected ? 0.0 : (1.0 - drop * 0.65)
        let rot = drop * 32

        crateBody(m: m, hue: Double(i % 3))
            .scaleEffect(scale)
            .rotationEffect(.degrees(rot))
            .position(x: x, y: m.beltCrateY + yOffset)
            .opacity(opacity)
    }

    private func crateBody(m: Metrics, hue: Double) -> some View {
        let palette: [(Color, Color)] = [
            (Color(red: 0.85, green: 0.62, blue: 0.30), Color(red: 0.66, green: 0.44, blue: 0.18)),
            (Color(red: 0.78, green: 0.50, blue: 0.34), Color(red: 0.58, green: 0.34, blue: 0.20)),
            (Color(red: 0.90, green: 0.74, blue: 0.46), Color(red: 0.70, green: 0.54, blue: 0.28))
        ]
        let pair = palette[Int(hue) % palette.count]
        let s = m.crateSize
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .fill(
                    LinearGradient(colors: [pair.0, pair.1],
                                   startPoint: .top, endPoint: .bottom)
                )
            // Cross-strap so it reads as a parcel/crate, not a plain square.
            RoundedRectangle(cornerRadius: s * 0.16, style: .continuous)
                .strokeBorder(Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.7),
                              lineWidth: max(1, s * 0.06))
            Rectangle()
                .fill(Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.45))
                .frame(width: s * 0.12)
            Rectangle()
                .fill(Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.45))
                .frame(height: s * 0.12)
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: s * 0.22, height: s * 0.22)
                .offset(x: -s * 0.22, y: -s * 0.22)
        }
        .frame(width: s, height: s)
    }

    // MARK: - Bin

    private func bin(m: Metrics, dropped: Int, pulse: Bool) -> some View {
        let fill = CGFloat(dropped) / CGFloat(max(1, crateCount))
        return ZStack(alignment: .bottom) {
            // Back wall + fill level.
            RoundedRectangle(cornerRadius: m.binCorner, style: .continuous)
                .fill(Color(red: 0.07, green: 0.06, blue: 0.05))
                .frame(width: m.binWidth, height: m.binHeight)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: m.binCorner * 0.6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.86, green: 0.64, blue: 0.32),
                                    Color(red: 0.62, green: 0.42, blue: 0.18)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: max(0, m.binHeight * 0.92 * fill))
                        .padding(.horizontal, m.unit * 0.6)
                        .padding(.bottom, m.unit * 0.5)
                        .animation(.spring(response: 0.34, dampingFraction: 0.6), value: dropped)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: m.binCorner, style: .continuous)
                        .strokeBorder(Color(red: 0.45, green: 0.36, blue: 0.24),
                                      lineWidth: max(1, m.unit * 0.4))
                )
        }
        .frame(width: m.binWidth, height: m.binHeight)
        .scaleEffect(pulse ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulse)
        .position(x: m.binCenterX, y: m.binCenterY)
    }

    // MARK: - Label / status

    @ViewBuilder
    private func label(m: Metrics, idle: Bool, complete: Bool, dropped: Int) -> some View {
        let (text, icon): (String, String) = {
            if idle { return ("Tap to load", "shippingbox.fill") }
            if complete { return ("Loaded", "checkmark.circle.fill") }
            return ("\(dropped)/\(crateCount)", "arrow.triangle.2.circlepath")
        }()

        HStack(spacing: m.unit * 0.6) {
            Image(systemName: icon)
                .font(.system(size: m.statusFont * 0.95, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .rotationEffect(.degrees(complete || idle ? 0 : 0))
            Text(text)
                .font(.system(size: m.statusFont, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(complete
                         ? Color(red: 0.55, green: 0.85, blue: 0.55)
                         : Color(red: 0.96, green: 0.92, blue: 0.84))
        .padding(.horizontal, m.unit * 1.4)
        .padding(.vertical, m.unit * 0.7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .position(x: m.statusX, y: m.statusY)
    }

    // MARK: - Helpers

    private func clamp(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
    private func easeIn(_ t: CGFloat) -> CGFloat { t * t }

    // MARK: - Layout metrics (single source of geometry)

    struct Metrics {
        let size: CGSize
        let unit: CGFloat
        let corner: CGFloat

        // belt
        let beltWidth: CGFloat
        let beltHeight: CGFloat
        let beltY: CGFloat
        let beltCorner: CGFloat
        let beltLeading: CGFloat
        let beltMidX: CGFloat
        let beltCrateY: CGFloat

        // crates
        let crateSize: CGFloat
        let crateSpacing: CGFloat
        let dropDistance: CGFloat

        // bin
        let binWidth: CGFloat
        let binHeight: CGFloat
        let binCenterX: CGFloat
        let binCenterY: CGFloat
        let binCorner: CGFloat
        let binMouthX: CGFloat

        // status
        let statusX: CGFloat
        let statusY: CGFloat
        let statusFont: CGFloat

        init(size: CGSize, crateCount: Int) {
            self.size = size
            let minSide = min(size.width, size.height)
            let u = minSide / 18.0
            self.unit = u
            self.corner = minSide * 0.18

            let binW = size.width * 0.20
            self.binWidth = binW
            self.binHeight = size.height * 0.46
            self.binCenterX = size.width - binW * 0.62 - u
            self.binCenterY = size.height * 0.56
            self.binCorner = binW * 0.22
            self.binMouthX = binCenterX - binW * 0.2

            let beltInsetLeading = u * 1.4
            let beltRight = binCenterX - binW * 0.5 - u * 0.4
            self.beltLeading = beltInsetLeading
            // Guard the belt width so divisors are never zero when the
            // GeometryReader proposes a transient .zero size (avoids
            // Int(ceil(0/0)) == Int(NaN) crash downstream).
            self.beltWidth = max(1, beltRight - beltInsetLeading)
            self.beltHeight = size.height * 0.16
            self.beltY = size.height * 0.5
            self.beltCorner = beltHeight * 0.35
            self.beltMidX = beltLeading + beltWidth * 0.5

            self.crateSize = min(beltHeight * 1.05, size.height * 0.2)
            // Floor crateSpacing at 1: it is used as a divisor in
            // truncatingRemainder / ceil(beltWidth/crateSpacing); a zero
            // value would produce NaN and crash Int(NaN).
            self.crateSpacing = max(1, max(crateSize * 1.5, beltWidth / 3.2))
            self.beltCrateY = beltY - crateSize * 0.32
            self.dropDistance = binHeight * 0.5

            self.statusFont = max(9, minSide * 0.12)
            self.statusX = size.width * 0.5
            self.statusY = size.height * 0.18
        }
    }
}
