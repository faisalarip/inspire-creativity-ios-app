// catalog-id: tx-typewriter-cursor
import SwiftUI

// MARK: - Typewriter Carriage
// Characters type in one at a time over a prefix of each line with a blinking
// block cursor and a subtle per-key vertical jitter. When a line finishes, the
// page feeds up (carriage-return) and the cursor snaps back to the left margin
// with a soft damped mechanical settle before the next line types. Everything is
// derived in closed form from a single TimelineView(.animation) clock so it is
// fully self-driving and never blank. iOS 17.

struct TypewriterCursorView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(Self.epoch)
                content(in: geo.size, elapsed: t)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.paper)
    }

    // Shared monotonic clock so the loop is stable across rebuilds.
    private static let epoch = Date()

    // Warm off-white "paper" so dark ink reads clearly at any tile size.
    private static let paper = Color(red: 0.96, green: 0.95, blue: 0.91)
    private static let ink = Color(red: 0.10, green: 0.10, blue: 0.13)

    // Two short lines so the signature carriage-return shift is always exercised.
    private var lines: [String] {
        demo
            ? ["hello, world.", "type type type."]
            : ["the quick brown fox", "jumps over it all."]
    }

    // MARK: - Timing model (all closed-form off `elapsed`)

    private let charInterval: Double = 0.12   // seconds per keystroke
    private let lineHold: Double = 0.9         // pause after a line completes
    private let returnTime: Double = 0.55      // carriage-return travel + settle

    private func lineDuration(_ s: String) -> Double {
        Double(s.count) * charInterval + lineHold + returnTime
    }

    private var cycleDuration: Double {
        lines.reduce(0) { $0 + lineDuration($1) } + 0.6 // trailing breath before repeat
    }

    // Resolve which line is active, how far into it, and how many of the
    // earlier lines are fully typed (shown above as the page scrolls up).
    private func phase(at elapsed: Double) -> Phase {
        let loop = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        var acc: Double = 0
        for (i, line) in lines.enumerated() {
            let dur = lineDuration(line)
            if loop < acc + dur {
                return Phase(lineIndex: i, localTime: max(0, loop - acc), line: line)
            }
            acc += dur
        }
        // Trailing breath: hold the last fully-typed line.
        let last = max(0, lines.count - 1)
        return Phase(lineIndex: last, localTime: lineDuration(lines[last]), line: lines[last])
    }

    struct Phase {
        let lineIndex: Int
        let localTime: Double
        let line: String
    }

    // MARK: - Body content

    private func content(in size: CGSize, elapsed: Double) -> some View {
        let p = phase(at: elapsed)
        let fontSize = max(13.0, min(size.width, size.height) * 0.16)
        let typed = max(0, min(p.line.count, Int(p.localTime / charInterval)))
        let lineComplete = typed >= p.line.count
        let carriage = carriageReturn(phase: p, fontSize: fontSize)
        let priorCount = max(0, p.lineIndex)

        return VStack(alignment: .leading, spacing: fontSize * 0.42) {
            // Already-completed lines sit above, fully typed.
            ForEach(0..<priorCount, id: \.self) { i in
                lineView(text: lines[i],
                         visible: lines[i].count,
                         fontSize: fontSize,
                         localTime: 999,
                         showCursor: false,
                         carriageX: 0)
            }
            // Active line with the live cursor + per-key jitter.
            lineView(text: p.line,
                     visible: typed,
                     fontSize: fontSize,
                     localTime: p.localTime,
                     showCursor: true,
                     carriageX: lineComplete ? carriage : 0)
        }
        .font(.system(size: fontSize, weight: .medium, design: .monospaced))
        .foregroundStyle(Self.ink)
        // Feed the page up so the active line stays roughly centered.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, fontSize * 0.6)
        .offset(y: feedOffset(lineIndex: p.lineIndex, fontSize: fontSize, viewHeight: size.height))
        .clipped()
    }

    // Vertical paper feed: keep the cursor band near the middle of the tile.
    private func feedOffset(lineIndex: Int, fontSize: CGFloat, viewHeight: CGFloat) -> CGFloat {
        let lineStep = fontSize * 1.42
        let totalActive = CGFloat(lineIndex) * lineStep
        let target = viewHeight * 0.5 - fontSize * 0.6
        return max(0, target - totalActive)
    }

    // Damped mechanical settle for the carriage-return slide. The cursor has
    // just travelled back to the left margin; it overshoots slightly and rings
    // down via A*exp(-d*t)*cos(w*t).
    private func carriageReturn(phase p: Phase, fontSize: CGFloat) -> CGFloat {
        let doneAt = Double(p.line.count) * charInterval + lineHold
        let dt = p.localTime - doneAt
        guard dt > 0 else { return 0 }
        let amp = fontSize * 0.9
        let decay = 9.0
        let omega = 22.0
        let ring = amp * CGFloat(exp(-decay * dt) * cos(omega * dt))
        return ring
    }

    // MARK: - Line + cursor

    private func lineView(text: String,
                          visible: Int,
                          fontSize: CGFloat,
                          localTime: Double,
                          showCursor: Bool,
                          carriageX: CGFloat) -> some View {
        let chars = Array(text)
        let count = max(0, min(visible, chars.count))

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                glyph(String(chars[i]), index: i, localTime: localTime, fontSize: fontSize)
            }
            if showCursor {
                cursor(fontSize: fontSize, localTime: localTime)
                    .offset(x: carriageX)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // left-anchored: no slosh
    }

    // A single glyph with a brief downward keystroke jitter that auto-settles.
    private func glyph(_ s: String, index i: Int, localTime: Double, fontSize: CGFloat) -> some View {
        let appearedAt = Double(i) * charInterval
        let age = localTime - appearedAt
        let jitter: CGFloat
        if age >= 0 && age < 0.5 {
            jitter = fontSize * 0.14 * CGFloat(exp(-14.0 * age) * cos(40.0 * age))
        } else {
            jitter = 0
        }
        return Text(s)
            .offset(y: jitter)
            .transition(.identity)
    }

    // Blinking solid block cursor — always rendered so a frame is never blank.
    private func cursor(fontSize: CGFloat, localTime: Double) -> some View {
        let blink = localTime.truncatingRemainder(dividingBy: 1.06) < 0.6 ? 1.0 : 0.18
        return RoundedRectangle(cornerRadius: 1)
            .fill(Self.ink)
            .frame(width: fontSize * 0.58, height: fontSize * 0.92)
            .opacity(blink)
            .padding(.leading, fontSize * 0.06)
    }
}
