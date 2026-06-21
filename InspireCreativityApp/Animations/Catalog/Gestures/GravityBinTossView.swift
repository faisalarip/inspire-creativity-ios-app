// catalog-id: ges-gravity-bin-toss
import SwiftUI

// MARK: - Gravity Bin Toss
// Fling chips toward a bin; they arc under gravity, bounce off the rim and each
// other, and pile up with stacking collisions. demo == true self-drives by
// auto-tossing one chip per cycle; demo == false reads a DragGesture fling.
//
// Single shared simulation core: only the spawn trigger differs between modes.
// All physics scale to the GeometryReader size so it works in a 120pt tile and
// a large detail area alike. iOS 17. No external dependencies.

struct GravityBinTossView: View {
    var demo: Bool = false

    var body: some View {
        GeometryReader { geo in
            GravityBinTossCore(demo: demo, size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - GravityBinTossView_Chip model

private struct GravityBinTossView_Chip: Identifiable {
    let id: Int
    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var spin: CGFloat        // current rotation, radians
    var spinRate: CGFloat    // radians / second
    var hue: Double          // base color hue 0..1
    var settled: Bool = false
    var bornAt: TimeInterval
}

// MARK: - Simulation core

private struct GravityBinTossCore: View {
    let demo: Bool
    let size: CGSize

    @State private var chips: [GravityBinTossView_Chip] = []
    @State private var nextID: Int = 0
    @State private var lastTick: Date? = nil
    @State private var spawnAccumulator: Double = 0
    @State private var collisionCount: Int = 0   // haptic trigger (only bumped when !demo)
    @State private var fadeOut: Double = 1.0      // demo reset fade
    @State private var resetting: Bool = false

    // Live drag preview
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                background
                Canvas { ctx, _ in
                    drawScene(into: ctx)
                }
                .opacity(fadeOut)

                // Aim preview line while dragging (interactive only).
                aimPreview
            }
            .onChange(of: timeline.date) { _, now in
                tick(now)
            }
        }
        .contentShape(Rectangle())
        .gesture(flingGesture, including: demo ? .subviews : .all)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: collisionCount)
    }

    // MARK: Layout helpers (all proportional to size)

    private var unit: CGFloat { min(size.width, size.height) }

    private var chipRadius: CGFloat { max(unit * 0.052, 3) }

    private var gravity: CGFloat { size.height * 3.4 } // pt / s^2

    private var binRect: CGRect {
        let w = size.width * 0.46
        let h = size.height * 0.5
        let x = (size.width - w) / 2
        let y = size.height - h - size.height * 0.06
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private var wallThickness: CGFloat { max(unit * 0.022, 2) }

    private var floorY: CGFloat { binRect.maxY }

    private var maxChips: Int { 16 }

    // Spawn origin for demo / auto toss.
    private var spawnPoint: CGPoint {
        CGPoint(x: size.width * 0.16, y: size.height * 0.26)
    }

    // MARK: Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.055, blue: 0.09),
                Color(red: 0.10, green: 0.11, blue: 0.17)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: Aim preview overlay

    @ViewBuilder
    private var aimPreview: some View {
        if let start = dragStart, let current = dragCurrent {
            Path { p in
                p.move(to: start)
                p.addLine(to: current)
            }
            .stroke(
                Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.55),
                style: StrokeStyle(lineWidth: max(unit * 0.012, 1.5), lineCap: .round, dash: [unit * 0.05, unit * 0.04])
            )
            Circle()
                .fill(Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.85))
                .frame(width: chipRadius * 1.8, height: chipRadius * 1.8)
                .position(current)
        }
    }

    // MARK: Drawing

    private func drawScene(into ctx: GraphicsContext) {
        drawBin(into: ctx)
        for chip in chips {
            drawChip(chip, into: ctx)
        }
    }

    private func drawBin(into ctx: GraphicsContext) {
        let r = binRect
        let wt = wallThickness
        let rimColor = Color(red: 0.62, green: 0.66, blue: 0.82)
        let innerColor = Color(red: 0.13, green: 0.14, blue: 0.22)

        // Inner well (subtle, so empty bin is never blank-looking).
        let well = Path(roundedRect: r.insetBy(dx: wt * 0.4, dy: wt * 0.4),
                        cornerRadius: wt)
        ctx.fill(well, with: .color(innerColor))

        // Left wall
        let leftWall = Path(roundedRect: CGRect(x: r.minX - wt / 2, y: r.minY, width: wt, height: r.height),
                            cornerRadius: wt / 2)
        // Right wall
        let rightWall = Path(roundedRect: CGRect(x: r.maxX - wt / 2, y: r.minY, width: wt, height: r.height),
                             cornerRadius: wt / 2)
        // Floor
        let floor = Path(roundedRect: CGRect(x: r.minX - wt / 2, y: r.maxY - wt / 2, width: r.width + wt, height: wt),
                         cornerRadius: wt / 2)

        ctx.fill(leftWall, with: .color(rimColor))
        ctx.fill(rightWall, with: .color(rimColor))
        ctx.fill(floor, with: .color(rimColor))

        // Rim caps (highlight) so the rim reads as a tactile lip the chips hit.
        let cap = chipRadius * 0.5
        for x in [r.minX, r.maxX] {
            let dot = Path(ellipseIn: CGRect(x: x - cap, y: r.minY - cap, width: cap * 2, height: cap * 2))
            ctx.fill(dot, with: .color(Color(red: 0.85, green: 0.88, blue: 1.0)))
        }
    }

    private func drawChip(_ chip: GravityBinTossView_Chip, into ctx: GraphicsContext) {
        let rect = CGRect(x: chip.position.x - chip.radius,
                          y: chip.position.y - chip.radius,
                          width: chip.radius * 2,
                          height: chip.radius * 2)

        let base = chipColor(chip.hue)
        let highlight = chipColor(chip.hue, brighten: 0.28)

        // Soft contact shadow under the chip.
        let shadow = Path(ellipseIn: rect.offsetBy(dx: 0, dy: chip.radius * 0.35))
        ctx.fill(shadow, with: .color(Color.black.opacity(0.22)))

        // GravityBinTossView_Chip body with a radial sheen.
        let body = Path(ellipseIn: rect)
        ctx.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [highlight, base]),
                center: CGPoint(x: chip.position.x - chip.radius * 0.35,
                                y: chip.position.y - chip.radius * 0.35),
                startRadius: 0,
                endRadius: chip.radius * 1.4
            )
        )

        // Rim ring + a notch mark to convey spin.
        ctx.stroke(body, with: .color(Color.white.opacity(0.32)), lineWidth: max(chip.radius * 0.12, 0.6))

        let notchLen = chip.radius * 0.72
        var notch = Path()
        notch.move(to: chip.position)
        notch.addLine(to: CGPoint(x: chip.position.x + cos(chip.spin) * notchLen,
                                  y: chip.position.y + sin(chip.spin) * notchLen))
        ctx.stroke(notch, with: .color(Color.white.opacity(0.5)), lineWidth: max(chip.radius * 0.14, 0.7))
    }

    private func chipColor(_ hue: Double, brighten: Double = 0) -> Color {
        Color(hue: hue, saturation: 0.62, brightness: min(0.95, 0.78 + brighten))
    }

    // MARK: Physics tick

    private func tick(_ now: Date) {
        guard let last = lastTick else {
            lastTick = now
            return
        }
        let rawDt = now.timeIntervalSince(last)
        lastTick = now
        // Clamp dt: first frames / return-from-background must not fling chips through walls.
        let dt = CGFloat(min(max(rawDt, 0), 1.0 / 30.0))
        guard dt > 0 else { return }

        handleSpawning(now: now)
        if dt > 0 {
            stepPhysics(dt: dt, now: now.timeIntervalSince1970)
        }
        handleDemoReset(now: now)
    }

    // MARK: Spawning

    private func handleSpawning(now: Date) {
        guard demo else { return }
        guard !resetting else { return }
        spawnAccumulator += 1.0 / 60.0
        // One toss roughly every ~0.85s; cycle of fill -> reset handled separately.
        let interval: Double = 0.85
        if spawnAccumulator >= interval && chips.count < maxChips {
            spawnAccumulator = 0
            spawnDemoChip(now: now)
        }
    }

    private func spawnDemoChip(now: Date) {
        // Aim into the bin with a pleasing arc; vary slightly per toss.
        let target = CGPoint(x: binRect.midX + CGFloat.random(in: -binRect.width * 0.25...binRect.width * 0.25),
                             y: binRect.minY + binRect.height * 0.3)
        let vx = (target.x - spawnPoint.x) * 1.7
        let vy = -size.height * CGFloat.random(in: 1.05...1.35)
        spawnChip(at: spawnPoint,
                  velocity: CGVector(dx: vx, dy: vy),
                  now: now)
    }

    private func spawnChip(at point: CGPoint, velocity: CGVector, now: Date) {
        guard chips.count < maxChips else { return }
        let chip = GravityBinTossView_Chip(
            id: nextID,
            position: point,
            velocity: velocity,
            radius: chipRadius * CGFloat.random(in: 0.9...1.12),
            spin: CGFloat.random(in: 0...(.pi * 2)),
            spinRate: CGFloat.random(in: -6...6),
            hue: Double.random(in: 0...1),
            bornAt: now.timeIntervalSince1970
        )
        nextID += 1
        chips.append(chip)
    }

    // MARK: Demo reset (fade, never hard-clear)

    private func handleDemoReset(now: Date) {
        guard demo else { return }
        if resetting {
            fadeOut = max(0, fadeOut - 0.06)
            if fadeOut <= 0 {
                chips.removeAll()
                fadeOut = 1.0
                resetting = false
                spawnAccumulator = 0
            }
            return
        }
        // When the bin is full and everything settled, start a graceful fade reset.
        if chips.count >= maxChips && chips.allSatisfy({ $0.settled }) {
            resetting = true
        }
    }

    // MARK: Integration + collisions

    private func stepPhysics(dt: CGFloat, now: TimeInterval) {
        let restitution: CGFloat = 0.42
        let airDrag: CGFloat = 0.0
        let restSpeed: CGFloat = size.height * 0.06   // below this near support -> sleep
        let r = binRect
        let wt = wallThickness

        // 1. Integrate non-settled chips (gravity + motion + spin).
        for i in chips.indices {
            if chips[i].settled { continue }
            chips[i].velocity.dy += gravity * dt
            if airDrag > 0 {
                chips[i].velocity.dx *= (1 - airDrag * dt)
                chips[i].velocity.dy *= (1 - airDrag * dt)
            }
            chips[i].position.x += chips[i].velocity.dx * dt
            chips[i].position.y += chips[i].velocity.dy * dt
            chips[i].spin += chips[i].spinRate * dt
        }

        // 2. World collisions: bin walls / floor + overall bounds.
        for i in chips.indices {
            if chips[i].settled { continue }
            resolveWorld(index: i, rect: r, wallThickness: wt, restitution: restitution)
        }

        // 3. Pairwise chip-vs-chip collisions (N^2 over <=16 bodies).
        resolveChipPairs(restitution: restitution)

        // 4. Rest detection: a chip slow + supported goes to sleep.
        for i in chips.indices {
            if chips[i].settled { continue }
            let rad = chips[i].radius
            let onFloor = chips[i].position.y + rad >= floorY - 0.5
            let supported = onFloor || restingOnChip(i)
            let speed = hypot(chips[i].velocity.dx, chips[i].velocity.dy)
            if supported && speed < restSpeed {
                chips[i].velocity = .zero
                chips[i].spinRate *= 0.5
                chips[i].settled = true
            }
        }
    }

    private func resolveWorld(index i: Int, rect r: CGRect, wallThickness wt: CGFloat, restitution: CGFloat) {
        let rad = chips[i].radius
        // Floor of the bin.
        let fy = r.maxY - wt * 0.5
        if chips[i].position.y + rad > fy {
            // Only collide with floor if horizontally inside the bin mouth.
            if chips[i].position.x > r.minX - rad && chips[i].position.x < r.maxX + rad {
                let pen = (chips[i].position.y + rad) - fy
                chips[i].position.y -= pen
                if chips[i].velocity.dy > 0 {
                    chips[i].velocity.dy = -chips[i].velocity.dy * restitution
                    chips[i].velocity.dx *= 0.86
                    bumpCollision()
                }
            }
        }
        // Inner walls (only when below the rim line, so chips can drop in from above).
        let leftInner = r.minX + wt * 0.5
        let rightInner = r.maxX - wt * 0.5
        let belowRim = chips[i].position.y > r.minY
        if belowRim {
            if chips[i].position.x - rad < leftInner {
                let pen = leftInner - (chips[i].position.x - rad)
                chips[i].position.x += pen
                if chips[i].velocity.dx < 0 {
                    chips[i].velocity.dx = -chips[i].velocity.dx * restitution
                    bumpCollision()
                }
            }
            if chips[i].position.x + rad > rightInner {
                let pen = (chips[i].position.x + rad) - rightInner
                chips[i].position.x -= pen
                if chips[i].velocity.dx > 0 {
                    chips[i].velocity.dx = -chips[i].velocity.dx * restitution
                    bumpCollision()
                }
            }
        } else {
            // Above the rim: bounce off the rim lips so flung chips can ricochet.
            collideRimCap(index: i, capCenter: CGPoint(x: r.minX, y: r.minY), restitution: restitution)
            collideRimCap(index: i, capCenter: CGPoint(x: r.maxX, y: r.minY), restitution: restitution)
        }

        // Keep chips inside the overall view so nothing escapes off-screen.
        clampToBounds(index: i)
    }

    private func collideRimCap(index i: Int, capCenter: CGPoint, restitution: CGFloat) {
        let rad = chips[i].radius
        let capR = chipRadius * 0.5
        let dx = chips[i].position.x - capCenter.x
        let dy = chips[i].position.y - capCenter.y
        let dist = hypot(dx, dy)
        let minDist = rad + capR
        if dist < minDist && dist > 0.0001 {
            let nx = dx / dist
            let ny = dy / dist
            let pen = minDist - dist
            chips[i].position.x += nx * pen
            chips[i].position.y += ny * pen
            let vn = chips[i].velocity.dx * nx + chips[i].velocity.dy * ny
            if vn < 0 {
                chips[i].velocity.dx -= (1 + restitution) * vn * nx
                chips[i].velocity.dy -= (1 + restitution) * vn * ny
                bumpCollision()
            }
        }
    }

    private func clampToBounds(index i: Int) {
        let rad = chips[i].radius
        if chips[i].position.x < rad {
            chips[i].position.x = rad
            chips[i].velocity.dx = abs(chips[i].velocity.dx) * 0.4
        }
        if chips[i].position.x > size.width - rad {
            chips[i].position.x = size.width - rad
            chips[i].velocity.dx = -abs(chips[i].velocity.dx) * 0.4
        }
        if chips[i].position.y > size.height - rad {
            chips[i].position.y = size.height - rad
            if chips[i].velocity.dy > 0 {
                chips[i].velocity.dy = -chips[i].velocity.dy * 0.3
            }
        }
    }

    private func resolveChipPairs(restitution: CGFloat) {
        guard chips.count > 1 else { return }
        for a in 0..<(chips.count - 1) {
            for b in (a + 1)..<chips.count {
                resolvePair(a, b, restitution: restitution)
            }
        }
    }

    private func resolvePair(_ a: Int, _ b: Int, restitution: CGFloat) {
        let pa = chips[a].position
        let pb = chips[b].position
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let dist = hypot(dx, dy)
        let minDist = chips[a].radius + chips[b].radius
        guard dist < minDist else { return }

        let safeDist = dist > 0.0001 ? dist : 0.0001
        let nx = dx / safeDist
        let ny = dy / safeDist
        let pen = minDist - safeDist

        let aSettled = chips[a].settled
        let bSettled = chips[b].settled

        // Positional correction: push out by half the penetration (or full, if
        // one body is asleep, so the awake chip stacks on top cleanly).
        if aSettled && !bSettled {
            chips[b].position.x += nx * pen
            chips[b].position.y += ny * pen
        } else if bSettled && !aSettled {
            chips[a].position.x -= nx * pen
            chips[a].position.y -= ny * pen
        } else if !aSettled && !bSettled {
            chips[a].position.x -= nx * pen * 0.5
            chips[a].position.y -= ny * pen * 0.5
            chips[b].position.x += nx * pen * 0.5
            chips[b].position.y += ny * pen * 0.5
        } else {
            // Both settled and overlapping (rare) — nudge apart gently, stay asleep.
            chips[a].position.x -= nx * pen * 0.5
            chips[b].position.x += nx * pen * 0.5
            return
        }

        // Velocity response along the normal (equal mass).
        let rvx = chips[b].velocity.dx - chips[a].velocity.dx
        let rvy = chips[b].velocity.dy - chips[a].velocity.dy
        let vn = rvx * nx + rvy * ny
        guard vn < 0 else { return }

        let impulse = -(1 + restitution) * vn / 2
        if !aSettled {
            chips[a].velocity.dx -= impulse * nx
            chips[a].velocity.dy -= impulse * ny
            // A sleeping neighbor getting struck should wake if hit hard.
        }
        if !bSettled {
            chips[b].velocity.dx += impulse * nx
            chips[b].velocity.dy += impulse * ny
        }
        // Wake a settled chip only on a strong hit so the pile doesn't jitter.
        let strong = abs(vn) > size.height * 0.25
        if strong {
            if aSettled { chips[a].settled = false }
            if bSettled { chips[b].settled = false }
        }
        bumpCollision()
    }

    // Is chip i resting on top of any settled chip (for rest detection)?
    private func restingOnChip(_ i: Int) -> Bool {
        let pi = chips[i].position
        let ri = chips[i].radius
        for j in chips.indices where j != i {
            guard chips[j].settled else { continue }
            let dx = chips[j].position.x - pi.x
            let dy = chips[j].position.y - pi.y
            let dist = hypot(dx, dy)
            let touch = ri + chips[j].radius
            // Supported if a settled chip is essentially below/touching it.
            if dist <= touch + 1.0 && chips[j].position.y > pi.y {
                return true
            }
        }
        return false
    }

    private func bumpCollision() {
        // Only fire haptics in interactive mode; demo tiles must stay silent.
        guard !demo else { return }
        collisionCount &+= 1
    }

    // MARK: Gesture (interactive mode)

    private var flingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil { dragStart = value.startLocation }
                dragCurrent = value.location
            }
            .onEnded { value in
                let now = Date()
                // Velocity from predicted end translation (momentum), not raw drag.
                let predicted = value.predictedEndTranslation
                let drag = value.translation
                let scale: CGFloat = 6.0
                var vx = (predicted.width - drag.width) * scale
                var vy = (predicted.height - drag.height) * scale

                // If it was basically a tap, give it a gentle lob toward the bin.
                let predLen = hypot(predicted.width, predicted.height)
                if predLen < 6 {
                    vx = (binRect.midX - value.startLocation.x) * 1.6
                    vy = -size.height * 1.1
                }
                // Clamp launch speed so it never blows through walls.
                let maxSpeed = size.height * 6.0
                let speed = hypot(vx, vy)
                if speed > maxSpeed {
                    vx *= maxSpeed / speed
                    vy *= maxSpeed / speed
                }
                spawnChip(at: value.startLocation,
                          velocity: CGVector(dx: vx, dy: vy),
                          now: now)
                if chips.count > maxChips {
                    // FIFO drop the oldest settled chip to keep the cap.
                    if let idx = chips.firstIndex(where: { $0.settled }) {
                        chips.remove(at: idx)
                    }
                }
                dragStart = nil
                dragCurrent = nil
            }
    }
}
