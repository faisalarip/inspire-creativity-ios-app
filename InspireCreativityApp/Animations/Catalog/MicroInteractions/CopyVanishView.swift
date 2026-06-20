// catalog-id: mi-copy-vanish
import SwiftUI

// MARK: - Copy Vanish Confirm
// On copy, the text duplicates, lifts off, and slides along an animatable
// bezier into a clipboard glyph that bulges to swallow it, then a checkmark
// crossfades in. `demo == true` self-drives the whole cycle on a loop;
// `demo == false` fires the same cycle on tap.

struct CopyVanishView: View {
    var demo: Bool = false

    // Single source of truth: one trigger increments to fire one interactive cycle.
    @State private var tapTrigger: Int = 0

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            // Self-driving: PhaseAnimator with no explicit trigger loops forever.
            PhaseAnimator(CopyPhase.allCases) { phase in
                CopyVanishStage(phase: phase, size: size)
            } animation: { phase in
                phase.animation
            }
        } else {
            // Interactive: tap fires exactly one cycle.
            PhaseAnimator(CopyPhase.allCases, trigger: tapTrigger) { phase in
                CopyVanishStage(phase: phase, size: size)
            } animation: { phase in
                // Only animate once a tap has happened so the resting state is stable.
                tapTrigger == 0 ? nil : phase.animation
            }
            .contentShape(Rectangle())
            .onTapGesture { tapTrigger += 1 }
        }
    }
}

// MARK: - Phases

private enum CopyPhase: CaseIterable {
    case idle    // ghost sits on the label, clipboard calm, no tick
    case lift    // ghost lifts off the row (scale up, rise)
    case fly     // ghost travels the bezier into the clipboard
    case swallow // clipboard bulges, ghost shrinks to nothing
    case confirm // checkmark crossfades in
    case settle  // tick eases out, ready to repeat

    var animation: Animation {
        switch self {
        case .idle:    return .easeInOut(duration: 0.5)
        case .lift:    return .spring(response: 0.32, dampingFraction: 0.62)
        case .fly:     return .timingCurve(0.42, 0.0, 0.30, 1.0, duration: 0.55)
        case .swallow: return .spring(response: 0.28, dampingFraction: 0.55)
        case .confirm: return .spring(response: 0.40, dampingFraction: 0.70)
        case .settle:  return .easeInOut(duration: 0.85)
        }
    }
}

// MARK: - Stage renderer (shared by demo + interactive)

private struct CopyVanishStage: View {
    let phase: CopyPhase
    let size: CGSize

    private var dim: CGFloat { min(size.width, size.height) }

    var body: some View {
        ZStack {
            background

            // The persistent source label — never disappears, so no blank frame.
            sourceLabel
                .position(labelAnchor)

            // The flying ghost duplicate.
            ghost

            // Clipboard glyph that swallows the ghost, with checkmark crossfade.
            clipboard
                .position(clipboardAnchor)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Layout anchors (all relative to GeometryReader size)

    private var labelAnchor: CGPoint {
        CGPoint(x: size.width * 0.40, y: size.height * 0.66)
    }

    private var clipboardAnchor: CGPoint {
        CGPoint(x: size.width * 0.72, y: size.height * 0.30)
    }

    // Quadratic bezier control point: arc up-and-over between the two anchors.
    private var flightControl: CGPoint {
        CGPoint(
            x: (labelAnchor.x + clipboardAnchor.x) * 0.5,
            y: min(labelAnchor.y, clipboardAnchor.y) - dim * 0.18
        )
    }

    // MARK: Progress derived from phase

    // 0 at label, 1 at clipboard.
    private var flightProgress: CGFloat {
        switch phase {
        case .idle, .lift:           return 0
        case .fly:                   return 1
        case .swallow, .confirm, .settle: return 1
        }
    }

    private var ghostScale: CGFloat {
        switch phase {
        case .idle:    return 1.0
        case .lift:    return 1.14
        case .fly:     return 0.74
        case .swallow: return 0.18
        default:       return 0.18
        }
    }

    private var ghostOpacity: Double {
        switch phase {
        case .idle:    return 0.0   // hidden until lift, source label carries the frame
        case .lift:    return 1.0
        case .fly:     return 1.0
        case .swallow: return 0.0
        default:       return 0.0
        }
    }

    private var clipboardBulge: CGFloat {
        switch phase {
        case .swallow: return 1.34
        case .confirm: return 1.10
        default:       return 1.0
        }
    }

    private var showCheck: Bool {
        switch phase {
        case .confirm, .settle: return true
        default:                return false
        }
    }

    private var labelDimmed: Double {
        // The source label dips slightly while the copy is in flight, then returns.
        switch phase {
        case .fly, .swallow, .confirm: return 0.45
        default:                       return 1.0
        }
    }

    // MARK: Subviews

    private var background: some View {
        RoundedRectangle(cornerRadius: dim * 0.14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hexCode: "1c1726"), Color(hexCode: "141019")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: dim * 0.14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private var sourceLabel: some View {
        codePill(text: "#A3E635")
            .opacity(labelDimmed)
    }

    private var ghost: some View {
        codePill(text: "#A3E635")
            .scaleEffect(ghostScale)
            .opacity(ghostOpacity)
            .modifier(
                BezierFlight(
                    progress: flightProgress,
                    start: labelAnchor,
                    control: flightControl,
                    end: clipboardAnchor
                )
            )
            .shadow(color: Color(hexCode: "A3E635").opacity(0.35), radius: dim * 0.04)
    }

    private func codePill(text: String) -> some View {
        Text(text)
            .font(.system(size: dim * 0.115, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(hexCode: "D9F99D"))
            .padding(.horizontal, dim * 0.07)
            .padding(.vertical, dim * 0.045)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hexCode: "A3E635").opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color(hexCode: "A3E635").opacity(0.30), lineWidth: 1)
                    )
            )
    }

    private var clipboard: some View {
        ZStack {
            // Soft glow that pulses as it swallows.
            Circle()
                .fill(Color(hexCode: "A3E635").opacity(showCheck ? 0.22 : 0.12))
                .frame(width: dim * 0.34, height: dim * 0.34)
                .scaleEffect(clipboardBulge)
                .blur(radius: dim * 0.03)

            clipboardGlyph
                .scaleEffect(clipboardBulge)
        }
    }

    @ViewBuilder
    private var clipboardGlyph: some View {
        let symbol = showCheck ? "checkmark.circle.fill" : "doc.on.clipboard.fill"
        Image(systemName: symbol)
            .font(.system(size: dim * 0.22, weight: .medium))
            .foregroundStyle(showCheck ? Color(hexCode: "A3E635") : Color(hexCode: "C8B8E8"))
            .contentTransition(.symbolEffect(.replace))
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Animatable bezier flight modifier

// Moves the modified view along a quadratic bezier as `progress` animates 0→1.
private struct BezierFlight: ViewModifier, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private func point(at t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x
        let y = mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }

    func body(content: Content) -> some View {
        let p = point(at: progress)
        content.position(p)
    }
}

// MARK: - Local hex color helper (private to avoid batch-wide redeclaration)

private extension Color {
    init(hexCode hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
            a = 1
        case 8:
            r = Double((v & 0xFF000000) >> 24) / 255
            g = Double((v & 0x00FF0000) >> 16) / 255
            b = Double((v & 0x0000FF00) >> 8) / 255
            a = Double(v & 0x000000FF) / 255
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
