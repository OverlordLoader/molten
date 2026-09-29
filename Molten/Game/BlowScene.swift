import SpriteKit
import UIKit

// MARK: - BlowScene
/// Press-and-hold to inflate the glass; release while the pressure needle
/// sits inside the glowing zone. Hold too long and the piece pops.
final class BlowScene: SKScene, MiniGameScene {
    var onFinish: ((Double) -> Void)?
    private var didFinish = false
    private func finish(_ q: Double) {
        guard !didFinish else { return }
        didFinish = true
        onFinish?(min(1, max(0, q)))
    }

    private var blob: SKNode!
    private var halo: SKShapeNode!
    private var needle: SKShapeNode!
    private var resultLabel: SKLabelNode!

    private var blobCenter = CGPoint.zero
    private var gaugeBottom: CGFloat = 0
    private var gaugeH: CGFloat = 0

    private var pressure: Double = 0        // 0...1
    private var holdTouch: UITouch?         // the finger currently inflating (multi-touch safe)
    private var enteredZone = false         // per-hold flag for the entry haptic
    private var resultShown = false
    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval?

    private let zoneLo = 0.60
    private let zoneHi = 0.80

    override func didMove(to view: SKView) {
        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bg)

        let cx = size.width / 2
        let cy = size.height / 2
        blobCenter = CGPoint(x: cx - 30, y: cy)

        // Blowpipe: dark rounded bar running from the left edge into the blob.
        let pipe = SKShapeNode(path: UIBezierPath(
            roundedRect: CGRect(x: 0, y: blobCenter.y - 12, width: blobCenter.x, height: 24),
            cornerRadius: 12
        ).cgPath)
        pipe.fillColor = SKColor(white: 0.16, alpha: 1)
        pipe.strokeColor = .clear
        addChild(pipe)

        // Additive halo behind the blob; its alpha ramps with pressure.
        halo = SKShapeNode(circleOfRadius: 72)
        halo.fillColor = SKColor.orange.withAlphaComponent(0.25)
        halo.strokeColor = .clear
        halo.blendMode = .add
        halo.position = blobCenter
        halo.alpha = 0.4
        addChild(halo)

        // The molten blob itself.
        blob = GlassRenderer.moltenBlobNode(radius: 46, color: .orange)
        blob.position = blobCenter
        addChild(blob)

        // Pressure gauge (right side): dark track + glowing target band + needle.
        let gaugeX = size.width * 0.86
        let gaugeW: CGFloat = 34
        gaugeH = size.height * 0.46
        gaugeBottom = cy - gaugeH / 2

        let gaugeTrack = SKShapeNode(path: UIBezierPath(
            roundedRect: CGRect(x: gaugeX - gaugeW / 2, y: gaugeBottom, width: gaugeW, height: gaugeH),
            cornerRadius: gaugeW / 2
        ).cgPath)
        gaugeTrack.fillColor = SKColor(white: 0.12, alpha: 1)
        gaugeTrack.strokeColor = SKColor.white.withAlphaComponent(0.2)
        gaugeTrack.lineWidth = 2
        addChild(gaugeTrack)

        // Target zone band: 0.60..0.80 of the gauge, glowing and breathing.
        let zoneH = gaugeH * CGFloat(zoneHi - zoneLo)
        let zonePath = UIBezierPath(
            roundedRect: CGRect(x: gaugeX - gaugeW / 2 - 5,
                                y: gaugeBottom + gaugeH * CGFloat(zoneLo),
                                width: gaugeW + 10, height: zoneH),
            cornerRadius: 10
        ).cgPath
        let zone = SKShapeNode(path: zonePath)
        zone.fillColor = SKColor.orange.withAlphaComponent(0.35)
        zone.strokeColor = .clear
        let zoneGlow = SKShapeNode(path: zonePath)
        zoneGlow.fillColor = SKColor.orange.withAlphaComponent(0.25)
        zoneGlow.strokeColor = .clear
        zoneGlow.blendMode = .add
        zoneGlow.glowWidth = 14
        zone.addChild(zoneGlow)
        zone.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.6),
            .fadeAlpha(to: 0.30, duration: 0.6),
        ])))
        addChild(zone)

        // Needle: white bar with an additive halo; turns orange inside the zone.
        let needlePath = UIBezierPath(
            roundedRect: CGRect(x: -28, y: -4.5, width: 56, height: 9),
            cornerRadius: 4.5
        ).cgPath
        needle = SKShapeNode(path: needlePath)
        needle.fillColor = .white
        needle.strokeColor = .clear
        let needleGlow = SKShapeNode(path: needlePath)
        needleGlow.fillColor = SKColor.white.withAlphaComponent(0.35)
        needleGlow.strokeColor = .clear
        needleGlow.blendMode = .add
        needleGlow.glowWidth = 8
        needle.addChild(needleGlow)
        needle.position = CGPoint(x: gaugeX, y: gaugeBottom)
        addChild(needle)

        // Labels.
        let instruction = SKLabelNode(fontNamed: "AvenirNext-Bold")
        instruction.text = "Press & HOLD — release inside the glow"
        instruction.fontSize = 20
        instruction.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 1)
        instruction.position = CGPoint(x: cx, y: size.height - 90)
        addChild(instruction)

        resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        resultLabel.fontSize = 30
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: cx, y: cy + 150)
        resultLabel.alpha = 0
        addChild(resultLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !resultShown, holdTouch == nil, let touch = touches.first else { return }
        holdTouch = touch
        enteredZone = false   // fresh haptic budget for this hold
        Haptics.selection()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let held = holdTouch, touches.contains(held), !resultShown else { return }
        release()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let held = holdTouch, touches.contains(held), !resultShown else { return }
        release()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard !resultShown, let last = lastUpdate else { return }
        let dt = min(0.05, currentTime - last)   // clamp hitches
        elapsed += dt

        guard holdTouch != nil else { return }
        pressure += dt * 0.5   // ~2s of holding to reach full pressure: tense but fair
        if pressure >= 1.0 {
            pop()
            return
        }
        // One light haptic the moment the needle enters the zone on this hold.
        if !enteredZone, pressure >= zoneLo, pressure <= zoneHi {
            enteredZone = true
            Haptics.light()
        }

        // Needle shows pressure + a fast wobble so holding feels alive and risky.
        let displayed = pressure + 0.025 * sin(elapsed * 9)
        needle.position.y = gaugeBottom + CGFloat(min(1, max(0, displayed))) * gaugeH
        needle.fillColor = (pressure >= zoneLo && pressure <= zoneHi) ? .orange : .white

        // The blob inflates with pressure and its halo brightens.
        blob.setScale(1 + CGFloat(pressure) * 1.1)
        halo.alpha = 0.4 + CGFloat(pressure) * 0.6
    }

    // MARK: - Outcomes

    private func release() {
        holdTouch = nil
        resultShown = true
        let p = pressure

        if p >= zoneLo && p <= zoneHi {
            // Dead-center (0.70) = 1.0, zone edges = 0.75.
            let q = 1.0 - 0.5 * (abs(p - 0.70) / 0.10)
            Haptics.success()
            showResultLabel("Beautiful!")
            // Satisfying "set": the glass firms up with a quick pop, relative to
            // the inflated size (an absolute 1.12->1.0 would collapse the grown blob).
            let s0 = blob.xScale
            blob.run(.sequence([
                .scale(to: s0 * 1.12, duration: 0.12),
                .scale(to: s0, duration: 0.18),
            ]))
            addBurst(at: blobCenter, color: .orange)
            endWith(q)
        } else if p > zoneHi {
            Haptics.medium()
            showResultLabel("Over-blown")
            endWith(max(0.2, 0.6 - abs(p - 0.70) * 1.2))
        } else {
            Haptics.medium()
            showResultLabel("Under-blown")
            endWith(max(0.2, 0.6 - abs(p - 0.70) * 1.2))
        }
    }

    private func pop() {
        resultShown = true
        holdTouch = nil
        Haptics.error()
        showResultLabel("It burst!")
        // Big red-orange pop: supersize the burst, then shrink the blob away.
        let burst = GlassRenderer.burst(at: blobCenter, color: SKColor(red: 1, green: 0.25, blue: 0.1, alpha: 1))
        burst.particleScale *= 1.8
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
        blob.run(.sequence([.scale(to: 0.01, duration: 0.18), .removeFromParent()]))
        halo.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
        endWith(0.15)
    }

    private func showResultLabel(_ text: String) {
        resultLabel.text = text
        resultLabel.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 0.8),
            .fadeOut(withDuration: 0.15),
        ]))
    }

    private func endWith(_ quality: Double) {
        halo.run(.fadeAlpha(to: 0.35, duration: 0.4))
        run(.sequence([.wait(forDuration: 1.1), .run { [weak self] in self?.finish(quality) }]))
    }

    private func addBurst(at point: CGPoint, color: SKColor) {
        let burst = GlassRenderer.burst(at: point, color: color)
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
    }
}
