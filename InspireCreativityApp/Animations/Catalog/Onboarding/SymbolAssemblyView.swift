// catalog-id: ob-symbol-assembly
import SwiftUI

// MARK: - Symbol Assembly Hero
//
// A scattered cloud of small particles flies in and locks together into a
// crisp SF Symbol, settling with a bounce. Swiping (interactive) explodes the
// symbol back into particles that re-converge into the next symbol; idle, it
// auto-cycles through the symbol set on a loop.
//
// Two modes:
//   demo == true  -> self-driving TimelineView loop (assemble -> hold -> explode -> next)
//   demo == false -> interactive DragGesture(minimumDistance: 0) scrubs the
//                     scatter; releasing past threshold advances/reverts the symbol.
//
// Design notes (the traps that sink this exact animation):
//   * Every particle's scatter origin + target offset + stagger is a DETERMINISTIC
//     function of its index. Nothing is randomized inside the Canvas/Timeline body,
//     so the swarm stays a coherent shape instead of shimmering static.
//   * Targets are sampled around the glyph's bounding region (NOT pixel-sampled),
//     and the real SF Symbol Image crossfades on top to sell the shape.
//   * SymbolAssemblyView_Particle opacity is decoupled from the symbol fade, so the mid-explode frame
//     (where both symbol images are near-zero) still shows a legible swarm.

struct SymbolAssemblyView: View {
    var demo: Bool = false

    // Symbols guaranteed available on iOS 17.
    private let symbols: [SymbolAssemblyView_SymbolStyle] = [
        SymbolAssemblyView_SymbolStyle(name: "sparkles",
                    color: Color(red: 0.62, green: 0.51, blue: 0.98)),
        SymbolAssemblyView_SymbolStyle(name: "heart.fill",
                    color: Color(red: 0.98, green: 0.44, blue: 0.55)),
        SymbolAssemblyView_SymbolStyle(name: "bolt.fill",
                    color: Color(red: 0.99, green: 0.79, blue: 0.36)),
        SymbolAssemblyView_SymbolStyle(name: "leaf.fill",
                    color: Color(red: 0.44, green: 0.84, blue: 0.60)),
        SymbolAssemblyView_SymbolStyle(name: "star.fill",
                    color: Color(red: 0.40, green: 0.74, blue: 0.99))
    ]

    private let particleCount: Int = 54

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            content(in: size)
                .frame(width: size.width, height: size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundFill)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            SymbolAssemblyView_DemoStage(symbols: symbols,
                      particleCount: particleCount,
                      size: size)
        } else {
            SymbolAssemblyView_InteractiveStage(symbols: symbols,
                             particleCount: particleCount,
                             size: size)
        }
    }

    private var backgroundFill: some View {
        RadialGradient(
            colors: [
                Color(red: 0.10, green: 0.07, blue: 0.13),
                Color(red: 0.05, green: 0.04, blue: 0.08)
            ],
            center: .center,
            startRadius: 4,
            endRadius: 260
        )
    }
}

// MARK: - Symbol descriptor

private struct SymbolAssemblyView_SymbolStyle {
    let name: String
    let color: Color
}

// MARK: - SymbolAssemblyView_Particle model (fully deterministic per index)

private struct SymbolAssemblyView_Particle {
    /// Direction (unit-ish) the particle scatters toward, as a fraction of the radius.
    let scatter: CGPoint
    /// Target offset from center as a fraction of the glyph radius.
    let target: CGPoint
    /// Per-particle dot radius as a fraction of min dimension.
    let dotScale: CGFloat
    /// Stagger 0..1 — later particles arrive later.
    let delay: CGFloat
    /// Subtle hue shift so the swarm isn't monotone.
    let tint: CGFloat
}

/// Builds the particle set ONCE from the index. No per-frame randomness:
/// a cheap integer hash gives stable pseudo-random values per index.
private func makeParticles(count: Int) -> [SymbolAssemblyView_Particle] {
    (0..<count).map { i in
        let a = hashUnit(i &* 2 &+ 1)          // scatter angle seed
        let b = hashUnit(i &* 7 &+ 13)         // scatter distance seed
        let c = hashUnit(i &* 3 &+ 5)          // target angle seed
        let d = hashUnit(i &* 11 &+ 17)        // target radial seed
        let e = hashUnit(i &* 5 &+ 23)         // dot size seed
        let f = hashUnit(i &* 13 &+ 31)        // tint seed

        // Scatter: spread across a wide ring well outside the glyph.
        let scatterAngle = a * 2.0 * Double.pi
        let scatterDist  = 1.55 + b * 1.05      // 1.55x .. 2.6x of glyph radius
        let scatter = CGPoint(
            x: CGFloat(cos(scatterAngle) * scatterDist),
            y: CGFloat(sin(scatterAngle) * scatterDist)
        )

        // Target: a filled-disk distribution (sqrt for even area coverage)
        // biased slightly outward so the swarm reads as the glyph's silhouette.
        let targetAngle = c * 2.0 * Double.pi
        let targetRad   = (0.18 + sqrt(d) * 0.82)   // 0.18 .. 1.0 of glyph radius
        let target = CGPoint(
            x: CGFloat(cos(targetAngle) * targetRad),
            y: CGFloat(sin(targetAngle) * targetRad)
        )

        return SymbolAssemblyView_Particle(
            scatter: scatter,
            target: target,
            dotScale: CGFloat(0.014 + e * 0.020),
            delay: CGFloat(b * 0.45),               // staggered arrival
            tint: CGFloat(f)
        )
    }
}

/// Deterministic 0..1 pseudo-random from an integer (Wang-style mix).
private func hashUnit(_ value: Int) -> Double {
    var x = UInt64(bitPattern: Int64(value)) &+ 0x9E3779B97F4A7C15
    x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
    x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
    x = x ^ (x >> 31)
    return Double(x % 1_000_000) / 1_000_000.0
}

// MARK: - SymbolAssemblyView_Resolved particle position / appearance (kept OUT of body)

private struct SymbolAssemblyView_Resolved {
    let position: CGPoint
    let radius: CGFloat
    let opacity: Double
}

/// progress: 0 = fully scattered, 1 = fully assembled (locked into glyph).
private func resolve(_ p: SymbolAssemblyView_Particle,
                     progress: CGFloat,
                     center: CGPoint,
                     glyphRadius: CGFloat,
                     minDim: CGFloat) -> SymbolAssemblyView_Resolved {
    // Per-particle eased local progress with stagger so they don't arrive in lockstep.
    let span: CGFloat = 1.0 - p.delay
    let raw = (progress - p.delay) / max(span, 0.0001)
    let t = smoothstep(clamp01(raw))

    let from = CGPoint(x: p.scatter.x * glyphRadius,
                       y: p.scatter.y * glyphRadius)
    let to   = CGPoint(x: p.target.x * glyphRadius,
                       y: p.target.y * glyphRadius)

    let ox = lerp(from.x, to.x, t)
    let oy = lerp(from.y, to.y, t)

    let pos = CGPoint(x: center.x + ox, y: center.y + oy)
    let radius = p.dotScale * minDim

    // Opacity NEVER hits zero anywhere in the cycle: scattered particles stay
    // clearly visible (this guarantees the mid-explode frame is never blank).
    // They fade only slightly as they lock in (the symbol image takes over).
    let scatteredOpacity: Double = 0.92
    let assembledOpacity: Double = 0.34
    let opacity = lerp(scatteredOpacity, assembledOpacity, t)

    return SymbolAssemblyView_Resolved(position: pos, radius: radius, opacity: opacity)
}

// MARK: - Canvas particle layer

private struct SymbolAssemblyView_ParticleCanvas: View {
    let particles: [SymbolAssemblyView_Particle]
    let progress: CGFloat        // 0 scattered .. 1 assembled
    let color: Color
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let minDim = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let glyphRadius = minDim * 0.34

            for p in particles {
                let r = resolve(p,
                                progress: progress,
                                center: center,
                                glyphRadius: glyphRadius,
                                minDim: minDim)

                let rect = CGRect(x: r.position.x - r.radius,
                                  y: r.position.y - r.radius,
                                  width: r.radius * 2,
                                  height: r.radius * 2)

                let dotColor = color.opacity(0.55 + p.tint * 0.45)
                context.opacity = r.opacity
                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Symbol image (crossfades in on lock)

private struct SymbolAssemblyView_GlyphImage: View {
    let style: SymbolAssemblyView_SymbolStyle
    let opacity: Double
    let bounceTrigger: Int      // changes drive symbolEffect(.bounce)
    let size: CGSize

    var body: some View {
        let minDim = min(size.width, size.height)
        let fontSize = minDim * 0.46

        Image(systemName: style.name)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(style.color)
            .symbolRenderingMode(.hierarchical)
            .modifier(SymbolAssemblyView_BounceModifier(trigger: bounceTrigger))
            .shadow(color: style.color.opacity(0.55 * opacity),
                    radius: minDim * 0.05)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

/// symbolEffect(.bounce, value:) is iOS-17-safe, so no availability guard needed.
private struct SymbolAssemblyView_BounceModifier: ViewModifier {
    let trigger: Int
    func body(content: Content) -> some View {
        content.symbolEffect(.bounce, value: trigger)
    }
}

// MARK: - Demo stage (self-driving)

private struct SymbolAssemblyView_DemoStage: View {
    let symbols: [SymbolAssemblyView_SymbolStyle]
    let particleCount: Int
    let size: CGSize

    private let particles: [SymbolAssemblyView_Particle]
    private let period: Double = 3.0     // seconds per symbol cycle

    init(symbols: [SymbolAssemblyView_SymbolStyle], particleCount: Int, size: CGSize) {
        self.symbols = symbols
        self.particleCount = particleCount
        self.size = size
        self.particles = makeParticles(count: particleCount)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = cyclePhase(at: t)

            ZStack {
                SymbolAssemblyView_ParticleCanvas(particles: particles,
                               progress: phase.progress,
                               color: symbols[phase.index].color,
                               size: size)

                SymbolAssemblyView_GlyphImage(style: symbols[phase.index],
                           opacity: symbolOpacity(for: phase.progress),
                           bounceTrigger: phase.index,
                           size: size)
                    .scaleEffect(symbolScale(for: phase.progress))
            }
        }
    }

    struct Phase {
        let index: Int
        let progress: CGFloat    // 0 scattered .. 1 assembled
    }

    /// Maps absolute time into (symbol index, assemble progress).
    /// Each cycle: assemble (0->1) -> hold(1) -> explode (1->0).
    private func cyclePhase(at time: Double) -> Phase {
        let total = time / period
        let index = Int(floor(total)) % symbols.count
        let local = total - floor(total)        // 0..1 within this symbol

        let progress: CGFloat
        if local < 0.38 {
            // assemble
            progress = CGFloat(local / 0.38)
        } else if local < 0.72 {
            // hold assembled
            progress = 1.0
        } else {
            // explode back to scattered (handoff to next symbol's assemble)
            progress = CGFloat(1.0 - (local - 0.72) / 0.28)
        }
        return Phase(index: index, progress: clamp01(progress))
    }

    private func symbolOpacity(for progress: CGFloat) -> Double {
        // Symbol only appears once particles are mostly home.
        Double(smoothstep(clamp01((progress - 0.7) / 0.3)))
    }

    private func symbolScale(for progress: CGFloat) -> CGFloat {
        // Tiny settle bounce as it locks.
        let s = smoothstep(clamp01((progress - 0.7) / 0.3))
        return 0.86 + 0.14 * s + 0.04 * CGFloat(sin(Double(s) * Double.pi))
    }
}

// MARK: - Interactive stage (real DragGesture)

private struct SymbolAssemblyView_InteractiveStage: View {
    let symbols: [SymbolAssemblyView_SymbolStyle]
    let particleCount: Int
    let size: CGSize

    private let particles: [SymbolAssemblyView_Particle]

    @State private var index: Int = 0
    /// 0 scattered .. 1 assembled. Resting state is fully assembled (1).
    @State private var progress: CGFloat = 1.0
    @State private var dragging: Bool = false
    @State private var bounceTrigger: Int = 0

    init(symbols: [SymbolAssemblyView_SymbolStyle], particleCount: Int, size: CGSize) {
        self.symbols = symbols
        self.particleCount = particleCount
        self.size = size
        self.particles = makeParticles(count: particleCount)
    }

    var body: some View {
        ZStack {
            SymbolAssemblyView_ParticleCanvas(particles: particles,
                           progress: progress,
                           color: symbols[index].color,
                           size: size)

            SymbolAssemblyView_GlyphImage(style: symbols[index],
                       opacity: symbolOpacity(for: progress),
                       bounceTrigger: bounceTrigger,
                       size: size)
                .scaleEffect(symbolScale(for: progress))

            hintLabel
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var hintLabel: some View {
        VStack {
            Spacer()
            Text("Swipe to rebuild")
                .font(.system(size: max(9, min(size.width, size.height) * 0.07),
                              weight: .medium))
                .foregroundStyle(.white.opacity(progress > 0.9 ? 0.5 : 0.0))
                .padding(.bottom, min(size.width, size.height) * 0.06)
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragging = true
                // Horizontal drag scrubs the symbol apart: more drag -> more scatter.
                let span = max(size.width * 0.55, 1)
                let amount = min(abs(value.translation.width) / span, 1.0)
                progress = clamp01(1.0 - amount)
            }
            .onEnded { value in
                dragging = false
                let span = max(size.width * 0.55, 1)
                let predicted = abs(value.predictedEndTranslation.width) / span
                let actual = abs(value.translation.width) / span

                if max(predicted, actual) > 0.5 {
                    advanceSymbol(forward: value.translation.width < 0)
                } else {
                    // Snap back assembled.
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        progress = 1.0
                    }
                }
            }
    }

    private func advanceSymbol(forward: Bool) {
        // Explode fully, swap symbol, then converge into the new one with a bounce.
        withAnimation(.easeIn(duration: 0.18)) {
            progress = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let count = symbols.count
            index = forward ? (index + 1) % count
                            : (index - 1 + count) % count
            withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) {
                progress = 1.0
            }
            bounceTrigger &+= 1
        }
    }

    private func symbolOpacity(for progress: CGFloat) -> Double {
        Double(smoothstep(clamp01((progress - 0.7) / 0.3)))
    }

    private func symbolScale(for progress: CGFloat) -> CGFloat {
        let s = smoothstep(clamp01((progress - 0.7) / 0.3))
        return 0.86 + 0.14 * s
    }
}

// MARK: - Math helpers

private func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

private func smoothstep(_ x: CGFloat) -> CGFloat {
    let t = clamp01(x)
    return t * t * (3 - 2 * t)
}
