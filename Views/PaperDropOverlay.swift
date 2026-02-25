//
//  CrumpledBallShape.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI
import Combine

// MARK: - CrumpledBallShape
// Irregular closed blob — 10 polar points with bumpy radius variance,
// smoothed via midpoint quad curves. Reads unmistakably as a crumpled paper ball.

private struct CrumpledBallShape: Shape {
    func path(in r: CGRect) -> Path {
        let cx     = r.midX, cy = r.midY
        let rx     = r.width  * 0.44
        let ry     = r.height * 0.44
        let numPts = 10
        let radii: [CGFloat] = [0.90, 1.10, 0.82, 1.12, 0.88, 1.08, 0.84, 1.14, 0.86, 1.06]

        var pts: [CGPoint] = []
        for i in 0..<numPts {
            let angle = CGFloat(i) / CGFloat(numPts) * .pi * 2 - .pi / 2
            let rr    = radii[i]
            pts.append(CGPoint(x: cx + cos(angle) * rx * rr,
                               y: cy + sin(angle) * ry * rr))
        }

        var p    = Path()
        let mid0 = CGPoint(x: (pts[numPts-1].x + pts[0].x) / 2,
                           y: (pts[numPts-1].y + pts[0].y) / 2)
        p.move(to: mid0)
        for i in 0..<numPts {
            let ctrl = pts[i]
            let next = pts[(i + 1) % numPts]
            let end  = CGPoint(x: (ctrl.x + next.x) / 2, y: (ctrl.y + next.y) / 2)
            p.addQuadCurve(to: end, control: ctrl)
        }
        p.closeSubpath()
        return p
    }
}

// Crumple crease 1 — diagonal across the ball
private struct CrumpleCrease1: Shape {
    func path(in r: CGRect) -> Path {
        let cx = r.midX, cy = r.midY
        let rx = r.width * 0.40, ry = r.height * 0.40
        var p = Path()
        p.move(to:    CGPoint(x: cx - rx * 0.72, y: cy + ry * 0.25))
        p.addQuadCurve(to:      CGPoint(x: cx + rx * 0.62, y: cy - ry * 0.30),
                       control: CGPoint(x: cx + rx * 0.05, y: cy + ry * 0.10))
        return p
    }
}

// Crumple crease 2 — opposite diagonal
private struct CrumpleCrease2: Shape {
    func path(in r: CGRect) -> Path {
        let cx = r.midX, cy = r.midY
        let rx = r.width * 0.38, ry = r.height * 0.38
        var p = Path()
        p.move(to:    CGPoint(x: cx + rx * 0.40, y: cy + ry * 0.52))
        p.addQuadCurve(to:      CGPoint(x: cx - rx * 0.35, y: cy - ry * 0.48),
                       control: CGPoint(x: cx + rx * 0.05, y: cy - ry * 0.05))
        return p
    }
}

// MARK: - PaperView

private struct PaperView: View {
    let width:  CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // ── Blob body with warm radial gradient ──
            CrumpledBallShape()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.980, green: 0.966, blue: 0.936), location: 0.00),
                            .init(color: Color(red: 0.958, green: 0.942, blue: 0.908), location: 0.55),
                            .init(color: Color(red: 0.928, green: 0.905, blue: 0.865), location: 1.00)
                        ]),
                        center: .init(x: 0.38, y: 0.36),
                        startRadius: 0,
                        endRadius: width * 0.55
                    )
                )
                .shadow(color: .black.opacity(0.20), radius: 7, x: 2, y: 4)
                .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)

            // ── Crumple crease 1 ──
            CrumpleCrease1()
                .stroke(Color(red: 0.36, green: 0.28, blue: 0.20).opacity(0.22), lineWidth: 0.8)

            // ── Crumple crease 2 ──
            CrumpleCrease2()
                .stroke(Color(red: 0.36, green: 0.28, blue: 0.20).opacity(0.16), lineWidth: 0.6)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - PaperDropOverlay
// Animation is driven entirely by TimelineView at display refresh rate —
// no DispatchQueue seams, no jank between phases.

struct PaperDropOverlay: View {

    @Binding var isDropping: Bool
    let jarFrame: CGRect
    let onReachJar: () -> Void

    @State private var phase:      DropPhase = .idle
    @State private var startDate:  Date?     = nil

    // Captured once at start — stable across all frames
    @State private var animFrom:   CGPoint = .zero
    @State private var animTo:     CGPoint = .zero
    @State private var animCP1:    CGPoint = .zero
    @State private var animCP2:    CGPoint = .zero
    @State private var rotDir:     Double  = 1      // flutter direction seed

    private enum DropPhase { case idle, active, done }

    // Tall portrait note — clearly a slip of paper, not a block
    private let noteW: CGFloat = 42
    private let noteH: CGFloat = 54
    private let totalDuration: TimeInterval = 1.1

    var body: some View {
        GeometryReader { _ in
            if phase == .active, let start = startDate {
                TimelineView(.animation) { ctx in
                    let elapsed = ctx.date.timeIntervalSince(start)
                    let props   = frame(at: elapsed)
                    if props.opacity > 0.005 {
                        PaperView(width: noteW, height: noteH)
                            .rotationEffect(.degrees(props.rotation))
                            .scaleEffect(props.scale)
                            .opacity(props.opacity)
                            .position(props.position)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)  // purely decorative animation
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onReceive(Just(isDropping)) { dropping in
            if dropping && phase == .idle { begin() }
        }
    }

    // MARK: - Per-frame computation (math, no SwiftUI interpolation)

    private struct Props {
        let position: CGPoint
        let rotation: Double
        let scale:    CGFloat
        let opacity:  Double
    }

    private func frame(at elapsed: TimeInterval) -> Props {
        let t = min(elapsed / totalDuration, 1.0)   // 0 → 1

        // ── Position: cubic Bézier ──
        let pos = bezier(animFrom, animCP1, animCP2, animTo, t)

        // ── Rotation: damped sinusoidal flutter ──
        // Frequency ramps up slightly as gravity accelerates the paper.
        // Direction inverts once mid-fall for realism.
        let freq   = 3.0 + t * 1.2
        let damp   = 1.0 - t * 0.42
        let flutter = rotDir * sin(t * .pi * freq) * 20.0 * damp

        // ── Scale: gentle shrink as paper enters jar mouth ──
        let s = CGFloat(lerp(1.02, 0.62, easeIn(t)))

        // ── Opacity: fade in 0→8%, hold, fade out 78→100% ──
        let opacity: Double
        switch t {
        case ..<0.08: opacity = t / 0.08
        case 0.78...: opacity = max(0, 1 - (t - 0.78) / 0.22)
        default:      opacity = 1
        }

        return Props(position: pos, rotation: flutter, scale: s, opacity: opacity)
    }

    // MARK: - Start

    private func begin() {
        guard phase == .idle else { return }
        // Skip visual arc animation when Reduce Motion is on — physics still fires.
        if UIAccessibility.isReduceMotionEnabled {
            onReachJar()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isDropping = false
            }
            return
        }

        let screen = UIScreen.main.bounds
        let fromX  = screen.midX + CGFloat.random(in: -8...8)
        let fromY  = screen.maxY - 126
        let toX    = jarFrame.midX
        let toY    = jarFrame.minY + 18

        // Control points create a lazy S-curve with lateral drift
        animFrom = CGPoint(x: fromX, y: fromY)
        animTo   = CGPoint(x: toX,   y: toY)
        animCP1  = CGPoint(
            x: lerp(fromX, toX, 0.28) + CGFloat.random(in:  10...22),
            y: lerp(fromY, toY, 0.28)
        )
        animCP2  = CGPoint(
            x: lerp(fromX, toX, 0.64) + CGFloat.random(in: -20...(-8)),
            y: lerp(fromY, toY, 0.64)
        )
        rotDir    = Bool.random() ? 1 : -1
        startDate = Date()
        phase     = .active

        // Physics hand-off — fire while paper is still visually above rim
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration * 0.84) {
            onReachJar()
        }
        // Cleanup once opacity reaches 0
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.06) {
            phase      = .done
            isDropping = false
            startDate  = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { phase = .idle }
        }
    }

    // MARK: - Math

    private func bezier(_ p0: CGPoint, _ p1: CGPoint,
                        _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        let t  = CGFloat(t), mt = 1 - t
        return CGPoint(
            x: mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x,
            y: mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func easeIn(_ t: Double) -> Double {
        t * t * t
    }
}
