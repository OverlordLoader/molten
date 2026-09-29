import SpriteKit
import UIKit

// MARK: - CarveScene
/// Trace the glowing pattern with a finger. Samples carve as you pass near
/// them; the score blends accuracy (how close you traced) with coverage.
final class CarveScene: SKScene, MiniGameScene {
    var onFinish: ((Double) -> Void)?
    private var didFinish = false
    private func finish(_ q: Double) {
        guard !didFinish else { return }
        didFinish = true
        onFinish?(min(1, max(0, q)))
    }

    /// Pattern select: 0 = sine wave, 1 = spiral, 2 = zigzag. Host sets this before didMove.
    var patternIndex: Int = 0

    private var samples: [CGPoint] = []
    private var carved: [Bool] = []
    private var carvedCount = 0
    private var distSum: CGFloat = 0
    private var ending = false                 // result decided; ignore further touches
    private var activeTouches = 0              // so one lifted finger doesn't end a multi-touch carve
    private var lastTick: TimeInterval = 0     // haptic throttle timestamp
    private var progressLabel: SKLabelNode!
    private var resultLabel: SKLabelNode!
    private var dotTexture: SKTexture!
    private var patternCenter = CGPoint.zero

    private let sampleCount = 120
    private let carveRadius: CGFloat = 30

    override func didMove(to view: SKView) {
        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bg)

        patternCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        samples = makePattern(patternIndex, centeredAt: patternCenter)
        carved = Array(repeating: false, count: samples.count)
        dotTexture = makeDotTexture()

        // Guide: white polyline + a wider additive glow copy underneath.
        let path = UIBezierPath()
        path.move(to: samples[0])
        for s in samples.dropFirst() { path.addLine(to: s) }
        let cgPath = path.cgPath
        let glow = SKShapeNode(path: cgPath)
        glow.strokeColor = SKColor.orange.withAlphaComponent(0.12)
        glow.lineWidth = 22
        glow.blendMode = .add
        glow.zPosition = 1
        addChild(glow)
        let guide = SKShapeNode(path: cgPath)
        guide.strokeColor = SKColor.white.withAlphaComponent(0.22)
        guide.lineWidth = 12
        guide.zPosition = 2
        addChild(guide)

        let instruction = SKLabelNode(fontNamed: "AvenirNext-Medium")
        instruction.text = "Trace the glowing line"
        instruction.fontSize = 18
        instruction.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 0.9)
        instruction.position = CGPoint(x: patternCenter.x, y: patternCenter.y + 195)
        addChild(instruction)

        progressLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        progressLabel.text = "0%"
        progressLabel.fontSize = 24
        progressLabel.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 1)
        progressLabel.position = CGPoint(x: patternCenter.x, y: patternCenter.y - 200)
        addChild(progressLabel)

        resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        resultLabel.fontSize = 30
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: patternCenter.x, y: patternCenter.y + 160)
        resultLabel.alpha = 0
        addChild(resultLabel)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches += touches.count
        handleTouches(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches = max(0, activeTouches - touches.count)
        guard activeTouches == 0, !ending, !didFinish, carvedCount < samples.count else { return }
        // Last finger lifted before the pattern was complete: keep the partial score.
        ending = true
        Haptics.medium()
        showResultLabel("Lifted early")
        let q = computeQuality()
        run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.finish(q) }]))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func handleTouches(_ touches: Set<UITouch>) {
        guard !ending, !didFinish else { return }
        for touch in touches {
            carve(near: touch.location(in: self))
        }
        if carvedCount == samples.count, !ending {
            completeCarve()
        }
    }

    /// Carves every uncarved sample within `carveRadius` of the touch point.
    /// Nearest-first in spirit, but fills gaps when the finger moves fast so
    /// quick drags don't leave holes along the line.
    private func carve(near point: CGPoint) {
        var carvedAny = false
        for i in samples.indices where !carved[i] {
            let dx = samples[i].x - point.x
            let dy = samples[i].y - point.y
            let d = (dx * dx + dy * dy).squareRoot()
            guard d <= carveRadius else { continue }
            carved[i] = true
            carvedCount += 1
            distSum += d
            addCarveDot(at: samples[i])
            sparkle(at: samples[i])
            carvedAny = true
        }
        guard carvedAny else { return }
        // Throttled tick so a fast drag feels like one continuous carve, not a buzzsaw.
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTick > 0.05 {
            lastTick = now
            Haptics.light()
        }
        progressLabel.text = "\(Int(Double(carvedCount) / Double(samples.count) * 100))%"
    }

    /// A carved sample becomes a small additive glowing dot (<=120 sprites total).
    private func addCarveDot(at point: CGPoint) {
        let dot = SKShapeNode(circleOfRadius: 5)
        dot.fillColor = SKColor.orange
        dot.strokeColor = .clear
        dot.blendMode = .add
        dot.glowWidth = 6
        dot.zPosition = 3
        dot.position = point
        addChild(dot)
    }

    /// Tiny one-shot sparkle (6 particles) — GlassRenderer.burst would be
    /// overkill at 42 particles per carved sample.
    private func sparkle(at point: CGPoint) {
        let e = SKEmitterNode()
        e.numParticlesToEmit = 6
        e.particleBirthRate = 120
        e.particleLifetime = 0.35
        e.particleSpeed = 90
        e.particleSpeedRange = 50
        e.emissionAngleRange = .pi * 2
        e.particleScale = 0.5
        e.particleAlphaSpeed = -2.5
        e.particleColor = .white
        e.particleColorBlendFactor = 1
        e.particleTexture = dotTexture
        e.particleBlendMode = .add
        e.position = point
        e.zPosition = 4
        addChild(e)
        e.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
    }

    private func completeCarve() {
        ending = true
        Haptics.success()
        showResultLabel("Carved!")
        let burst = GlassRenderer.burst(at: patternCenter, color: .orange)
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
        let q = computeQuality()
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in self?.finish(q) }]))
    }

    private func showResultLabel(_ text: String) {
        resultLabel.text = text
        resultLabel.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.15),
        ]))
    }

    private func computeQuality() -> Double {
        let coverage = Double(carvedCount) / Double(samples.count)
        let avgDist: Double = carvedCount > 0 ? Double(distSum) / Double(carvedCount) : 60
        let accuracy = 1 - min(1, max(0, avgDist / 60))
        return max(0.15, 0.45 * accuracy + 0.55 * coverage)
    }

    // MARK: - Patterns (~120 samples each in a 300x300 area)

    private func makePattern(_ index: Int, centeredAt center: CGPoint) -> [CGPoint] {
        let n = sampleCount
        var pts: [CGPoint] = []
        pts.reserveCapacity(n)
        switch index % 3 {
        case 0:
            // Sine wave: 2 full periods across the width.
            for i in 0..<n {
                let t = Double(i) / Double(n - 1)
                let x = -150 + 300 * t
                let y = 90 * sin(4 * Double.pi * t)
                pts.append(CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(y)))
            }
        case 1:
            // Spiral: 2.5 turns, radius 12 -> 140.
            for i in 0..<n {
                let t = Double(i) / Double(n - 1)
                let r = 12 + 128 * t
                let a = 2.5 * 2 * Double.pi * t
                pts.append(CGPoint(x: center.x + CGFloat(r * cos(a)),
                                  y: center.y + CGFloat(r * sin(a))))
            }
        default:
            // Zigzag: 5 sharp peaks across the width.
            for i in 0..<n {
                let t = Double(i) / Double(n - 1)
                let x = -150 + 300 * t
                let frac = (5 * t).truncatingRemainder(dividingBy: 1)
                let tri = 1 - abs(2 * frac - 1) * 2   // [-1, 1], 5 peaks
                pts.append(CGPoint(x: center.x + CGFloat(x), y: center.y + CGFloat(120 * tri)))
            }
        }
        return pts
    }

    /// Soft radial dot used as the sparkle particle texture.
    private func makeDotTexture() -> SKTexture {
        let s: CGFloat = 24
        let image = UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            let cg = ctx.cgContext
            let colors = [SKColor.white.cgColor, SKColor.white.withAlphaComponent(0).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray,
                                      locations: [0, 1])!
            cg.drawRadialGradient(gradient,
                                  startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                                  endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2,
                                  options: [])
        }
        return SKTexture(image: image)
    }
}
