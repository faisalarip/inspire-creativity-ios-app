// catalog-id: nav-genie-magnify-dock
import SwiftUI

// MARK: - Genie Magnify Dock
// A macOS-style dock: icons magnify on a Gaussian bell-curve as the touch
// glides across, neighbors falling off smoothly, and a tapped icon stretches
// up into a "genie" squash before popping back to rest.
//
// demo == true  -> a TimelineView sweeps a synthetic touchX back and forth on a
//                  sine loop so the magnification travels along the dock with no
//                  finger. Base icons are always visible, so it is never blank.
// demo == false -> a DragGesture(minimumDistance: 0) feeds location.x into the
//                  live Gaussian scale, and a tap fires the genie squash-pop.

public struct GenieMagnifyDockView: View {
    public var demo: Bool = false

    public init(demo: Bool = false) {
        self.demo = demo
    }

    public var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if demo {
            GenieMagnifyDockView_DemoDock(size: size)
        } else {
            GenieMagnifyDockView_InteractiveDock(size: size)
        }
    }
}

// MARK: - Shared geometry / styling

private struct GenieMagnifyDockView_DockMetrics {
    let size: CGSize
    let iconCount: Int

    // The dock content sits in the lower portion of the tile, leaving headroom
    // above for magnified icons to grow upward.
    var contentWidth: CGFloat { size.width }

    // Icon footprint scales with the available size so it works at ~120pt and large.
    var iconSize: CGFloat {
        let byWidth = size.width / (CGFloat(iconCount) + 1.4)
        let byHeight = size.height * 0.30
        return max(14, min(byWidth, byHeight))
    }

    var spacing: CGFloat { iconSize * 0.34 }

    // The pitch between icon centers.
    var pitch: CGFloat { iconSize + spacing }

    var rowWidth: CGFloat {
        iconSize * CGFloat(iconCount) + spacing * CGFloat(max(iconCount - 1, 0))
    }

    var leadingInset: CGFloat { (size.width - rowWidth) / 2 }

    // Center x of icon i within the full size.
    func centerX(_ i: Int) -> CGFloat {
        leadingInset + iconSize / 2 + CGFloat(i) * pitch
    }

    // The dock floor: icons rest just above the bottom of the tile.
    var floorY: CGFloat { size.height - max(8, size.height * 0.10) }

    // Sigma is tied to the pitch so the bell spans ~2 neighbors at any size.
    var sigma: CGFloat { pitch * 1.15 }

    // How much an icon may grow at the peak of the bell.
    var amplitude: CGFloat { 0.95 }
}

// Gaussian magnification factor for an icon center given the touch x.
// Factored out (and fully annotated) to keep the type-checker fast.
private func gaussianScale(iconCenterX: CGFloat,
                           touchX: CGFloat?,
                           sigma: CGFloat,
                           amplitude: CGFloat) -> CGFloat {
    guard let touchX else { return 1.0 }
    let safeSigma: CGFloat = max(sigma, 0.0001)
    let d: CGFloat = touchX - iconCenterX
    let denom: CGFloat = 2.0 * safeSigma * safeSigma
    let bell: CGFloat = exp(-(d * d) / denom)
    return 1.0 + amplitude * bell
}

private let dockIconNames: [String] = [
    "house.fill",
    "magnifyingglass",
    "bubble.left.fill",
    "heart.fill",
    "camera.fill",
    "gearshape.fill"
]

private let dockIconColors: [Color] = [
    Color(red: 0.36, green: 0.62, blue: 0.98),
    Color(red: 0.42, green: 0.80, blue: 0.55),
    Color(red: 0.98, green: 0.72, blue: 0.30),
    Color(red: 0.95, green: 0.42, blue: 0.50),
    Color(red: 0.62, green: 0.50, blue: 0.96),
    Color(red: 0.50, green: 0.78, blue: 0.86)
]

// MARK: - A single dock icon

private struct GenieMagnifyDockView_DockIcon: View {
    let index: Int
    let metrics: GenieMagnifyDockView_DockMetrics
    let touchX: CGFloat?
    let isPopping: Bool

    private var iconName: String {
        dockIconNames[index % dockIconNames.count]
    }

    private var iconColor: Color {
        dockIconColors[index % dockIconColors.count]
    }

    private var magnify: CGFloat {
        gaussianScale(iconCenterX: metrics.centerX(index),
                      touchX: touchX,
                      sigma: metrics.sigma,
                      amplitude: metrics.amplitude)
    }

    var body: some View {
        tile
            .frame(width: metrics.iconSize, height: metrics.iconSize)
            // The genie modifier applies the live magnify (anchored to the dock
            // floor so icons grow upward) AND the squash-pop in one scaleEffect,
            // so magnification is applied exactly once.
            .geniePop(active: isPopping, baseScale: magnify)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: touchX == nil)
    }

    private var tile: some View {
        let r: CGFloat = metrics.iconSize * 0.26
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [iconColor, iconColor.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
            )
            .overlay(
                Image(systemName: iconName)
                    .font(.system(size: metrics.iconSize * 0.46, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
            )
            .shadow(color: Color.black.opacity(0.30),
                    radius: metrics.iconSize * 0.14,
                    y: metrics.iconSize * 0.10)
    }
}

// MARK: - Genie squash-pop modifier (KeyframeAnimator, iOS 17)

private struct GenieMagnifyDockView_GeniePop: ViewModifier {
    let active: Bool
    let baseScale: CGFloat

    struct Frame {
        var stretchY: CGFloat = 1.0
        var squashX: CGFloat = 1.0
        var lift: CGFloat = 0.0
        var glow: CGFloat = 0.0
    }

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(
                initialValue: Frame(),
                trigger: active
            ) { view, frame in
                view
                    // Combine the live magnify with the genie stretch/squash.
                    .scaleEffect(
                        x: baseScale * frame.squashX,
                        y: baseScale * frame.stretchY,
                        anchor: .bottom
                    )
                    .offset(y: -frame.lift)
                    .overlay(glowOverlay(frame.glow))
            } keyframes: { _ in
                // Tall genie stretch, then a brief squash, then settle to base (1.0).
                KeyframeTrack(\.stretchY) {
                    SpringKeyframe(1.55, duration: 0.16, spring: .snappy)
                    CubicKeyframe(0.80, duration: 0.10)
                    SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
                }
                KeyframeTrack(\.squashX) {
                    SpringKeyframe(0.74, duration: 0.16, spring: .snappy)
                    CubicKeyframe(1.14, duration: 0.10)
                    SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
                }
                KeyframeTrack(\.lift) {
                    SpringKeyframe(1.0, duration: 0.16, spring: .snappy)
                    CubicKeyframe(1.0, duration: 0.10)
                    SpringKeyframe(0.0, duration: 0.30, spring: .bouncy)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(1.0, duration: 0.16)
                    LinearKeyframe(0.0, duration: 0.40)
                }
            }
    }

    private func glowOverlay(_ amount: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.white.opacity(Double(amount) * 0.9), lineWidth: 2)
            .blur(radius: 3)
            .opacity(Double(amount))
            .allowsHitTesting(false)
    }
}

private extension View {
    func geniePop(active: Bool, baseScale: CGFloat) -> some View {
        modifier(GenieMagnifyDockView_GeniePop(active: active, baseScale: baseScale))
    }
}

// MARK: - The dock row + tray (shared chrome)

private struct GenieMagnifyDockView_DockRow: View {
    let metrics: GenieMagnifyDockView_DockMetrics
    let touchX: CGFloat?
    let poppingIndex: Int?

    var body: some View {
        ZStack {
            tray
            icons
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
    }

    private var tray: some View {
        // A frosted dock tray pinned to the floor.
        let trayHeight: CGFloat = metrics.iconSize * 1.5
        let trayWidth: CGFloat = metrics.rowWidth + metrics.iconSize * 0.9
        return RoundedRectangle(cornerRadius: trayHeight * 0.32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.92),
                        Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: trayHeight * 0.32, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .frame(width: max(trayWidth, 0), height: trayHeight)
            .position(x: metrics.size.width / 2,
                      y: metrics.floorY - trayHeight / 2 + metrics.iconSize * 0.18)
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 6)
    }

    private var icons: some View {
        ForEach(0..<metrics.iconCount, id: \.self) { i in
            GenieMagnifyDockView_DockIcon(
                index: i,
                metrics: metrics,
                touchX: touchX,
                isPopping: poppingIndex == i
            )
            // Bottom-anchored so the icon foot rests on the floor and grows up.
            .position(x: metrics.centerX(i),
                      y: metrics.floorY - metrics.iconSize / 2)
        }
    }
}

// MARK: - Demo (self-driving) dock

private struct GenieMagnifyDockView_DemoDock: View {
    let size: CGSize

    private var metrics: GenieMagnifyDockView_DockMetrics {
        GenieMagnifyDockView_DockMetrics(size: size, iconCount: resolvedCount)
    }

    private var resolvedCount: Int {
        // Fewer icons in a cramped tile, more when there's room.
        size.width < 220 ? 5 : 6
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let touchX = sweepX(at: t)
            let popping = autoPopIndex(at: t)
            GenieMagnifyDockView_DockRow(metrics: metrics, touchX: touchX, poppingIndex: popping)
        }
    }

    // Sine sweep eases at the turnarounds (no sawtooth snap).
    private func sweepX(at t: TimeInterval) -> CGFloat {
        let period: Double = 3.2
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        let s = (sin(phase * 2.0 * .pi - .pi / 2) + 1.0) / 2.0  // 0...1 eased
        let left = metrics.centerX(0)
        let right = metrics.centerX(metrics.iconCount - 1)
        return left + CGFloat(s) * (right - left)
    }

    // Pop the icon nearest the synthetic touch each time the sweep reverses
    // near an end, keyed so the KeyframeAnimator retriggers cleanly.
    private func autoPopIndex(at t: TimeInterval) -> Int? {
        let popPeriod: Double = 3.2
        let slot = Int(t / popPeriod)
        // Alternate ends so the genie pop is visible on both sides over time.
        return slot.isMultiple(of: 2) ? (metrics.iconCount - 1) : 0
    }
}

// MARK: - Interactive dock

private struct GenieMagnifyDockView_InteractiveDock: View {
    let size: CGSize

    @State private var touchX: CGFloat? = nil
    @State private var poppingIndex: Int? = nil

    private var metrics: GenieMagnifyDockView_DockMetrics {
        GenieMagnifyDockView_DockMetrics(size: size, iconCount: resolvedCount)
    }

    private var resolvedCount: Int {
        size.width < 220 ? 5 : 6
    }

    var body: some View {
        GenieMagnifyDockView_DockRow(metrics: metrics, touchX: touchX, poppingIndex: poppingIndex)
            .contentShape(Rectangle())
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        // minimumDistance: 0 so the piece wins inside a ScrollView.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchX = value.location.x
            }
            .onEnded { value in
                fireGenie(at: value.location.x)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                    touchX = nil
                }
            }
    }

    // A drag that ends on/over an icon fires the genie squash-pop on it.
    private func fireGenie(at x: CGFloat) {
        guard let i = nearestIcon(to: x) else { return }
        let dx = abs(x - metrics.centerX(i))
        guard dx <= metrics.iconSize * 0.75 else { return }
        poppingIndex = nil
        DispatchQueue.main.async {
            poppingIndex = i
        }
    }

    private func nearestIcon(to x: CGFloat) -> Int? {
        guard metrics.iconCount > 0 else { return nil }
        var best = 0
        var bestD = CGFloat.greatestFiniteMagnitude
        for i in 0..<metrics.iconCount {
            let d = abs(x - metrics.centerX(i))
            if d < bestD { bestD = d; best = i }
        }
        return best
    }
}
