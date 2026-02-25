//
//  SplashView.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SwiftUI

// MARK: - SplashView
// Shows every app open. Wordmark + jar animate in together.
// Clean, still, intentional — like the app itself.

struct SplashView: View {

    let onComplete: () -> Void

    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset:  Double = 8
    @State private var jarOpacity:      Double = 0
    @State private var jarScale:        Double = 0.94

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // ── Jar ──
                SplashJarView()
                    .frame(width: 210, height: 230)
                    .opacity(jarOpacity)
                    .scaleEffect(jarScale)
                    .accessibilityHidden(true)

                Spacer().frame(height: 40)

                // ── Wordmark ──
                VStack(spacing: 8) {
                    Text("BECOMING")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(5.5)
                        .foregroundStyle(Color(.label).opacity(0.40))

                    Text("A jar for who you're becoming")
                        .font(.system(size: 14, weight: .light).italic())
                        .foregroundStyle(Color(.label).opacity(0.26))
                }
                .opacity(wordmarkOpacity)
                .offset(y: wordmarkOffset)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Becoming. A jar for who you're becoming.")

                Spacer()
                Spacer().frame(height: 60) // visual weight toward top-center
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        // Announce app name to VoiceOver users
        UIAccessibility.post(notification: .screenChanged, argument: "Becoming")

        // Jar fades + scales in
        withAnimation(.easeOut(duration: 0.80).delay(0.30)) {
            jarOpacity = 1
            jarScale   = 1
        }

        // Wordmark drifts up and fades in shortly after
        withAnimation(.easeOut(duration: 0.65).delay(0.60)) {
            wordmarkOpacity = 1
            wordmarkOffset  = 0
        }

        // Hold, then signal completion — parent handles transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.40) {
            onComplete()
        }
    }
}

// MARK: - SplashJarView
// Pure SwiftUI Canvas — photorealistic glass jar, no SpriteKit overhead.
// Shared between SplashView and OnboardingView.

struct SplashJarView: View {

    var paperCount: Int = 0  // 0 = empty, pass >0 to show paper chits inside

    var body: some View {
        Canvas { ctx, size in
            drawJar(ctx: ctx, size: size)
            if paperCount > 0 { drawPapers(ctx: ctx, size: size) }
        }
    }

    private func drawJar(ctx: GraphicsContext, size: CGSize) {
        let w    = size.width
        let h    = size.height
        let midX = w / 2

        // ── Geometry ──
        let neckW   = w * 0.60
        let neckL   = midX - neckW / 2
        let neckR   = midX + neckW / 2
        let bodyTop = h * 0.18
        let baseY   = h * 0.90
        let rimH: CGFloat = 16

        // ── Body path ──
        var body = Path()
        body.move(to: CGPoint(x: neckL, y: bodyTop))
        body.addLine(to: CGPoint(x: neckR, y: bodyTop))
        body.addCurve(
            to:       CGPoint(x: w * 0.95, y: h * 0.30),
            control1: CGPoint(x: neckR + w * 0.045, y: bodyTop),
            control2: CGPoint(x: w * 0.95,           y: h * 0.24)
        )
        body.addLine(to: CGPoint(x: w * 0.955, y: baseY - 8))
        body.addQuadCurve(
            to:      CGPoint(x: w * 0.045, y: baseY - 8),
            control: CGPoint(x: midX, y: baseY + 5)
        )
        body.addLine(to: CGPoint(x: w * 0.05, y: h * 0.30))
        body.addCurve(
            to:       CGPoint(x: neckL, y: bodyTop),
            control1: CGPoint(x: w * 0.05,            y: h * 0.24),
            control2: CGPoint(x: neckL - w * 0.045,   y: bodyTop)
        )
        body.closeSubpath()

        // ── Layer 1: Ground shadow ──
        let shadowRect = CGRect(x: w * 0.12, y: baseY + 3, width: w * 0.76, height: 14)
        ctx.fill(Path(ellipseIn: shadowRect),
                 with: .color(.init(red: 0.50, green: 0.44, blue: 0.38, opacity: 0.07)))
        let shadowInner = CGRect(x: w * 0.22, y: baseY + 5, width: w * 0.56, height: 8)
        ctx.fill(Path(ellipseIn: shadowInner),
                 with: .color(.init(red: 0.50, green: 0.44, blue: 0.38, opacity: 0.08)))

        // ── Layer 2: Glass body fill ──
        ctx.fill(body,
                 with: .color(.init(red: 0.84, green: 0.88, blue: 0.90, opacity: 0.18)))

        // ── Layer 3: Inner warm ambient ──
        var innerBody = Path()
        let inset: CGFloat = 5
        let innerNeckL = neckL + inset, innerNeckR = neckR - inset
        innerBody.move(to: CGPoint(x: innerNeckL, y: bodyTop + inset))
        innerBody.addLine(to: CGPoint(x: innerNeckR, y: bodyTop + inset))
        innerBody.addCurve(
            to:       CGPoint(x: w * 0.95 - inset, y: h * 0.30 + inset),
            control1: CGPoint(x: innerNeckR + w * 0.03, y: bodyTop + inset),
            control2: CGPoint(x: w * 0.95 - inset,      y: h * 0.25)
        )
        innerBody.addLine(to: CGPoint(x: w * 0.955 - inset, y: baseY - 12))
        innerBody.addQuadCurve(
            to:      CGPoint(x: w * 0.045 + inset, y: baseY - 12),
            control: CGPoint(x: midX, y: baseY)
        )
        innerBody.addLine(to: CGPoint(x: w * 0.05 + inset, y: h * 0.30 + inset))
        innerBody.addCurve(
            to:       CGPoint(x: innerNeckL, y: bodyTop + inset),
            control1: CGPoint(x: w * 0.05 + inset,       y: h * 0.25),
            control2: CGPoint(x: innerNeckL - w * 0.03,  y: bodyTop + inset)
        )
        innerBody.closeSubpath()
        ctx.fill(innerBody,
                 with: .color(.init(red: 0.97, green: 0.95, blue: 0.90, opacity: 0.18)))

        // ── Layer 4: Left broad highlight (main glass sheen) ──
        var streak = Path()
        streak.addRoundedRect(
            in: CGRect(x: w * 0.095, y: h * 0.27, width: w * 0.088, height: h * 0.52),
            cornerSize: CGSize(width: w * 0.044, height: w * 0.044)
        )
        ctx.fill(streak, with: .color(.white.opacity(0.10)))

        // ── Layer 5: Left edge highlight ──
        var leftEdge = Path()
        leftEdge.move(to:    CGPoint(x: w * 0.065, y: h * 0.31))
        leftEdge.addCurve(
            to:       CGPoint(x: w * 0.072, y: baseY - 16),
            control1: CGPoint(x: w * 0.058, y: h * 0.52),
            control2: CGPoint(x: w * 0.075, y: h * 0.70)
        )
        ctx.stroke(leftEdge,
                   with: .color(.white.opacity(0.60)),
                   style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        // ── Layer 6: Right edge reflection ──
        var rightEdge = Path()
        rightEdge.move(to:    CGPoint(x: w * 0.935, y: h * 0.31))
        rightEdge.addLine(to: CGPoint(x: w * 0.928, y: baseY - 18))
        ctx.stroke(rightEdge,
                   with: .color(.white.opacity(0.22)),
                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        // ── Layer 7: Base curve edge ──
        var baseEdge = Path()
        baseEdge.move(to:    CGPoint(x: w * 0.15, y: baseY - 2))
        baseEdge.addQuadCurve(
            to:      CGPoint(x: w * 0.85, y: baseY - 2),
            control: CGPoint(x: midX, y: baseY + 4)
        )
        ctx.stroke(baseEdge,
                   with: .color(.white.opacity(0.35)),
                   style: StrokeStyle(lineWidth: 1.0))

        // ── Layer 8: Glass inner edge (thickness) ──
        ctx.stroke(innerBody,
                   with: .color(.white.opacity(0.07)),
                   style: StrokeStyle(lineWidth: 1.0))

        // ── Layer 9: Body outline — light-based, not hard border ──
        ctx.stroke(body,
                   with: .color(.init(red: 0.52, green: 0.60, blue: 0.66, opacity: 0.42)),
                   style: StrokeStyle(lineWidth: 1.4))

        // ── Layer 10: Rim ──
        let rimRect = CGRect(x: neckL - 3, y: bodyTop - rimH,
                             width: neckW + 6, height: rimH + 3)
        let rim = Path(roundedRect: rimRect, cornerRadius: 4.5)
        ctx.fill(rim,
                 with: .color(.init(red: 0.80, green: 0.86, blue: 0.91, opacity: 0.28)))
        ctx.stroke(rim,
                   with: .color(.white.opacity(0.48)),
                   style: StrokeStyle(lineWidth: 1.0))

        // Rim top highlight arc
        var rimHL = Path()
        rimHL.move(to:    CGPoint(x: neckL + 5, y: bodyTop - rimH + 2))
        rimHL.addQuadCurve(
            to:      CGPoint(x: neckR - 5, y: bodyTop - rimH + 2),
            control: CGPoint(x: midX, y: bodyTop - rimH - 3)
        )
        ctx.stroke(rimHL,
                   with: .color(.white.opacity(0.80)),
                   style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    // Papers rendered as warm beige chits piled at the bottom of the jar
    private func drawPapers(ctx: GraphicsContext, size: CGSize) {
        let w    = size.width
        let h    = size.height
        let midX = w / 2
        let baseY = h * 0.90

        // Deterministic chit positions — feels settled, not random
        let chits: [(CGFloat, CGFloat, CGFloat)] = [
            (midX - 22, baseY - 22, -12),
            (midX + 14, baseY - 20, 8),
            (midX - 6,  baseY - 36, 3),
            (midX + 28, baseY - 34, -6),
            (midX - 28, baseY - 38, 15),
        ]

        let count = Swift.min(paperCount, chits.count)
        for i in 0..<count {
            let (cx, cy, deg) = chits[i]
            let rad = CGFloat(deg) * .pi / 180
            let cw: CGFloat = 28, ch: CGFloat = 24

            var ctx2 = ctx
            ctx2.transform = CGAffineTransform(translationX: cx, y: cy)
                .rotated(by: rad)

            // Shadow
            let shadowRect = CGRect(x: -cw/2 + 1.5, y: -ch/2 + 2, width: cw, height: ch)
            ctx2.fill(Path(shadowRect),
                      with: .color(.init(red: 0.38, green: 0.32, blue: 0.24, opacity: 0.09)))

            // Chit body
            let variants: [(Double, Double, Double)] = [
                (0.929, 0.902, 0.847),
                (0.941, 0.918, 0.871),
                (0.918, 0.890, 0.835),
            ]
            let (r, g, b) = variants[i % 3]
            let chitRect = CGRect(x: -cw/2, y: -ch/2, width: cw, height: ch)
            ctx2.fill(Path(chitRect),
                      with: .color(.init(red: r, green: g, blue: b, opacity: 1)))
            ctx2.stroke(Path(chitRect),
                        with: .color(.init(red: 0.62, green: 0.55, blue: 0.44, opacity: 0.14)),
                        style: StrokeStyle(lineWidth: 0.5))
        }
    }
}
