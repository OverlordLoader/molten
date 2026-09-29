import SpriteKit
import UIKit

/// Demo / attract scene: studio backdrop, MOLTEN title, and four finished pieces
/// on pedestals. Tap a piece for a pulse + celebration burst. No buttons here —
/// navigation is handled by the SwiftUI overlay.
final class DemoScene: SKScene {

    private let world = SKNode()

    private let lineup: [(shape: PieceShape, color: PieceColor)] = [
        (.vase, .ember),
        (.orb, .ocean),
        (.teardrop, .violet),
        (.twist, .forest),
    ]

    private var pieceNodes: [SKNode] = []
    private var centerTitle: SKLabelNode?

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.03, alpha: 1.0)
        addChild(world)

        let w = size.width, h = size.height

        // Studio backdrop (laid out around its own center).
        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: w / 2, y: h / 2)
        world.addChild(bg)

        // Slow ambient camera drift: the whole world breathes +/-12pt over 9s.
        // Feel: 4.5s per leg feels calm, not seasick.
        world.run(.repeatForever(.sequence([
            SKAction.moveBy(x: 12, y: 0, duration: 4.5),
            SKAction.moveBy(x: -12, y: 0, duration: 4.5),
        ])))

        // Title block, upper third.
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "MOLTEN"
        title.fontSize = 44
        title.fontColor = SKColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        title.position = CGPoint(x: w / 2, y: h * 0.78)
        world.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitle.text = "glassblowing studio"
        subtitle.fontSize = 16
        subtitle.fontColor = .white
        subtitle.alpha = 0.6
        subtitle.position = CGPoint(x: w / 2, y: h * 0.78 - 34)
        world.addChild(subtitle)

        // Four pedestals across the lower two-thirds.
        let pieceSize = min(w, h) * 0.20
        let baseY = h * 0.34
        let glowTexture = Self.makeGlowTexture()

        for (i, entry) in lineup.enumerated() {
            let x = w * (CGFloat(i) + 0.5) / CGFloat(lineup.count)

            // Pedestal: dark rounded rect with a thin top highlight line.
            let pedW = pieceSize * 1.15
            let pedestal = SKShapeNode(
                rect: CGRect(x: -pedW / 2, y: -5, width: pedW, height: 10),
                cornerRadius: 5)
            pedestal.fillColor = SKColor(red: 0x14 / 255.0, green: 0x14 / 255.0,
                                         blue: 0x1C / 255.0, alpha: 1.0)
            pedestal.strokeColor = .clear
            pedestal.position = CGPoint(x: x, y: baseY - pieceSize / 2 - 14)
            world.addChild(pedestal)

            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: -pedW / 2 + 6, y: 0))
            linePath.addLine(to: CGPoint(x: pedW / 2 - 6, y: 0))
            let highlight = SKShapeNode(path: linePath)
            highlight.strokeColor = SKColor(white: 1, alpha: 0.18)
            highlight.lineWidth = 1.5
            highlight.position = CGPoint(x: x, y: pedestal.position.y + 5)
            world.addChild(highlight)

            // The piece itself.
            let piece = GlassRenderer.finishedPieceNode(shape: entry.shape,
                                                        color: entry.color,
                                                        size: pieceSize)
            piece.name = "piece:\(i)"
            piece.position = CGPoint(x: x, y: baseY)
            world.addChild(piece)
            pieceNodes.append(piece)

            // Staggered idle motion so the four pieces don't move in lockstep.
            // Feel: ~0.45s phase offset; bob +/-8pt, sway +/-0.05 rad — gentle.
            let phase = Double(i) * 0.45
            piece.run(.sequence([
                SKAction.wait(forDuration: phase),
                SKAction.repeatForever(.sequence([
                    SKAction.moveBy(x: 0, y: 8, duration: 1.6),
                    SKAction.moveBy(x: 0, y: -8, duration: 1.6),
                ])),
            ]))
            piece.run(.sequence([
                SKAction.wait(forDuration: phase * 0.7),
                SKAction.repeatForever(.sequence([
                    SKAction.rotate(toAngle: 0.05, duration: 1.8),
                    SKAction.rotate(toAngle: -0.05, duration: 1.8),
                ])),
            ]))

            // Soft additive halo behind the piece, pulsing.
            // Feel: one sprite per piece, alpha 0.18 <-> 0.30 — cheap and calm.
            let halo = SKSpriteNode(texture: glowTexture,
                                    color: entry.color.glowColor,
                                    size: CGSize(width: pieceSize * 1.6, height: pieceSize * 1.6))
            halo.colorBlendFactor = 1.0
            halo.blendMode = .add
            halo.alpha = 0.18
            halo.zPosition = -1
            piece.addChild(halo)
            halo.run(.repeatForever(.sequence([
                SKAction.fadeAlpha(to: 0.30, duration: 1.4),
                SKAction.fadeAlpha(to: 0.18, duration: 1.4),
            ])))

            // Name label under the pedestal.
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = "\(entry.color.displayName) \(entry.shape.displayName)"
            label.fontSize = 13
            label.fontColor = .white
            label.alpha = 0.75
            label.position = CGPoint(x: x, y: pedestal.position.y - 28)
            world.addChild(label)
        }
    }

    /// Soft radial glow texture, tinted per piece via the sprite's color.
    private static func makeGlowTexture() -> SKTexture {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [
                UIColor(white: 1, alpha: 1).cgColor,
                UIColor(white: 1, alpha: 0.35).cgColor,
                UIColor(white: 1, alpha: 0).cgColor,
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors,
                                      locations: [0, 0.45, 1])!
            c.drawRadialGradient(gradient,
                                 startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                 endCenter: CGPoint(x: 32, y: 32), endRadius: 32,
                                 options: [])
        }
        return SKTexture(image: image)
    }

    // MARK: - Interaction

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: world)

        // Walk up from the hit node to find a "piece:<index>" ancestor.
        var tappedIndex: Int?
        tapSearch: for node in world.nodes(at: location) {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name, name.hasPrefix("piece:"),
                   let index = Int(name.dropFirst("piece:".count)),
                   lineup.indices.contains(index) {
                    tappedIndex = index
                    break tapSearch
                }
                current = n.parent
            }
        }
        guard let index = tappedIndex else { return }
        let entry = lineup[index]
        let piece = pieceNodes[index]

        // Springy pulse: quick out, slower settle.
        // Feel: 0.12s out / 0.35s back reads snappy without overshoot.
        piece.run(.sequence([
            SKAction.scale(to: 1.18, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.35),
        ]))

        // Celebration burst at the piece's position (world coordinates).
        world.addChild(GlassRenderer.burst(at: piece.position, color: entry.color.glowColor))

        Haptics.medium()

        // Big center title, briefly: fade in 0.25s, hold 0.8s, fade out 0.4s.
        centerTitle?.removeFromParent()
        let big = SKLabelNode(fontNamed: "AvenirNext-Bold")
        big.text = "\(entry.color.displayName) \(entry.shape.displayName)"
        big.fontSize = 34
        big.fontColor = SKColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        big.alpha = 0
        big.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        big.zPosition = 50
        world.addChild(big)
        centerTitle = big
        big.run(.sequence([
            SKAction.fadeIn(withDuration: 0.25),
            SKAction.wait(forDuration: 0.8),
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent(),
        ]))
    }
}
