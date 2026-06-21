// catalog-id: mi-popcorn-emoji
import SwiftUI

// MARK: - PopcornEmojiView
/// Tapping pops a cluster of emoji that fire upward at staggered times with
/// slight horizontal drift, each rotating and shrinking like popping kernels.
///
/// - `demo == true`  : a self-driving loop auto-fires a fresh burst every few
///                     seconds, derived purely from the timeline clock (no timers,
///                     no state mutation during view update).
/// - `demo == false` : a real interactive component — tap anywhere to pop a
///                     cluster from the touch point, with haptic feedback.
struct PopcornEmojiView: View {

    var demo: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if demo {
                PopcornEmojiView_DemoPopcorn(size: size)
            } else {
                PopcornEmojiView_InteractivePopcorn(size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared model

/// Immutable per-kernel seed. All randomness is baked in ONCE at spawn so the
/// physics is a pure function of elapsed time (no per-frame jitter).
private struct PopcornEmojiView_Kernel: Identifiable {
    let id: Int
    let emoji: String
    let launchDelay: Double      // seconds before this kernel pops
    let lifetime: Double         // seconds visible after launch
    let originX: CGFloat         // 0...1 normalized horizontal start near source
    let driftX: CGFloat          // -1...1 normalized horizontal drift
    let power: CGFloat           // 0.7...1.3 launch-velocity multiplier
    let spin: Double             // radians/second rotation
    let baseScale: CGFloat       // 0.8...1.25 size multiplier
}

private enum PopcornEmojiView_PopcornConfig {
    static let emojis = ["🍿", "🌽", "✨", "🎉", "🧈"]
    static let kernelsPerBurst = 22
    static let maxLifetime: Double = 1.9
    static let loopPeriod: Double = 3.2
}

/// A live burst: a start date plus its baked kernels.
private struct PopcornEmojiView_Burst: Identifiable {
    let id = UUID()
    let startDate: Date
    let origin: CGPoint        // tap point in view coordinates
    let kernels: [PopcornEmojiView_Kernel]
}

// MARK: - PopcornEmojiView_Kernel generation (seeded, stable)

private func makeKernels(seed: UInt64) -> [PopcornEmojiView_Kernel] {
    var rng = PopcornEmojiView_SplitMix64(seed: seed)
    let count = PopcornEmojiView_PopcornConfig.kernelsPerBurst
    return (0..<count).map { i in
        let emoji = PopcornEmojiView_PopcornConfig.emojis[Int(rng.next() % UInt64(PopcornEmojiView_PopcornConfig.emojis.count))]
        let launchDelay: Double = rng.double(in: 0.0...0.55)
        let lifetime: Double = rng.double(in: 1.0...PopcornEmojiView_PopcornConfig.maxLifetime)
        let originX: CGFloat = CGFloat(rng.double(in: 0.32...0.68))
        let driftX: CGFloat = CGFloat(rng.double(in: -1.0...1.0))
        let power: CGFloat = CGFloat(rng.double(in: 0.72...1.3))
        let spin: Double = rng.double(in: -7.0...7.0)
        let baseScale: CGFloat = CGFloat(rng.double(in: 0.8...1.25))
        return PopcornEmojiView_Kernel(id: i,
                      emoji: emoji,
                      launchDelay: launchDelay,
                      lifetime: lifetime,
                      originX: originX,
                      driftX: driftX,
                      power: power,
                      spin: spin,
                      baseScale: baseScale)
    }
}

/// Tiny deterministic RNG so a given seed always yields the same burst shape,
/// keeping the popcorn stable across frames.
private struct PopcornEmojiView_SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Physics + drawing (shared by demo & interactive)

private struct PopcornEmojiView_PopcornFrame: View {
    let size: CGSize
    /// Each entry: kernels + the elapsed seconds since that burst started.
    let bursts: [(origin: CGPoint, kernels: [PopcornEmojiView_Kernel], elapsed: Double)]
    let pulse: Double   // 0...1 source "pop" pulse for the always-on base

    var body: some View {
        Canvas { context, _ in
            drawSource(in: &context)
            drawBursts(in: &context)
        }
    }

    // Always-visible popcorn source so the view is never blank between pops.
    private func drawSource(in context: inout GraphicsContext) {
        let dim = min(size.width, size.height)
        let baseFont = dim * 0.34
        let bounce = 1.0 + 0.12 * sin(pulse * .pi)   // gentle breathing pop
        let sourcePoint = CGPoint(x: size.width / 2, y: size.height * 0.82)

        var sub = context
        sub.translateBy(x: sourcePoint.x, y: sourcePoint.y)
        sub.scaleBy(x: bounce, y: bounce)
        let resolved = sub.resolve(Text("🍿").font(.system(size: baseFont)))
        let s = resolved.measure(in: size)
        sub.draw(resolved, at: CGPoint(x: 0, y: -s.height * 0.1), anchor: .center)
    }

    private func drawBursts(in context: inout GraphicsContext) {
        let dim = min(size.width, size.height)
        let kernelFont = dim * 0.18
        let v0 = size.height * 0.95        // launch speed (points/sec), screen-relative
        let gravity = size.height * 1.9    // gravity (points/sec^2)
        let driftSpan = size.width * 0.45

        // Resolve glyphs once per frame, reuse per kernel.
        var resolvedCache: [String: GraphicsContext.ResolvedText] = [:]
        for e in PopcornEmojiView_PopcornConfig.emojis {
            resolvedCache[e] = context.resolve(Text(e).font(.system(size: kernelFont)))
        }

        for burst in bursts {
            for kernel in burst.kernels {
                let t = burst.elapsed - kernel.launchDelay
                guard t >= 0, t <= kernel.lifetime else { continue }
                drawKernel(kernel,
                           t: t,
                           burstOrigin: burst.origin,
                           v0: v0,
                           gravity: gravity,
                           driftSpan: driftSpan,
                           cache: resolvedCache,
                           context: context)
            }
        }
    }

    private func drawKernel(_ kernel: PopcornEmojiView_Kernel,
                            t: Double,
                            burstOrigin: CGPoint,
                            v0: CGFloat,
                            gravity: CGFloat,
                            driftSpan: CGFloat,
                            cache: [String: GraphicsContext.ResolvedText],
                            context: GraphicsContext) {
        guard let glyph = cache[kernel.emoji] else { return }

        let tt = CGFloat(t)
        let life = CGFloat(kernel.lifetime)
        let progress = tt / life                       // 0...1 across lifetime

        // Projectile motion: up then gravity pulls it back down.
        let launch = v0 * kernel.power
        let dy = -(launch * tt) + 0.5 * gravity * tt * tt
        let dx = kernel.driftX * driftSpan * tt

        // Origin: blend the burst point with a small per-kernel spread.
        let spread = (kernel.originX - 0.5) * driftSpan * 0.6
        let x = burstOrigin.x + spread + dx
        let y = burstOrigin.y + dy

        // Shrink + fade as the kernel ages, with a quick pop-in at the start.
        let popIn = min(1.0, tt / 0.09)
        let shrink = 1.0 - 0.55 * progress
        let scale = kernel.baseScale * shrink * popIn
        let fadeStart: CGFloat = 0.6
        let opacity: Double = progress < fadeStart
            ? 1.0
            : Double(max(0.0, 1.0 - (progress - fadeStart) / (1.0 - fadeStart)))

        guard scale > 0.01, opacity > 0.01 else { return }

        let angle = kernel.spin * t

        var sub = context
        sub.opacity = opacity
        sub.translateBy(x: x, y: y)
        sub.rotate(by: .radians(angle))
        sub.scaleBy(x: scale, y: scale)
        sub.draw(glyph, at: .zero, anchor: .center)
    }
}

// MARK: - Demo (self-driving)

private struct PopcornEmojiView_DemoPopcorn: View {
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let period = PopcornEmojiView_PopcornConfig.loopPeriod
            let loopIndex = floor(now / period)
            let phase = now - loopIndex * period          // 0...period

            // One burst per loop, fired at phase 0, plus the previous loop's tail
            // so pops overlap and never leave a fully empty frame.
            let bursts = demoBursts(loopIndex: loopIndex, phase: phase)
            let pulse = max(0.0, 1.0 - phase / 0.5)        // source pulse at fire

            PopcornEmojiView_PopcornFrame(size: size, bursts: bursts, pulse: pulse)
        }
        .accessibilityLabel("Popcorn emoji burst animation")
    }

    private func demoBursts(loopIndex: Double,
                            phase: Double) -> [(origin: CGPoint, kernels: [PopcornEmojiView_Kernel], elapsed: Double)] {
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.74)
        var result: [(CGPoint, [PopcornEmojiView_Kernel], Double)] = []

        // Current loop's burst.
        let curSeed = UInt64(bitPattern: Int64(loopIndex)) &* 2_654_435_761
        result.append((origin, makeKernels(seed: curSeed), phase))

        // Previous loop's burst (its tail still fading early in this loop).
        let prevElapsed = phase + PopcornEmojiView_PopcornConfig.loopPeriod
        if prevElapsed <= PopcornEmojiView_PopcornConfig.maxLifetime + 0.6 {
            let prevSeed = UInt64(bitPattern: Int64(loopIndex - 1)) &* 2_654_435_761
            result.append((origin, makeKernels(seed: prevSeed), prevElapsed))
        }
        return result.map { (origin: $0.0, kernels: $0.1, elapsed: $0.2) }
    }
}

// MARK: - Interactive (tap to pop)

private struct PopcornEmojiView_InteractivePopcorn: View {
    let size: CGSize
    @State private var bursts: [PopcornEmojiView_Burst] = []
    @State private var burstCount: Int = 0
    @State private var lastTap: CGPoint = .zero

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let live = liveBursts(now: now)
            let pulse = sourcePulse(now: now)

            PopcornEmojiView_PopcornFrame(size: size, bursts: live, pulse: pulse)
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    spawnBurst(at: value.location)
                }
        )
        // Tapping the always-on source is the obvious affordance; a tap anywhere
        // also works thanks to contentShape above.
        .sensoryFeedback(.impact(weight: .light), trigger: burstCount)
        .accessibilityLabel("Tap to pop popcorn emoji")
    }

    private func liveBursts(now: Date) -> [(origin: CGPoint, kernels: [PopcornEmojiView_Kernel], elapsed: Double)] {
        bursts.compactMap { burst in
            let elapsed = now.timeIntervalSince(burst.startDate)
            guard elapsed <= PopcornEmojiView_PopcornConfig.maxLifetime + 0.6 else { return nil }
            return (origin: burst.origin, kernels: burst.kernels, elapsed: elapsed)
        }
    }

    private func sourcePulse(now: Date) -> Double {
        guard let recent = bursts.last else { return 0 }
        let dt = now.timeIntervalSince(recent.startDate)
        guard dt < 0.5 else { return 0 }
        return max(0.0, 1.0 - dt / 0.5)
    }

    private func spawnBurst(at point: CGPoint) {
        let nowDate = Date()
        // Prune expired bursts here (cannot mutate inside Canvas).
        bursts.removeAll { nowDate.timeIntervalSince($0.startDate) > PopcornEmojiView_PopcornConfig.maxLifetime + 0.6 }

        let seed = UInt64(bitPattern: Int64(nowDate.timeIntervalSinceReferenceDate * 1000))
        let origin = CGPoint(x: point.x, y: point.y)
        bursts.append(PopcornEmojiView_Burst(startDate: nowDate, origin: origin, kernels: makeKernels(seed: seed)))
        lastTap = point
        burstCount &+= 1
    }
}
