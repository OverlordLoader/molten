import SpriteKit
import UIKit

/// Procedural visual core for Molten: studio backdrop, molten glass, cooled pieces, particles.
/// Everything is generated in code via UIGraphicsImageRenderer -> SKTexture. No image assets.
enum GlassRenderer {

    // MARK: - Texture helpers

    /// Cached soft round particle dot (white core fading to transparent).
    private static let softDotTexture: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.4).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0, 0.4, 1])!
            c.drawRadialGradient(gradient,
                                 startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                 endCenter: CGPoint(x: 16, y: 16), endRadius: 16,
                                 options: [])
        }
        return SKTexture(image: image)
    }()

    private static func radialTexture(size: CGSize,
                                      stops: [(CGFloat, UIColor)],
                                      radius: CGFloat? = nil) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = radius ?? max(size.width, size.height) * 0.5
            let colors = stops.map { $0.1.cgColor } as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: stops.map { $0.0 })!
            c.drawRadialGradient(gradient,
                                 startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: r,
                                 options: [])
        }
        return SKTexture(image: image)
    }

    private static func darker(_ color: UIColor, factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }

    // MARK: - Studio background

    /// Dark studio backdrop. Children are laid out around the node's center
    /// (caller positions the returned node, e.g. at the scene center).
    static func studioBackground(size: CGSize) -> SKNode {
        let root = SKNode()

        // 1. Full-screen vertical gradient: deep blue-black top -> warm dark brown bottom.
        let bgImage = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let top = UIColor(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x14 / 255.0, alpha: 1)
            let bottom = UIColor(red: 0x1A / 255.0, green: 0x0F / 255.0, blue: 0x08 / 255.0, alpha: 1)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [top.cgColor, bottom.cgColor] as CFArray,
                                      locations: [0, 1])!
            // Image space is y-down: y = 0 is the top of the screen.
            c.drawLinearGradient(gradient,
                                 start: CGPoint(x: size.width / 2, y: 0),
                                 end: CGPoint(x: size.width / 2, y: size.height),
                                 options: [])
        }
        let bg = SKSpriteNode(texture: SKTexture(image: bgImage), size: size)
        bg.zPosition = -10
        root.addChild(bg)

        // 2. Warm furnace glow near bottom-center.
        let glow = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: size.width * 1.1, height: size.height * 0.55),
            stops: [
                (0.0, UIColor(red: 1.0, green: 0.45, blue: 0.12, alpha: 0.55)),
                (0.5, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.18)),
                (1.0, UIColor(red: 0.9, green: 0.30, blue: 0.08, alpha: 0.0)),
            ]))
        glow.position = CGPoint(x: 0, y: -size.height * 0.32)
        glow.blendMode = .add
        glow.zPosition = -9
        root.addChild(glow)

        // 3. Vignette: darkened edges. Radius uses the full diagonal so corners are covered.
        let vignette = SKSpriteNode(texture: radialTexture(
            size: size,
            stops: [
                (0.0, UIColor(white: 0, alpha: 0.0)),
                (0.55, UIColor(white: 0, alpha: 0.0)),
                (1.0, UIColor(white: 0, alpha: 0.7)),
            ],
            radius: hypot(size.width, size.height) / 2))
        vignette.zPosition = 10
        root.addChild(vignette)

        // 4. Two ambient ember emitters low on screen.
        for x in [-size.width * 0.28, size.width * 0.28] {
            let emitter = emberEmitter()
            emitter.position = CGPoint(x: x, y: -size.height * 0.38)
            emitter.zPosition = -8
            root.addChild(emitter)
        }

        return root
    }

    // MARK: - Molten blob

    /// A gob of molten glass: white-hot core, additive glow layers, rising sparks,
    /// and a gentle heat-shimmer on the glow layers.
    static func moltenBlobNode(radius: CGFloat, color: SKColor) -> SKNode {
        let root = SKNode()
        let base: UIColor = color
        let d = radius * 2
        let box = CGSize(width: d, height: d)

        // Core sprite: white-hot center -> saturated color -> transparent edge.
        let coreTexture = radialTexture(size: box, stops: [
            (0.0, .white),
            (0.30, base),
            (0.70, base.withAlphaComponent(0.6)),
            (1.0, base.withAlphaComponent(0.0)),
        ])

        let core = SKSpriteNode(texture: coreTexture)
        core.zPosition = 2

        let mid = SKSpriteNode(texture: coreTexture)
        mid.setScale(1.8)
        mid.blendMode = .add
        mid.alpha = 0.5
        mid.zPosition = 1

        let halo = SKSpriteNode(texture: coreTexture)
        halo.setScale(2.8)
        halo.blendMode = .add
        halo.alpha = 0.22
        halo.zPosition = 0

        root.addChild(halo)
        root.addChild(mid)
        root.addChild(core)

        // Heat shimmer: glow layers breathe 1.0 <-> 1.05 on slightly different periods.
        mid.run(.repeatForever(.sequence([
            SKAction.scale(to: 1.8 * 1.05, duration: 0.45),
            SKAction.scale(to: 1.8, duration: 0.45),
        ])))
        halo.run(.repeatForever(.sequence([
            SKAction.scale(to: 2.8 * 1.05, duration: 0.7),
            SKAction.scale(to: 2.8, duration: 0.7),
        ])))
        // Alpha breathe 0.45 <-> 0.6 on the mid glow.
        mid.run(.repeatForever(.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.55),
            SKAction.fadeAlpha(to: 0.45, duration: 0.55),
        ])))

        let sparks = emberEmitter()
        root.addChild(sparks)

        return root
    }

    // MARK: - Finished piece

    /// Silhouette for each shape, drawn in a square box (image space, y-down).
    static func silhouettePath(for shape: PieceShape, in rect: CGRect) -> CGPath {
        let p = UIBezierPath()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let minY = rect.minY
        switch shape {
        case .orb:
            p.append(UIBezierPath(ovalIn: rect.insetBy(dx: w * 0.06, dy: h * 0.06)))
        case .teardrop:
            // Round bottom tapering to a point at the top.
            p.move(to: CGPoint(x: cx, y: minY + h * 0.04))
            p.addCurve(to: CGPoint(x: cx - w * 0.36, y: minY + h * 0.60),
                       controlPoint1: CGPoint(x: cx - w * 0.05, y: minY + h * 0.16),
                       controlPoint2: CGPoint(x: cx - w * 0.30, y: minY + h * 0.36))
            p.addCurve(to: CGPoint(x: cx, y: minY + h * 0.96),
                       controlPoint1: CGPoint(x: cx - w * 0.40, y: minY + h * 0.80),
                       controlPoint2: CGPoint(x: cx - w * 0.16, y: minY + h * 0.96))
            p.addCurve(to: CGPoint(x: cx + w * 0.36, y: minY + h * 0.60),
                       controlPoint1: CGPoint(x: cx + w * 0.16, y: minY + h * 0.96),
                       controlPoint2: CGPoint(x: cx + w * 0.40, y: minY + h * 0.80))
            p.addCurve(to: CGPoint(x: cx, y: minY + h * 0.04),
                       controlPoint1: CGPoint(x: cx + w * 0.30, y: minY + h * 0.36),
                       controlPoint2: CGPoint(x: cx + w * 0.05, y: minY + h * 0.16))
            p.close()
        case .vase:
            // Flared lip, narrow neck, round body (overlapping subpaths fill as one).
            p.append(UIBezierPath(roundedRect: CGRect(x: cx - w * 0.20, y: minY + h * 0.05,
                                                     width: w * 0.40, height: h * 0.07),
                                              cornerRadius: h * 0.035))
            p.append(UIBezierPath(rect: CGRect(x: cx - w * 0.11, y: minY + h * 0.11,
                                               width: w * 0.22, height: h * 0.32)))
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.37, y: minY + h * 0.38,
                                                 width: w * 0.74, height: h * 0.58)))
        case .twist:
            // Hourglass: two offset lobes.
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.34, y: minY + h * 0.06,
                                                 width: w * 0.56, height: h * 0.40)))
            p.append(UIBezierPath(ovalIn: CGRect(x: cx - w * 0.22, y: minY + h * 0.52,
                                                 width: w * 0.62, height: h * 0.44)))
        }
        return p.cgPath
    }

    /// A cooled glass piece: translucent gradient body, drop shadow, additive inner
    /// glow, caustic highlight streak, and a rim-light crescent on the upper-left edge.
    /// The node is centered (children span -size/2 ... size/2).
    static func finishedPieceNode(shape: PieceShape, color: PieceColor, size: CGFloat) -> SKNode {
        let root = SKNode()
        let base: UIColor = color.skColor
        let glow: UIColor = color.glowColor
        let box = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let silhouette = UIBezierPath(cgPath: silhouettePath(for: shape, in: box))

        // Soft drop shadow ellipse beneath the piece.
        let shadow = SKSpriteNode(texture: radialTexture(
            size: CGSize(width: size * 0.95, height: size * 0.30),
            stops: [
                (0.0, UIColor(white: 0, alpha: 0.5)),
                (0.6, UIColor(white: 0, alpha: 0.25)),
                (1.0, UIColor(white: 0, alpha: 0.0)),
            ]))
        shadow.position = CGPoint(x: 0, y: -size / 2 - size * 0.05)
        shadow.zPosition = -1
        root.addChild(shadow)

        // Body: vertical linear gradient (color @55% alpha top -> deeper shade bottom),
        // clipped to the silhouette, with the rim light baked in.
        let bodyImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            c.saveGState()
            c.addPath(silhouette.cgPath)
            c.clip()
            let topColor = base.withAlphaComponent(0.55)
            let bottomColor = darker(base, factor: 0.45).withAlphaComponent(0.85)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
                                      locations: [0, 1])!
            c.drawLinearGradient(gradient,
                                 start: CGPoint(x: size / 2, y: 0),
                                 end: CGPoint(x: size / 2, y: size),
                                 options: [])
            c.restoreGState()

            // Rim light: thin white stroke along the upper-left edge.
            c.saveGState()
            c.clip(to: CGRect(x: 0, y: 0, width: size * 0.55, height: size * 0.55))
            c.setStrokeColor(UIColor(white: 1, alpha: 0.5).cgColor)
            c.setLineWidth(max(2, size * 0.03))
            c.setLineCap(.round)
            c.addPath(silhouette.cgPath)
            c.strokePath()
            c.restoreGState()
        }
        let body = SKSpriteNode(texture: SKTexture(image: bodyImage))
        root.addChild(body)

        // Inner glow copy: silhouette filled with the hot glow color, additive, low alpha.
        let innerGlowImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(glow.withAlphaComponent(0.6).cgColor)
            c.addPath(silhouette.cgPath)
            c.fillPath()
        }
        let innerGlow = SKSpriteNode(texture: SKTexture(image: innerGlowImage))
        innerGlow.blendMode = .add
        innerGlow.alpha = 0.35
        root.addChild(innerGlow)

        // Caustic highlight: curved white streak, additive.
        let streakImage = UIGraphicsImageRenderer(size: box.size).image { ctx in
            let c = ctx.cgContext
            let streak = UIBezierPath()
            streak.move(to: CGPoint(x: size * 0.30, y: size * 0.26))
            streak.addCurve(to: CGPoint(x: size * 0.38, y: size * 0.72),
                            controlPoint1: CGPoint(x: size * 0.20, y: size * 0.42),
                            controlPoint2: CGPoint(x: size * 0.28, y: size * 0.58))
            c.setStrokeColor(UIColor(white: 1, alpha: 1).cgColor)
            c.setLineWidth(max(2, size * 0.05))
            c.setLineCap(.round)
            c.addPath(streak.cgPath)
            c.strokePath()
        }
        let caustic = SKSpriteNode(texture: SKTexture(image: streakImage))
        caustic.blendMode = .add
        caustic.alpha = 0.35
        root.addChild(caustic)

        return root
    }

    // MARK: - Particles

    /// Ambient rising sparks: small soft dots drifting upward.
    static func emberEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softDotTexture
        e.particleBirthRate = 10
        e.particleLifetime = 2.6
        e.particleLifetimeRange = 1.0
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.5
        e.particleSpeed = 65          // 40...90 via range below
        e.particleSpeedRange = 25
        e.xAcceleration = 8           // gentle sideways drift
        e.particleScale = 0.05
        e.particleScaleSpeed = -0.015
        e.particleColor = SKColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1.0)
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -0.3
        e.particleBlendMode = .add
        e.particlePositionRange = CGVector(dx: 50, dy: 8)
        return e
    }

    /// One-shot celebration burst. The caller positions the returned node;
    /// it removes itself after firing.
    static func burst(at point: CGPoint, color: SKColor) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.position = point
        e.particleTexture = softDotTexture
        e.numParticlesToEmit = 42
        e.particleBirthRate = 300     // high birth rate + fixed count = one explosion
        e.emissionAngleRange = .pi * 2
        e.particleSpeed = 130
        e.particleSpeedRange = 130
        e.particleLifetime = 0.9
        e.particleScale = 0.1
        e.particleScaleSpeed = -0.09
        e.particleColor = color
        e.particleColorBlendFactor = 1.0
        e.particleAlpha = 1.0
        e.particleAlphaSpeed = -1.0
        e.particleBlendMode = .add
        e.yAcceleration = -120        // gentle arc so sparks fall back down
        // Self-cleanup: all 42 particles are out well before 1.4s.
        e.run(.sequence([
            SKAction.wait(forDuration: 1.4),
            SKAction.removeFromParent(),
        ]))
        return e
    }

    // MARK: - Showcase scene

    /// Small showcase scene for a finished piece: dark backdrop, centered piece
    /// with a slow sway + bob, and embers near the bottom.
    static func previewScene(for piece: GlassPiece, size: CGSize) -> SKScene {
        let scene = SKScene(size: size)
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(white: 0.03, alpha: 1.0)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let bg = studioBackground(size: size)
        bg.position = center
        scene.addChild(bg)

        let pieceSize = 0.68 * min(size.width, size.height)
        let node = finishedPieceNode(shape: piece.shape, color: piece.color, size: pieceSize)
        node.position = CGPoint(x: center.x, y: size.height * 0.55)
        scene.addChild(node)

        // Slow showcase motion: sway +/-0.07 rad over 2.4s, bob +/-10pt over 3s.
        node.run(.repeatForever(.sequence([
            SKAction.rotate(toAngle: 0.07, duration: 1.2),
            SKAction.rotate(toAngle: -0.07, duration: 1.2),
        ])))
        node.run(.repeatForever(.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 1.5),
            SKAction.moveBy(x: 0, y: -10, duration: 1.5),
        ])))

        let embers = emberEmitter()
        embers.position = CGPoint(x: center.x, y: size.height * 0.12)
        scene.addChild(embers)

        return scene
    }
}
