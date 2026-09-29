import SpriteKit
import UIKit

// MARK: - SpinScene
/// Keep the spinning needle inside the glowing 75° zone at the top of the
/// dial by tapping to reverse its direction. 12-second round; forgiving
/// scoring (55% in-zone time earns a perfect score).
final class SpinScene: SKScene, MiniGameScene {
    var onFinish: ((Double) -> Void)?
    private var didFinish = false
    private func finish(_ q: Double) {
        guard !didFinish else { return }
        didFinish = true
        onFinish?(min(1, max(0, q)))
    }

    // NOTE: SpriteKit scenes are y-up, so the top of the dial is +π/2
    // (the design note's −π/2 assumed flipped UIKit coordinates).
    private let zoneCenter = CGFloat.pi / 2
    private let zoneHalf = CGFloat(37.5 * Double.pi / 180)   // 75° zone
    private let omega: CGFloat = 2.6                        // rad/s needle speed
    private let roundLength: TimeInterval = 12

    private var pieceCenter = CGPoint.zero
    private var needleNode: SKNode!
    private var trail: SKShapeNode!
    private var zoneGlow: SKShapeNode!
    private var hudLabel: SKLabelNode!
    private var resultLabel: SKLabelNode!

    private var theta: CGFloat = 0
    private var direction: CGFloat = 1
    private var timeLeft: TimeInterval = 12
    private var inZoneTime: TimeInterval = 0
    private var streak: TimeInterval = 0   // consecutive in-zone seconds, drives zone brightness
    private var lastUpdate: TimeInterval?
    private var ended = false

    override func didMove(to view: SKView) {
        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bg)

        let cx = size.width / 2
        let cy = size.height / 2
        pieceCenter = CGPoint(x: cx, y: cy - 10)

        // Punty pipe running in from the left, behind the piece.
        let pipe = SKShapeNode(path: UIBezierPath(
            roundedRect: CGRect(x: 0, y: pieceCenter.y - 11, width: pieceCenter.x - 40, height: 22),
            cornerRadius: 11
        ).cgPath)
        pipe.fillColor = SKColor(white: 0.16, alpha: 1)
        pipe.strokeColor = .clear
        addChild(pipe)

        // Glass piece silhouette: a simple vase, translucent teal.
        addChild(makeVase(at: pieceCenter))

        // Target zone: fixed 75° arc at the top of the dial (radius matches the needle tip).
        let zoneSpan = zoneHalf * 2
        let zonePath = UIBezierPath(
            arcCenter: pieceCenter, radius: 122,
            startAngle: zoneCenter - zoneSpan / 2,
            endAngle: zoneCenter + zoneSpan / 2,
            clockwise: false
        ).cgPath
        let zone = SKShapeNode(path: zonePath)
        zone.strokeColor = SKColor.orange.withAlphaComponent(0.3)
        zone.lineWidth = 26
        addChild(zone)
        zoneGlow = SKShapeNode(path: zonePath)
        zoneGlow.strokeColor = SKColor.orange.withAlphaComponent(0.5)
        zoneGlow.lineWidth = 26
        zoneGlow.blendMode = .add
        zoneGlow.glowWidth = 16
        zoneGlow.alpha = 0.3
        addChild(zoneGlow)

        // Trail: a 40° additive arc that lags behind the needle for motion feel.
        // Built symmetric around 0 and rotated each frame — cheaper than rebuilding the path.
        let trailSpan = CGFloat(40 * Double.pi / 180)
        trail = SKShapeNode(path: UIBezierPath(
            arcCenter: .zero, radius: 110,
            startAngle: -trailSpan / 2, endAngle: trailSpan / 2,
            clockwise: false
        ).cgPath)
        trail.strokeColor = SKColor.white.withAlphaComponent(0.25)
        trail.lineWidth = 10
        trail.blendMode = .add
        trail.position = pieceCenter
        addChild(trail)

        // Needle: thin glowing pointer (~110pt) rotating around the piece center.
        needleNode = SKNode()
        needleNode.position = pieceCenter
        let barPath = UIBezierPath(
            roundedRect: CGRect(x: 6, y: -4, width: 104, height: 8),
            cornerRadius: 4
        ).cgPath
        let bar = SKShapeNode(path: barPath)
        bar.fillColor = .white
        bar.strokeColor = .clear
        let barGlow = SKShapeNode(path: barPath)
        barGlow.fillColor = SKColor.white.withAlphaComponent(0.35)
        barGlow.strokeColor = .clear
        barGlow.blendMode = .add
        barGlow.glowWidth = 8
        bar.addChild(barGlow)
        needleNode.addChild(bar)
        let tip = SKShapeNode(circleOfRadius: 7)
        tip.fillColor = SKColor.orange
        tip.strokeColor = .clear
        tip.blendMode = .add
        tip.glowWidth = 10
        tip.position = CGPoint(x: 110, y: 0)
        needleNode.addChild(tip)
        addChild(needleNode)

        // HUD: seconds remaining.
        hudLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        hudLabel.fontSize = 24
        hudLabel.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 1)
        hudLabel.position = CGPoint(x: cx, y: size.height - 90)
        hudLabel.text = "12"
        addChild(hudLabel)

        let instruction = SKLabelNode(fontNamed: "AvenirNext-Medium")
        instruction.text = "Tap to flip the needle — keep it in the glow"
        instruction.fontSize = 17
        instruction.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 0.85)
        instruction.position = CGPoint(x: cx, y: size.height - 120)
        addChild(instruction)

        resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        resultLabel.fontSize = 28
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: cx, y: pieceCenter.y + 200)
        resultLabel.alpha = 0
        addChild(resultLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !ended else { return }
        direction *= -1   // tap anywhere to reverse
        Haptics.light()
        // Tiny spark at the needle tip so every tap gets visual feedback.
        let tip = CGPoint(x: pieceCenter.x + CGFloat(cos(Double(theta))) * 110,
                          y: pieceCenter.y + CGFloat(sin(Double(theta))) * 110)
        let spark = GlassRenderer.burst(at: tip, color: .orange)
        addChild(spark)
        spark.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard !ended, let last = lastUpdate else { return }
        let dt = min(0.05, currentTime - last)   // clamp hitches
        theta += direction * omega * CGFloat(dt)
        needleNode.zRotation = theta
        // Trail is centered 20° behind the needle tip.
        trail.zRotation = theta - CGFloat(20 * Double.pi / 180)

        let inZone = abs(angleDiff(theta, zoneCenter)) < zoneHalf
        if inZone {
            inZoneTime += dt
            streak += dt
        } else {
            streak = 0
        }
        // The zone glows brighter the longer you hold the streak (saturates ~3s).
        zoneGlow.alpha = 0.3 + CGFloat(min(1, streak / 3)) * 0.5

        timeLeft -= dt
        hudLabel.text = "\(max(0, Int(ceil(timeLeft))))"
        if timeLeft <= 0 {
            endRound()
        }
    }

    private func endRound() {
        ended = true
        // Forgiving: 55% of the round in-zone earns a perfect score.
        let quality = min(1, max(0.15, inZoneTime / (roundLength * 0.55)))
        let pct = Int(inZoneTime / roundLength * 100)
        resultLabel.text = "In the zone \(pct)%!"
        resultLabel.run(.fadeIn(withDuration: 0.2))
        Haptics.success()
        let burst = GlassRenderer.burst(at: pieceCenter, color: .orange)
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.finish(quality) }]))
    }

    /// Wraps the a→b angle distance into [-π, π].
    private func angleDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = a - b
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    /// Simple symmetrical vase silhouette, drawn around the origin.
    private func makeVase(at center: CGPoint) -> SKShapeNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: 0, y: -85))
        p.addCurve(to: CGPoint(x: -46, y: -38),
                   controlPoint1: CGPoint(x: -52, y: -85),
                   controlPoint2: CGPoint(x: -56, y: -58))
        p.addCurve(to: CGPoint(x: -30, y: 42),
                   controlPoint1: CGPoint(x: -36, y: -18),
                   controlPoint2: CGPoint(x: -42, y: 22))
        p.addCurve(to: CGPoint(x: -18, y: 85),
                   controlPoint1: CGPoint(x: -20, y: 62),
                   controlPoint2: CGPoint(x: -18, y: 72))
        p.addLine(to: CGPoint(x: 18, y: 85))
        p.addCurve(to: CGPoint(x: 30, y: 42),
                   controlPoint1: CGPoint(x: 18, y: 72),
                   controlPoint2: CGPoint(x: 20, y: 62))
        p.addCurve(to: CGPoint(x: 46, y: -38),
                   controlPoint1: CGPoint(x: 42, y: 22),
                   controlPoint2: CGPoint(x: 36, y: -18))
        p.addCurve(to: CGPoint(x: 0, y: -85),
                   controlPoint1: CGPoint(x: 56, y: -58),
                   controlPoint2: CGPoint(x: 52, y: -85))
        p.close()
        let vase = SKShapeNode(path: p.cgPath)
        vase.fillColor = SKColor(red: 0.3, green: 0.85, blue: 0.8, alpha: 0.45)
        vase.strokeColor = SKColor(red: 0.5, green: 0.95, blue: 0.9, alpha: 0.8)
        vase.lineWidth = 3
        vase.glowWidth = 8
        vase.position = center
        return vase
    }
}
