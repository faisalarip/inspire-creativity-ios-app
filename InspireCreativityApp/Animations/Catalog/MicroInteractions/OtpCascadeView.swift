// catalog-id: mi-otp-cascade
import SwiftUI

// MARK: - OTP Cascade Entry
// As each code digit is entered its box flips up to reveal the number with a
// staggered domino delay; a wrong code shakes the whole row in unison.
//
// demo == true  -> a self-driving TimelineView clock auto-types the digits with
//                  a domino flip stagger, holds, runs a failure shake, then clears
//                  and loops. The empty box outlines are always visible so no frame
//                  is ever blank.
// demo == false -> a real interactive OTP field: a hidden focusable TextField
//                  captures keystrokes, each new digit flips its box up, and once
//                  the row is full the code is validated against a fixed target.
//                  A wrong code shakes the row and clears; the right code tints green.

struct OtpCascadeView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            let metrics = OtpCascadeView_OtpMetrics(size: geo.size)
            ZStack {
                background
                Group {
                    if demo {
                        OtpCascadeView_OtpCascadeDemo(metrics: metrics)
                    } else {
                        OtpCascadeView_OtpCascadeInteractive(metrics: metrics)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.078, green: 0.063, blue: 0.098),
                Color(red: 0.043, green: 0.035, blue: 0.063)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Shared layout metrics

private struct OtpCascadeView_OtpMetrics {
    let size: CGSize
    let count: Int = 4

    var minSide: CGFloat { min(size.width, size.height) }

    // Box width derived from available width so it works in a 120pt tile and a
    // large detail area alike. Spacing scales with the box.
    var boxWidth: CGFloat {
        let usable = size.width * 0.86
        let spacingTotal = spacing * CGFloat(count - 1)
        let raw = (usable - spacingTotal) / CGFloat(count)
        return max(18, min(raw, size.height * 0.55))
    }

    var boxHeight: CGFloat { boxWidth * 1.32 }

    var spacing: CGFloat { max(6, size.width * 0.035) }

    var corner: CGFloat { boxWidth * 0.22 }

    var digitFont: CGFloat { boxHeight * 0.52 }

    var captionFont: CGFloat { max(8, minSide * 0.075) }
}

// MARK: - Palette

private enum OtpCascadeView_OtpPalette {
    static let slotIdle = Color(red: 0.14, green: 0.12, blue: 0.18)
    static let slotStroke = Color(red: 0.32, green: 0.28, blue: 0.42)
    static let slotActive = Color(red: 0.46, green: 0.38, blue: 0.95)
    static let digit = Color(red: 0.96, green: 0.95, blue: 1.0)
    static let success = Color(red: 0.36, green: 0.86, blue: 0.58)
    static let failure = Color(red: 0.98, green: 0.40, blue: 0.44)
    static let caption = Color(red: 0.62, green: 0.58, blue: 0.74)

    static func slotFill(_ accent: Color, filled: Bool) -> Color {
        filled ? accent.opacity(0.16) : slotIdle
    }
}

// MARK: - A single digit slot

// The empty outline container is ALWAYS rendered as the resting layer; only the
// digit face on top flips. That guarantees the row is never blank mid-cascade.
private struct OtpCascadeView_DigitSlot: View {
    let metrics: OtpCascadeView_OtpMetrics
    let character: String      // empty string == not yet filled
    let flip: Double           // 0 == flat down (hidden), 1 == fully revealed
    let accent: Color          // tint for this slot (active / success / failure)
    let highlighted: Bool      // active cursor position glow

    private var revealAngle: Double {
        // -90deg (edge-on, hidden) -> 0deg (face-on, revealed)
        (1.0 - flip) * -90.0
    }

    private var faceOpacity: Double {
        // Fade the face in only over the back half of the flip so the early
        // edge-on sliver never shows a ghost digit.
        max(0, min(1, (flip - 0.25) / 0.55))
    }

    var body: some View {
        ZStack {
            container
            digitFace
        }
        .frame(width: metrics.boxWidth, height: metrics.boxHeight)
    }

    private var container: some View {
        RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
            .fill(OtpCascadeView_OtpPalette.slotFill(accent, filled: !character.isEmpty))
            .overlay(
                RoundedRectangle(cornerRadius: metrics.corner, style: .continuous)
                    .stroke(
                        highlighted ? accent : OtpCascadeView_OtpPalette.slotStroke,
                        lineWidth: highlighted ? 2.0 : 1.2
                    )
            )
            .overlay(cursor)
            .shadow(
                color: highlighted ? accent.opacity(0.55) : .clear,
                radius: highlighted ? 8 : 0
            )
    }

    @ViewBuilder
    private var cursor: some View {
        if highlighted && character.isEmpty {
            OtpCascadeView_BlinkingCaret(color: accent)
                .frame(width: 2, height: metrics.boxHeight * 0.42)
        }
    }

    @ViewBuilder
    private var digitFace: some View {
        if !character.isEmpty {
            Text(character)
                .font(.system(size: metrics.digitFont, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .foregroundStyle(OtpCascadeView_OtpPalette.digit)
                .opacity(faceOpacity)
                .rotation3DEffect(
                    .degrees(revealAngle),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.55
                )
        }
    }
}

// MARK: - Blinking caret for the active empty slot

private struct OtpCascadeView_BlinkingCaret: View {
    let color: Color
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let on = (sin(t * 4.5) > -0.2)
            Capsule()
                .fill(color)
                .opacity(on ? 0.95 : 0.12)
        }
    }
}

// MARK: - Row of slots + shared shake

private struct OtpCascadeView_OtpRow: View {
    let metrics: OtpCascadeView_OtpMetrics
    let digits: [String]       // exactly metrics.count entries, "" for empty
    let flips: [Double]        // per-slot reveal 0..1
    let accent: Color
    let activeIndex: Int       // -1 == none highlighted
    let shake: CGFloat         // current horizontal shake offset

    var body: some View {
        HStack(spacing: metrics.spacing) {
            ForEach(0..<metrics.count, id: \.self) { i in
                OtpCascadeView_DigitSlot(
                    metrics: metrics,
                    character: safeDigit(i),
                    flip: safeFlip(i),
                    accent: accent,
                    highlighted: i == activeIndex
                )
            }
        }
        .offset(x: shake)
    }

    private func safeDigit(_ i: Int) -> String {
        i < digits.count ? digits[i] : ""
    }

    private func safeFlip(_ i: Int) -> Double {
        i < flips.count ? flips[i] : 0
    }
}

// MARK: - Demo (self-driving)

private struct OtpCascadeView_OtpCascadeDemo: View {
    let metrics: OtpCascadeView_OtpMetrics

    // One full loop: type digits, hold, shake, clear, pause.
    private let period: Double = 3.4
    private let code = ["4", "8", "1", "6"]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = (t.truncatingRemainder(dividingBy: period)) / period // 0..1
            let model = phase(for: p)

            VStack(spacing: metrics.boxHeight * 0.28) {
                OtpCascadeView_OtpRow(
                    metrics: metrics,
                    digits: model.digits,
                    flips: model.flips,
                    accent: model.accent,
                    activeIndex: model.activeIndex,
                    shake: model.shake
                )
                caption(model.statusText, color: model.captionColor)
            }
        }
    }

    private func caption(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: metrics.captionFont, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    struct DemoModel {
        var digits: [String]
        var flips: [Double]
        var accent: Color
        var activeIndex: Int
        var shake: CGFloat
        var statusText: String
        var captionColor: Color
    }

    // Slice the normalized clock into named windows. This keeps the never-blank
    // invariant: the empty outlines always render and we only animate the faces.
    private func phase(for p: Double) -> DemoModel {
        // Windows (fractions of the loop):
        //  0.00 - 0.55  typing the 4 digits with a domino stagger
        //  0.55 - 0.70  hold (all revealed)
        //  0.70 - 0.90  failure shake
        //  0.90 - 1.00  clear + brief empty pause
        let stagger = 0.11
        let flipWindow = 0.13

        if p < 0.70 {
            // Typing + hold
            var flips = [Double](repeating: 0, count: 4)
            var digits = [String](repeating: "", count: 4)
            var active = -1
            for i in 0..<4 {
                let start = Double(i) * stagger
                let local = (p - start) / flipWindow
                let f = max(0, min(1, easeOut(local)))
                flips[i] = f
                if f > 0.02 { digits[i] = code[i] }
                else if active == -1 { active = i }
            }
            // If everything started flipping, cursor sits at last unfinished.
            if active == -1 {
                for i in 0..<4 where flips[i] < 0.95 { active = i; break }
            }
            return DemoModel(
                digits: digits,
                flips: flips,
                accent: OtpCascadeView_OtpPalette.slotActive,
                activeIndex: active,
                shake: 0,
                statusText: "Enter code",
                captionColor: OtpCascadeView_OtpPalette.caption
            )
        } else if p < 0.90 {
            // Failure shake: full row, all revealed, red tint, damped sine offset.
            let local = (p - 0.70) / 0.20            // 0..1
            let amp = metrics.boxWidth * 0.34
            let decay = exp(-3.0 * local)
            let shake = CGFloat(sin(local * .pi * 6) * decay) * amp
            return DemoModel(
                digits: code,
                flips: [1, 1, 1, 1],
                accent: OtpCascadeView_OtpPalette.failure,
                activeIndex: -1,
                shake: shake,
                statusText: "Incorrect code",
                captionColor: OtpCascadeView_OtpPalette.failure
            )
        } else {
            // Clear: boxes empty out, brief pause before loop restarts.
            return DemoModel(
                digits: ["", "", "", ""],
                flips: [0, 0, 0, 0],
                accent: OtpCascadeView_OtpPalette.slotActive,
                activeIndex: 0,
                shake: 0,
                statusText: "Enter code",
                captionColor: OtpCascadeView_OtpPalette.caption
            )
        }
    }

    private func easeOut(_ x: Double) -> Double {
        let c = max(0, min(1, x))
        return 1 - pow(1 - c, 2.4)
    }
}

// MARK: - Interactive

private struct OtpCascadeView_OtpCascadeInteractive: View {
    let metrics: OtpCascadeView_OtpMetrics

    private let correctCode = "4816"

    @State private var entry: String = ""
    @State private var flips: [Double] = [0, 0, 0, 0]
    @State private var shake: CGFloat = 0
    @State private var status: Status = .typing
    @FocusState private var focused: Bool

    enum Status: Equatable {
        case typing
        case success
        case failure
    }

    private var accent: Color {
        switch status {
        case .typing:  return OtpCascadeView_OtpPalette.slotActive
        case .success: return OtpCascadeView_OtpPalette.success
        case .failure: return OtpCascadeView_OtpPalette.failure
        }
    }

    private var digits: [String] {
        var out = [String](repeating: "", count: metrics.count)
        for (i, ch) in entry.prefix(metrics.count).enumerated() {
            out[i] = String(ch)
        }
        return out
    }

    private var activeIndex: Int {
        guard status == .typing else { return -1 }
        return entry.count < metrics.count ? entry.count : -1
    }

    var body: some View {
        VStack(spacing: metrics.boxHeight * 0.24) {
            OtpCascadeView_OtpRow(
                metrics: metrics,
                digits: digits,
                flips: flips,
                accent: accent,
                activeIndex: activeIndex,
                shake: shake
            )
            .background(hiddenField)
            caption
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { DispatchQueue.main.async { focused = true } }
        .sensoryFeedback(.selection, trigger: entry)
        .sensoryFeedback(.success, trigger: status == .success)
        .sensoryFeedback(.error, trigger: status == .failure)
    }

    private var caption: some View {
        Text(captionText)
            .font(.system(size: metrics.captionFont, weight: .semibold, design: .rounded))
            .foregroundStyle(status == .typing ? OtpCascadeView_OtpPalette.caption : accent)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var captionText: String {
        switch status {
        case .typing:  return "Tap, type \(correctCode)"
        case .success: return "Verified"
        case .failure: return "Incorrect code"
        }
    }

    // A real focusable text field, kept invisible behind the boxes. It captures
    // the OS keyboard so the boxes are driven by genuine input.
    private var hiddenField: some View {
        TextField("", text: $entry)
            #if os(iOS)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            #endif
            .focused($focused)
            .foregroundStyle(.clear)
            .tint(.clear)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .onChange(of: entry) { old, new in
                handleChange(old: old, new: new)
            }
    }

    private func handleChange(old: String, new: String) {
        // Sanitize to digits, cap at count.
        let cleaned = String(new.filter { $0.isNumber }.prefix(metrics.count))
        if cleaned != new {
            entry = cleaned
            return
        }
        if status != .typing {
            // Re-typing after a result resets the row.
            status = .typing
            flips = [0, 0, 0, 0]
        }
        // Flip up any newly added digit boxes with a domino stagger.
        if cleaned.count > old.count {
            for i in old.count..<cleaned.count {
                let delay = Double(i - old.count) * 0.07
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(delay)) {
                    if i < flips.count { flips[i] = 1 }
                }
            }
        } else if cleaned.count < old.count {
            for i in cleaned.count..<flips.count {
                withAnimation(.easeOut(duration: 0.18)) { flips[i] = 0 }
            }
        }
        if cleaned.count == metrics.count {
            validate(cleaned)
        }
    }

    private func validate(_ value: String) {
        if value == correctCode {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                status = .success
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                status = .failure
            }
            runShake()
        }
    }

    // Shared row shake via a keyframe-style damped sequence, then clear.
    private func runShake() {
        let amp = metrics.boxWidth * 0.32
        let steps: [(CGFloat, Double)] = [
            (amp, 0.05), (-amp * 0.8, 0.06), (amp * 0.55, 0.06),
            (-amp * 0.32, 0.06), (amp * 0.15, 0.06), (0, 0.06)
        ]
        var delay: Double = 0
        for (value, dur) in steps {
            withAnimation(.easeInOut(duration: dur).delay(delay)) {
                shake = value
            }
            delay += dur
        }
        // After the shake settles, clear the row back to empty.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.35) {
            guard status == .failure else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                flips = [0, 0, 0, 0]
            }
            entry = ""
            status = .typing
        }
    }
}
