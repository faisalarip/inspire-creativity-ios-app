// catalog-id: mi-emoji-fountain
import SwiftUI

// MARK: - Particle Model

private struct EmojiFountainView_EmojiParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var angle: CGFloat
    var spin: CGFloat
    var age: Double
    var life: Double
    var size: CGFloat
    var glyphIndex: Int

    var isDead: Bool { age >= life }
}

// MARK: - Particle Engine
// A plain reference type held in @State. Its mutations happen inside the
// Canvas draw closure and are intentionally invisible to SwiftUI's
// dependency tracking; TimelineView(.animation) drives the redraws.

private final class EmojiFountainView_EmojiFountainEngine {
    var particles: [EmojiFountainView_EmojiParticle] = []
    var lastTime: Double = -1
    var emissionAccumulator: Double = 0
    var seed: UInt64 = 0x9E3779B97F4A7C15

    let maxParticles = 150

    // Cheap deterministic PRNG so spawn jitter is stable & fast.
    private func nextUnit() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let bits = (seed >> 33) & 0xFFFFFF
        return CGFloat(bits) / CGFloat(0xFFFFFF)
    }

    private func nextRange(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        lo + (hi - lo) * nextUnit()
    }

    /// Advance the simulation by a clamped delta and emit at the given rate.
    /// - Parameters:
    ///   - dt: seconds elapsed (already clamped by caller)
    ///   - rate: particles per second to spawn this step (0 = none)
    ///   - origin: nozzle position in canvas space
    ///   - gravity: downward acceleration in points/s^2
    ///   - glyphCount: number of available emoji glyphs
    func step(dt: Double,
              rate: Double,
              origin: CGPoint,
              gravity: CGFloat,
              glyphCount: Int) {
        // Emit
        if rate > 0 {
            emissionAccumulator += rate * dt
            var toSpawn = Int(emissionAccumulator)
            if toSpawn > 0 {
                emissionAccumulator -= Double(toSpawn)
                // Don't overshoot the cap in a single hitchy frame.
                let room = maxParticles - particles.count
                toSpawn = min(toSpawn, max(0, room))
                for _ in 0..<toSpawn {
                    spawn(at: origin, glyphCount: glyphCount)
                }
            }
        } else {
            emissionAccumulator = 0
        }

        // Integrate (semi-implicit Euler) + cull.
        let g = gravity
        let drag: CGFloat = 0.06
        for i in particles.indices {
            particles[i].vy += g * CGFloat(dt)
            // mild horizontal air drag so the spray feathers out
            particles[i].vx -= particles[i].vx * drag * CGFloat(dt)
            particles[i].x += particles[i].vx * CGFloat(dt)
            particles[i].y += particles[i].vy * CGFloat(dt)
            particles[i].angle += particles[i].spin * CGFloat(dt)
            particles[i].age += dt
        }

        particles.removeAll { p in
            p.isDead || p.y > origin.y + 2000
        }
    }

    private func spawn(at origin: CGPoint, glyphCount: Int) {
        // Upward arcing burst with a spread cone biased to vertical.
        let speed = nextRange(360, 620)
        // angle measured from straight up; +/- spread
        let spread = nextRange(-0.42, 0.42)
        let vx = sin(spread) * speed
        let vy = -cos(spread) * speed
        let p = EmojiFountainView_EmojiParticle(
            x: origin.x + nextRange(-6, 6),
            y: origin.y,
            vx: vx,
            vy: vy,
            angle: nextRange(0, .pi * 2),
            spin: nextRange(-7, 7),
            age: 0,
            life: Double(nextRange(1.5, 2.6)),
            size: nextRange(20, 34),
            glyphIndex: Int(nextUnit() * CGFloat(glyphCount)) % max(1, glyphCount)
        )
        particles.append(p)
    }
}

// MARK: - View

struct EmojiFountainView: View {
    var demo: Bool = false

    @State private var engine = EmojiFountainView_EmojiFountainEngine()
    @State private var isPressing = false
    @State private var pressStart: Double = 0
    @State private var holdRamp: Double = 0   // 0...1 interactive hold intensity

    private let glyphs: [String] = ["🎉", "✨", "💖", "🌟", "🎈", "🥳", "💫", "🔥"]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background
                fountainCanvas(size: size)
                nozzle(size: size)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(pressGesture, including: demo ? .none : .all)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: Layers

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.07, blue: 0.13),
                Color(red: 0.05, green: 0.04, blue: 0.09)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func fountainCanvas(size: CGSize) -> some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                advance(now: now, canvasSize: canvasSize)
                draw(in: &context, canvasSize: canvasSize)
            }
        }
        .allowsHitTesting(false)
    }

    private func nozzle(size: CGSize) -> some View {
        let dim = min(size.width, size.height)
        let buttonSize = max(34, dim * 0.34)
        return VStack {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.52, blue: 0.72),
                                Color(red: 0.86, green: 0.27, blue: 0.55)
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: buttonSize
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(
                            Color.white.opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 0.86, green: 0.27, blue: 0.55)
                        .opacity(0.6),
                        radius: glowRadius, x: 0, y: 0)
                    .scaleEffect(buttonScale)
                Text("🎊")
                    .font(.system(size: buttonSize * 0.5))
                    .scaleEffect(buttonScale)
            }
            .frame(width: buttonSize, height: buttonSize)
            .padding(.bottom, max(8, dim * 0.1))
            .animation(.spring(response: 0.3, dampingFraction: 0.6),
                       value: isPressing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    // MARK: Derived visuals

    private var buttonScale: CGFloat {
        isPressing ? 0.86 : 1.0
    }

    private var glowRadius: CGFloat {
        isPressing ? 18 : 8
    }

    // MARK: Simulation driving

    private func advance(now: Double, canvasSize: CGSize) {
        if engine.lastTime < 0 {
            engine.lastTime = now
        }
        var dt = now - engine.lastTime
        engine.lastTime = now
        // Clamp: first frame & background-return produce huge dt.
        dt = min(max(dt, 0), 1.0 / 30.0)

        let origin = nozzleOrigin(in: canvasSize)
        let rate = emissionRate(now: now)
        engine.step(dt: dt,
                    rate: rate,
                    origin: origin,
                    gravity: gravity(for: canvasSize),
                    glyphCount: glyphs.count)
    }

    private func gravity(for size: CGSize) -> CGFloat {
        // Scale gravity with view height so the arc shape is size-agnostic.
        let h = max(size.height, 1)
        return h * 2.6
    }

    private func nozzleOrigin(in size: CGSize) -> CGPoint {
        let dim = min(size.width, size.height)
        let buttonSize = max(34, dim * 0.34)
        let bottomPad = max(8, dim * 0.1)
        let y = size.height - bottomPad - buttonSize * 0.75
        return CGPoint(x: size.width / 2, y: y)
    }

    /// Particles per second. Demo: sinusoidal pulse with a non-zero floor so
    /// the canvas is never empty. Interactive: ramps with hold duration.
    private func emissionRate(now: Double) -> Double {
        if demo {
            // ~3.2s loop, oscillating between a calm floor and a lively peak.
            let phase = sin(now * (2 * Double.pi / 3.2))
            let normalized = (phase + 1) / 2          // 0...1
            let floor = 24.0
            let peak = 95.0
            return floor + (peak - floor) * normalized
        } else {
            guard isPressing else { return 0 }
            let held = now - pressStart
            // Ramp 0.4s ease-in from a baseline to a fat stream.
            let ramp = min(1.0, held / 1.2)
            let eased = ramp * ramp * (3 - 2 * ramp)  // smoothstep
            let base = 28.0
            let maxRate = 110.0
            return base + (maxRate - base) * eased
        }
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, canvasSize: CGSize) {
        // Resolve each glyph once (no per-emoji view allocation).
        var resolved: [GraphicsContext.ResolvedText] = []
        resolved.reserveCapacity(glyphs.count)
        for g in glyphs {
            let text = Text(g).font(.system(size: 28))
            resolved.append(context.resolve(text))
        }

        for p in engine.particles {
            let t = p.age / max(p.life, 0.0001)
            let opacity = fade(t)
            if opacity <= 0.01 { continue }

            // Copy the value-type context per particle so transforms don't
            // accumulate across the whole canvas.
            var c = context
            c.opacity = opacity
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(Double(p.angle)))
            let scale = p.size / 28.0
            c.scaleBy(x: scale, y: scale)
            c.draw(resolved[p.glyphIndex], at: .zero, anchor: .center)
        }
    }

    private func fade(_ t: Double) -> Double {
        // Quick fade-in, long hold, fade-out near end of life.
        if t < 0.08 {
            return t / 0.08
        } else if t > 0.75 {
            return max(0, (1 - t) / 0.25)
        }
        return 1
    }

    // MARK: Gesture

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressing {
                    isPressing = true
                    pressStart = Date().timeIntervalSinceReferenceDate
                }
            }
            .onEnded { _ in
                isPressing = false
            }
    }
}
