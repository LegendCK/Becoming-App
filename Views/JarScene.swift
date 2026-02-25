//
//  JarScene.swift
//  Becoming
//
//  Created by admin56 on 25/02/26.
//


import SpriteKit
import UIKit

// MARK: - JarScene
// Spec: light-based glass (no hard outlines), subtle reflections,
// naturally accumulated papers, warm elliptical shadow.

final class JarScene: SKScene {

    // MARK: - Config

    private struct Config {
        // Jar shape
        let jarWidthRatio:   CGFloat = 0.68
        let jarHeightRatio:  CGFloat = 0.80
        let neckWidthRatio:  CGFloat = 0.66
        let rimHeight:       CGFloat = 15
        let shoulderYRatio:  CGFloat = 0.83

        // Papers — spec: -18° to +18°, scale variance 0.95–1.05
        let chitBase:        CGFloat = 28
        let chitVariance:    CGFloat = 7
        let maxPhysicsPapers: Int    = 32
        /// Max chits shown at once — jar never visually fills to the rim.
        /// Papers beyond this limit fade out silently (data is never lost).
        let maxVisualPapers: Int    = 48

        // Physics
        let gravity:     CGFloat = -4.2
        let damping:     CGFloat = 0.80
        let restitution: CGFloat = 0.04
        let friction:    CGFloat = 0.92
    }

    private let cfg = Config()

    private var papers:         [Paper]        = []
    private var paperNodes:     [UUID: SKNode] = [:]
    private var jarVisualNodes: [SKNode]       = []
    private var emptyStateNode: SKNode?
    private var boundaryNode:   SKNode?    /// IDs reserved for an upcoming animated drop — syncPaperNodes skips these
    /// so no static floor-node is placed before the drop animation fires.
    private var pendingDropIDs: Set<UUID>      = []
    // MARK: - Public API

    func load(papers: [Paper]) {
        self.papers = papers
        guard size.width > 0 else { return }
        syncPaperNodes()
        updateEmptyState()
    }

    /// Animate a single paper chit out of the jar, then remove it.
    func removePaper(id: UUID) {
        papers.removeAll { $0.id == id }
        guard let node = paperNodes[id] else { return }
        paperNodes.removeValue(forKey: id)
        let fade = SKAction.sequence([
            SKAction.fadeAlpha(to: 0, duration: 0.25),
            SKAction.removeFromParent()
        ])
        node.run(fade)
        updateEmptyState()
    }

    func dropPaper(_ paper: Paper) { 
        if !papers.contains(where: { $0.id == paper.id }) {
            papers.append(paper)
        }
        // If we're at the visual cap, evict the oldest displayed chit before
        // the new one lands — it fades away quietly as the fresh paper falls.
        evictOldestIfOverCapacity()
        // Clear reservation — syncPaperNodes may have skipped this ID,
        // so there is no stale static node to remove.
        pendingDropIDs.remove(paper.id)
        paperNodes[paper.id]?.removeFromParent()
        paperNodes.removeValue(forKey: paper.id)
        guard size.width > 0 else { return }
        let node = makeChitNode(paper: paper, index: papers.count - 1)
        paperNodes[paper.id] = node
        addChild(node)
        animateDrop(node: node)
        updateEmptyState()
    }

    /// Call this immediately after the paper is created and before the drop
    /// animation fires, so syncPaperNodes won't place a static node for it.
    func reserveForDrop(id: UUID) {
        pendingDropIDs.insert(id)
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: cfg.gravity)
        buildJar()
        buildBoundary()
        startIdleAnimation()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        jarVisualNodes.forEach { $0.removeFromParent() }
        jarVisualNodes.removeAll()
        boundaryNode?.removeFromParent()
        buildJar()
        buildBoundary()
        // Remove all paper nodes so syncPaperNodes re-places them with the
        // correct geometry. Without this, the `guard paperNodes[id] == nil`
        // guard inside syncPaperNodes skips existing nodes and leaves them
        // at the wrong positions from the initial (zero-size) layout pass.
        for (_, node) in paperNodes { node.removeFromParent() }
        paperNodes.removeAll()
        syncPaperNodes()
        updateEmptyState()
    }

    // MARK: - Geometry

    /// Jar body rect — padded top so rim never clips
    private var jarRect: CGRect {
        let w          = size.width  * cfg.jarWidthRatio
        let h          = size.height * cfg.jarHeightRatio
        let x          = (size.width - w) / 2
        let topPad     = cfg.rimHeight + 14
        let bottomPad: CGFloat = 18
        let availH     = size.height - topPad - bottomPad
        let y          = bottomPad + (availH - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func jarPath(for rect: CGRect) -> CGPath {
        let p     = CGMutablePath()
        let midX  = rect.midX
        let w     = rect.width, h = rect.height
        let neckL = midX - w * cfg.neckWidthRatio / 2
        let neckR = midX + w * cfg.neckWidthRatio / 2
        let shdY  = rect.minY + h * cfg.shoulderYRatio
        let si    = w * 0.014

        p.move(to: CGPoint(x: neckL, y: rect.maxY))
        p.addLine(to: CGPoint(x: neckR, y: rect.maxY))
        p.addCurve(
            to:       CGPoint(x: rect.maxX,         y: shdY),
            control1: CGPoint(x: neckR + w * 0.045, y: rect.maxY),
            control2: CGPoint(x: rect.maxX,         y: shdY + h * 0.05)
        )
        p.addLine(to: CGPoint(x: rect.maxX - si, y: rect.minY + h * 0.07))
        p.addCurve(
            to:       CGPoint(x: rect.minX + si, y: rect.minY + h * 0.07),
            control1: CGPoint(x: rect.maxX - si, y: rect.minY),
            control2: CGPoint(x: rect.minX + si, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.minX, y: shdY))
        p.addCurve(
            to:       CGPoint(x: neckL,              y: rect.maxY),
            control1: CGPoint(x: rect.minX,          y: shdY + h * 0.05),
            control2: CGPoint(x: neckL - w * 0.045,  y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }

    // MARK: - Build Jar (light-based, no hard outlines)

    private func addJ(_ node: SKNode) {
        addChild(node)
        jarVisualNodes.append(node)
    }

    private func buildJar() {
        let rect = jarRect
        let dark = isDark
        let jp   = jarPath(for: rect)

        // ── Warm elliptical ground shadow — anchored, narrow, ~10% ──
        // Feathered layers; pulled up so jar feels grounded not floating
        let shadowSizes: [(CGFloat, CGFloat, CGFloat)] = [
            (0.86, 18, 0.03),
            (0.70, 11, 0.055),
            (0.52, 6,  0.08)
        ]
        for (wRatio, hh, alpha) in shadowSizes {
            let s = SKShapeNode(ellipseOf: CGSize(width: rect.width * wRatio, height: hh))
            s.position    = CGPoint(x: rect.midX, y: rect.minY - 6)
            s.fillColor   = UIColor(red: 0.55, green: 0.50, blue: 0.45,
                                    alpha: dark ? alpha * 2.2 : alpha)
            s.strokeColor = .clear
            s.zPosition   = 1
            addJ(s)
        }

        // ── Jar body — warm glass tint, less blue, slight depth ──
        let body = SKShapeNode(path: jp)
        body.fillColor   = UIColor(red: 0.86, green: 0.87, blue: 0.86,
                                   alpha: dark ? 0.06 : 0.26)
        body.strokeColor = .clear
        body.zPosition   = 10
        addJ(body)

        // Subtle depth gradient: top of jar slightly lighter (warmer glass feel)
        let topTint = SKShapeNode(path: jarPath(for: rect.insetBy(dx: 0, dy: 0)))
        topTint.fillColor   = UIColor(red: 0.95, green: 0.93, blue: 0.88,
                                      alpha: dark ? 0.025 : 0.06)
        topTint.strokeColor = .clear
        topTint.zPosition   = 11
        addJ(topTint)

        // ── No hard outline — instead: outer light edge (light-based) ──
        // Left outer edge — catches ambient light
        let leftOuter = CGMutablePath()
        leftOuter.move(to: CGPoint(x: rect.minX + 1.5, y: rect.maxY - 4))
        leftOuter.addCurve(
            to:       CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.10),
            control1: CGPoint(x: rect.minX + 1, y: rect.midY + 30),
            control2: CGPoint(x: rect.minX + 2.5, y: rect.midY - 30)
        )
        let leftOuterNode = SKShapeNode(path: leftOuter)
        leftOuterNode.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.30 : 0.55)
        leftOuterNode.lineWidth   = 1.2
        leftOuterNode.lineCap     = .round
        leftOuterNode.zPosition   = 60
        addJ(leftOuterNode)

        // Right outer edge
        let rightOuter = CGMutablePath()
        rightOuter.move(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY - 4))
        rightOuter.addCurve(
            to:       CGPoint(x: rect.maxX - 2, y: rect.minY + rect.height * 0.10),
            control1: CGPoint(x: rect.maxX - 1, y: rect.midY + 30),
            control2: CGPoint(x: rect.maxX - 2.5, y: rect.midY - 30)
        )
        let rightOuterNode = SKShapeNode(path: rightOuter)
        rightOuterNode.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.12 : 0.28)
        rightOuterNode.lineWidth   = 1.0
        rightOuterNode.lineCap     = .round
        rightOuterNode.zPosition   = 60
        addJ(rightOuterNode)

        // Bottom base curve edge
        let baseEdge = CGMutablePath()
        baseEdge.move(to:    CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + 4))
        baseEdge.addQuadCurve(
            to:      CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + 4),
            control: CGPoint(x: rect.midX, y: rect.minY - 2)
        )
        let baseEdgeNode = SKShapeNode(path: baseEdge)
        baseEdgeNode.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.18 : 0.40)
        baseEdgeNode.lineWidth   = 1.0
        baseEdgeNode.zPosition   = 60
        addJ(baseEdgeNode)

        // ── Glass thickness — inner edge, 1px white 8% (spec) ──
        let innerRect = rect.insetBy(dx: 3, dy: 3)
        let innerEdge = SKShapeNode(path: jarPath(for: innerRect))
        innerEdge.fillColor   = .clear
        innerEdge.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.05 : 0.08)
        innerEdge.lineWidth   = 1.0
        innerEdge.zPosition   = 61
        addJ(innerEdge)

        // ── Left reflection — spec: 6-10%, gradient fade, slight curve ──
        // Simulate gradient by layering multiple ellipses with decreasing alpha
        let refX  = rect.minX + rect.width * 0.09
        let refW  = rect.width * 0.095
        let refTop    = rect.minY + rect.height * 0.08
        let refBottom = rect.maxY - cfg.rimHeight - rect.height * 0.05
        let refH  = refBottom - refTop

        // Bottom fade
        let refBottomNode = SKShapeNode(rect: CGRect(x: refX, y: refTop, width: refW, height: refH * 0.25))
        refBottomNode.fillColor   = UIColor.white.withAlphaComponent(0)
        refBottomNode.strokeColor = .clear
        refBottomNode.zPosition   = 62
        addJ(refBottomNode)

        // Core reflection — reduced 30%, shorter so it fades before the base
        let refPath = CGMutablePath()
        refPath.addRoundedRect(
            in: CGRect(x: refX + 1, y: refTop + refH * 0.22,
                       width: refW - 2, height: refH * 0.46),
            cornerWidth: (refW - 2) / 2,
            cornerHeight: (refW - 2) / 2
        )
        let refNode = SKShapeNode(path: refPath)
        refNode.fillColor   = UIColor.white.withAlphaComponent(dark ? 0.05 : 0.063)
        refNode.strokeColor = .clear
        refNode.zPosition   = 62
        addJ(refNode)

        // Top fade — brightens near lip only, doesn't reach mid-body
        let refTopPath = CGMutablePath()
        refTopPath.addRoundedRect(
            in: CGRect(x: refX, y: refBottom - refH * 0.15, width: refW, height: refH * 0.13),
            cornerWidth: refW / 2, cornerHeight: refW / 2
        )
        let refTopNode = SKShapeNode(path: refTopPath)
        refTopNode.fillColor   = UIColor.white.withAlphaComponent(dark ? 0.04 : 0.055)
        refTopNode.strokeColor = .clear
        refTopNode.zPosition   = 62
        addJ(refTopNode)

        // ── Very subtle glass overlay on papers (barely visible) ──
        let glassOver = SKShapeNode(path: jp)
        glassOver.fillColor   = UIColor.white.withAlphaComponent(dark ? 0.015 : 0.04)
        glassOver.strokeColor = .clear
        glassOver.zPosition   = 55
        addJ(glassOver)

        // ── Rim — cylindrical glass band ──
        let midX  = rect.midX
        let neckL = midX - rect.width * cfg.neckWidthRatio / 2 - 2
        let neckR = midX + rect.width * cfg.neckWidthRatio / 2 + 2
        let rimPath = CGMutablePath()
        rimPath.addRoundedRect(
            in: CGRect(x: neckL, y: rect.maxY - 3,
                       width: neckR - neckL,
                       height: cfg.rimHeight + 3),
            cornerWidth: 4, cornerHeight: 4
        )
        let rim = SKShapeNode(path: rimPath)
        rim.fillColor   = UIColor(red: 0.82, green: 0.87, blue: 0.92,
                                  alpha: dark ? 0.12 : 0.18)
        rim.strokeColor = .clear
        rim.zPosition   = 63
        addJ(rim)

        // Rim outer light edge
        let rimEdge = SKShapeNode(path: rimPath)
        rimEdge.fillColor   = .clear
        rimEdge.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.28 : 0.52)
        rimEdge.lineWidth   = 1.0
        rimEdge.zPosition   = 64
        addJ(rimEdge)

        // Rim top highlight (brightest point)
        let rimHL = CGMutablePath()
        rimHL.move(to:    CGPoint(x: neckL + 5,  y: rect.maxY + cfg.rimHeight - 1))
        rimHL.addQuadCurve(
            to:      CGPoint(x: neckR - 5,  y: rect.maxY + cfg.rimHeight - 1),
            control: CGPoint(x: midX, y: rect.maxY + cfg.rimHeight + 3)
        )
        let rimHLNode = SKShapeNode(path: rimHL)
        rimHLNode.strokeColor = UIColor.white.withAlphaComponent(dark ? 0.45 : 0.78)
        rimHLNode.lineWidth   = 2.0
        rimHLNode.lineCap     = .round
        rimHLNode.zPosition   = 65
        addJ(rimHLNode)
    }

    // MARK: - Physics Boundary

    private func buildBoundary() {
        boundaryNode?.removeFromParent()
        let rect   = jarRect
        let floorY = rect.minY + rect.height * 0.065
        let inset: CGFloat = 5
        let c = SKNode()

        func edge(_ a: CGPoint, _ b: CGPoint, fr: CGFloat = 0.92) {
            let n = SKNode()
            let body = SKPhysicsBody(edgeFrom: a, to: b)
            body.friction         = fr
            body.restitution      = cfg.restitution
            body.categoryBitMask  = 0x1 << 1
            body.collisionBitMask = 0x1 << 0
            n.physicsBody = body
            c.addChild(n)
        }

        edge(CGPoint(x: rect.minX + rect.width * 0.06, y: floorY),
             CGPoint(x: rect.maxX - rect.width * 0.06, y: floorY), fr: 0.95)
        edge(CGPoint(x: rect.minX + inset,     y: rect.minY + rect.height * 0.82),
             CGPoint(x: rect.minX + inset + 3, y: floorY + 4))
        edge(CGPoint(x: rect.maxX - inset,     y: rect.minY + rect.height * 0.82),
             CGPoint(x: rect.maxX - inset - 3, y: floorY + 4))

        addChild(c)
        boundaryNode = c
    }

    // MARK: - Chit Node
    // Crumpled paper ball: irregular closed blob, organic crumple crease lines.
    // SpriteKit y-axis is up; blob is centered at (0,0).

    private func makeChitNode(paper: Paper, index: Int) -> SKNode {
        let container = SKNode()

        // ── Deterministic size + crumple variance ──
        let rotSeed   = paper.rotation                  // -12…12
        let scaleSeed = abs(paper.xOffset).truncatingRemainder(dividingBy: 10) / 10.0
        let scale     = CGFloat(0.92 + scaleSeed * 0.16)
        let base      = cfg.chitBase * scale

        // Per-paper crumple nudge
        let cs = CGFloat(rotSeed * 0.30)  // ±3.6 pts max

        // ── Crumpled blob — polar coords, 10-point smooth closed path ──
        // Radius pattern gives the scrunched-ball silhouette.
        let radius = base * 0.62
        let numPts = 10
        let bumpPattern: [CGFloat] = [0.90, 1.10, 0.82, 1.12, 0.88, 1.08, 0.84, 1.14, 0.86, 1.06]
        let shift = abs(Int(rotSeed)) % numPts   // rotate pattern per paper

        var blobPts: [CGPoint] = []
        for i in 0..<numPts {
            let ri    = (i + shift) % numPts
            let angle = CGFloat(i) / CGFloat(numPts) * .pi * 2 - .pi / 2
            let r     = radius * bumpPattern[ri] + cs * 0.06
            blobPts.append(CGPoint(x: cos(angle) * r, y: sin(angle) * r))
        }

        // Smooth closed loop via midpoint quad curves
        let cp = CGMutablePath()
        let startMid = CGPoint(x: (blobPts[numPts-1].x + blobPts[0].x) / 2,
                               y: (blobPts[numPts-1].y + blobPts[0].y) / 2)
        cp.move(to: startMid)
        for i in 0..<numPts {
            let ctrl = blobPts[i]
            let next = blobPts[(i + 1) % numPts]
            let end  = CGPoint(x: (ctrl.x + next.x) / 2, y: (ctrl.y + next.y) / 2)
            cp.addQuadCurve(to: end, control: ctrl)
        }
        cp.closeSubpath()

        // ── Crumple crease lines — two curved strokes across the blob ──
        let crease1 = CGMutablePath()
        crease1.move(to:    CGPoint(x: -radius * 0.58 + cs * 0.10, y:  radius * 0.20 + cs * 0.06))
        crease1.addQuadCurve(
            to:      CGPoint(x:  radius * 0.50 + cs * 0.06, y: -radius * 0.24 - cs * 0.06),
            control: CGPoint(x:  cs * 0.12,                 y:  radius * 0.08))

        let crease2 = CGMutablePath()
        crease2.move(to:    CGPoint(x:  radius * 0.32 + cs * 0.08, y:  radius * 0.42 + cs * 0.04))
        crease2.addQuadCurve(
            to:      CGPoint(x: -radius * 0.28 - cs * 0.06, y: -radius * 0.38 - cs * 0.08),
            control: CGPoint(x:  radius * 0.04,             y: -radius * 0.04 + cs * 0.05))

        // ── Layer 1: cast shadow ──
        let castShadow = SKShapeNode(path: cp)
        castShadow.fillColor   = UIColor(red: 0.28, green: 0.22, blue: 0.16, alpha: 0.14)
        castShadow.strokeColor = .clear
        castShadow.position    = CGPoint(x: 2.2, y: -3.2)
        castShadow.zPosition   = CGFloat(index % 32) + 18
        container.addChild(castShadow)

        // ── Layer 2: contact shadow ──
        let contactShadow = SKShapeNode(path: cp)
        contactShadow.fillColor   = UIColor(red: 0.38, green: 0.30, blue: 0.22, alpha: 0.08)
        contactShadow.strokeColor = .clear
        contactShadow.position    = CGPoint(x: 1.0, y: -1.6)
        contactShadow.zPosition   = CGFloat(index % 32) + 19
        container.addChild(contactShadow)

        // ── Layer 3: chit body ──
        let chit = SKShapeNode(path: cp)
        chit.fillColor   = paperColor(for: index)
        chit.strokeColor = UIColor(red: 0.50, green: 0.42, blue: 0.30, alpha: 0.18)
        chit.lineWidth   = 0.5
        chit.lineJoin    = .round
        chit.zPosition   = CGFloat(index % 32) + 20
        container.addChild(chit)

        // ── Layer 4: crumple crease 1 ──
        let creaseLine1 = SKShapeNode(path: crease1)
        creaseLine1.strokeColor = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 0.22)
        creaseLine1.lineWidth   = 0.7
        creaseLine1.lineCap     = .round
        creaseLine1.zPosition   = CGFloat(index % 32) + 21
        container.addChild(creaseLine1)

        // ── Layer 5: crumple crease 2 ──
        let creaseLine2 = SKShapeNode(path: crease2)
        creaseLine2.strokeColor = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 0.16)
        creaseLine2.lineWidth   = 0.5
        creaseLine2.lineCap     = .round
        creaseLine2.zPosition   = CGFloat(index % 32) + 21
        container.addChild(creaseLine2)

        // ── Physics — circle matches the blob silhouette well ──
        let body = SKPhysicsBody(circleOfRadius: radius * 0.88)
        body.isDynamic      = true
        body.restitution    = cfg.restitution
        body.friction       = cfg.friction
        body.linearDamping  = cfg.damping
        body.angularDamping = 0.92
        body.mass           = 0.15
        body.categoryBitMask   = 0x1 << 0
        body.collisionBitMask  = (0x1 << 0) | (0x1 << 1)
        container.physicsBody  = body

        return container
    }

    // Warm beige palette — aged paper, no pure whites
    private func paperColor(for index: Int) -> UIColor {
        let variants: [UIColor] = [
            UIColor(red: 0.934, green: 0.906, blue: 0.852, alpha: 1), // warm ivory
            UIColor(red: 0.946, green: 0.922, blue: 0.874, alpha: 1), // light cream
            UIColor(red: 0.922, green: 0.894, blue: 0.838, alpha: 1), // deeper warm
            UIColor(red: 0.958, green: 0.934, blue: 0.890, alpha: 1), // pale parchment
            UIColor(red: 0.914, green: 0.885, blue: 0.828, alpha: 1), // warm mid
            UIColor(red: 0.940, green: 0.910, blue: 0.858, alpha: 1)  // neutral warm
        ]
        return variants[index % variants.count]
    }

    // MARK: - Sync

    /// Returns the IDs that should currently be visible (newest maxVisualPapers).
    private func visualWindow() -> Set<UUID> {
        Set(papers.suffix(cfg.maxVisualPapers).map(\.id))
    }

    /// Fade out and remove the oldest displayed chit when over the visual cap.
    private func evictOldestIfOverCapacity() {
        let window = visualWindow()
        // paperNodes may contain IDs about to be evicted — find ones outside window
        let toEvict = paperNodes.keys.filter { !window.contains($0) }
        for id in toEvict {
            guard let node = paperNodes[id] else { continue }
            paperNodes.removeValue(forKey: id)
            let fade = SKAction.sequence([
                SKAction.wait(forDuration: 0.15),          // slight delay — new paper is mid-fall
                SKAction.fadeAlpha(to: 0, duration: 0.55), // slow, gentle disappear
                SKAction.removeFromParent()
            ])
            node.run(fade)
        }
    }

    private func syncPaperNodes() {
        let existing = Set(paperNodes.keys)
        let current  = Set(papers.map(\.id))
        let window   = visualWindow()   // only the newest N

        // Remove nodes for deleted papers
        for id in existing.subtracting(current) {
            if let node = paperNodes[id] {
                let fade = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0, duration: 0.28),
                    SKAction.removeFromParent()
                ])
                node.run(fade)
            }
            paperNodes.removeValue(forKey: id)
        }

        // Fade out nodes that are outside the visual window (jar-full eviction)
        for id in existing.intersection(current).subtracting(window) {
            guard let node = paperNodes[id] else { continue }
            paperNodes.removeValue(forKey: id)
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.50),
                SKAction.removeFromParent()
            ])
            node.run(fade)
        }

        let rect    = jarRect
        let floorY  = rect.minY + rect.height * 0.10
        // Layout only within the visual window, newest papers on top
        let visiblePapers = papers.filter { window.contains($0.id) }
        let count   = visiblePapers.count
        let spacing = Swift.min(10.0, 100.0 / CGFloat(Swift.max(count, 1)))
        // Slight rightward bias — pile is naturally off-center, more human
        let pileOffset: CGFloat = 6.0

        for (index, paper) in visiblePapers.enumerated() {
            // Skip papers that are about to be animated in via dropPaper.
            guard !pendingDropIDs.contains(paper.id) else { continue }
            guard paperNodes[paper.id] == nil else { continue }
            let node = makeChitNode(paper: paper, index: index)
            // Wider rotation variance: stored -12…12, scaled ×1.8 → ±21.6°
            let visualRotation = CGFloat(paper.rotation) * 1.8 * .pi / 180
            // Wider x spread (0.85) + pile offset; every 4th paper leans near wall
            let wallLean: CGFloat = (index % 4 == 3)
                ? (paper.xOffset > 0 ? rect.width * 0.26 : -rect.width * 0.26)
                : CGFloat(paper.xOffset) * 0.85
            node.position  = CGPoint(
                x: rect.midX + wallLean + pileOffset,
                y: floorY + CGFloat(index) * spacing
            )
            node.zRotation = visualRotation
            node.physicsBody?.isDynamic = index >= count - cfg.maxPhysicsPapers
            addChild(node)
            paperNodes[paper.id] = node
        }
    }

    // MARK: - Drop
    // Spec: easeOut timing, natural gravity, no bounce exaggeration

    private func animateDrop(node: SKNode) {
        let rect = jarRect
        node.position  = CGPoint(
            x: rect.midX + CGFloat.random(in: -6...6),
            y: rect.maxY + 15
        )
        node.alpha     = 0
        node.zRotation = CGFloat.random(in: -0.30...0.30)
        node.physicsBody?.isDynamic = true

        node.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.03),
            SKAction.fadeIn(withDuration: 0.15)
        ]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak node] in
            node?.physicsBody?.applyImpulse(CGVector(
                dx: CGFloat.random(in: -0.5...0.5),
                dy: CGFloat.random(in: -0.4...(-0.1))
            ))
        }
    }

    // MARK: - Empty State

    private func updateEmptyState() {
        emptyStateNode?.removeFromParent()
        emptyStateNode = nil
        guard papers.isEmpty else { return }

        let rect = jarRect
        let c    = SKNode()

        let glow = SKShapeNode(path: jarPath(for: rect.insetBy(dx: 8, dy: 8)))
        glow.fillColor   = isDark
            ? UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.04)
            : UIColor(red: 0.90, green: 0.85, blue: 0.75, alpha: 0.18)
        glow.strokeColor = .clear
        glow.zPosition   = 12
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: isDark ? 0.12 : 0.35, duration: 2.6),
            SKAction.fadeAlpha(to: isDark ? 0.02 : 0.08, duration: 2.6)
        ])))
        c.addChild(glow)

        let label      = SKLabelNode(text: "Ready for your first")
        label.fontName = "Georgia-Italic"
        label.fontSize = 10.5
        label.fontColor = isDark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor(red: 0.28, green: 0.22, blue: 0.16, alpha: 0.35)
        label.position  = CGPoint(x: rect.midX, y: rect.midY - 8)
        label.zPosition = 13
        label.horizontalAlignmentMode = .center
        label.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.65, duration: 2.8),
            SKAction.fadeAlpha(to: 0.12, duration: 2.8)
        ])))
        c.addChild(label)

        c.zPosition = 12
        addChild(c)
        emptyStateNode = c
    }

    // MARK: - Idle

    private func startIdleAnimation() {
        let wait  = SKAction.wait(forDuration: 9.0, withRange: 5.0)
        let nudge = SKAction.run { [weak self] in
            self?.papers.suffix(3).forEach { p in
                self?.paperNodes[p.id]?.physicsBody?.applyImpulse(
                    CGVector(dx: CGFloat.random(in: -0.10...0.10),
                             dy: CGFloat.random(in: 0.03...0.12))
                )
            }
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, nudge])), withKey: "idle")
    }

    private var isDark: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }
}
