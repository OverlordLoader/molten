import SpriteKit
import UIKit

// MARK: - MiniGameScene
/// Shared contract for Molten's four mini-game scenes. Declared once here;
/// BlowScene, SpinScene and CarveScene (in their own files) conform to it.
/// `onFinish` is called exactly once with the final quality score (0...1).
protocol MiniGameScene: AnyObject {
    var onFinish: ((Double) -> Void)? { get set }
}

// MARK: - GatherScene
/// Timing tap game: a glowing needle oscillates on a vertical heat meter.
/// Tap when the needle is inside the glowing sweet-spot band.
final class GatherScene: SKScene, MiniGameScene {
    var onFinish: ((Double) -> Void)?
    private var didFinish = false
    private func finish(_ q: Double) {
        guard !didFinish else { return }
        didFinish = true
        onFinish?(min(1, max(0, q)))
    }

    // MARK: - Heat meter state
    private var marker: SKShapeNode!
    private var resultLabel: SKLabelNode!
    private var centerY: CGFloat = 0
    private var trackH: CGFloat = 0
    private var amplitude: CGFloat = 0
    private var phase: CGFloat = 0
    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval?
    private var windowCenterY: CGFloat = 0
    private var windowHalfHeight: CGFloat = 0
    private var resolved = false   // tap already taken; the scene is now playing its outro

    override func didMove(to view: SKView) {
        // Studio backdrop (origin-at-center node).
        let bg = GlassRenderer.studioBackground(size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(bg)

        centerY = size.height / 2
        let trackW: CGFloat = 46
        trackH = size.height * 0.52

        // Track: rounded rect filled with a vertical heat gradient
        // (deep blue at the bottom -> orange -> near-white at the top).
        let track = SKShapeNode(path: UIBezierPath(
            roundedRect: CGRect(x: -trackW / 2, y: -trackH / 2, width: trackW, height: trackH),
            cornerRadius: trackW / 2
        ).cgPath)
        track.fillColor = .white
        track.fillTexture = makeHeatGradientTexture()
        track.strokeColor = SKColor.white.withAlphaComponent(0.25)
        track.lineWidth = 2
        track.position = CGPoint(x: size.width / 2, y: centerY)
        addChild(track)

        // Sweet-spot band: 64%..78% of track height, glowing + pulsing.
        windowCenterY = centerY - trackH / 2 + trackH * 0.71
        windowHalfHeight = trackH * 0.07
        let bandH = windowHalfHeight * 2
        let bandPath = UIBezierPath(
            roundedRect: CGRect(x: -(trackW / 2 + 5), y: -bandH / 2, width: trackW + 10, height: bandH),
            cornerRadius: 10
        ).cgPath
        let band = SKShapeNode(path: bandPath)
        band.fillColor = SKColor.orange.withAlphaComponent(0.35)
        band.strokeColor = .clear
        band.position = CGPoint(x: size.width / 2, y: windowCenterY)
        // .add glow copy rides along as a child so it pulses in sync with the band.
        let bandGlow = SKShapeNode(path: bandPath)
        bandGlow.fillColor = SKColor.orange.withAlphaComponent(0.25)
        bandGlow.strokeColor = .clear
        bandGlow.blendMode = .add
        bandGlow.glowWidth = 14
        band.addChild(bandGlow)
        // Breathe the band alpha 0.30 <-> 0.55 forever (1.2s cycle feels alive, not frantic).
        band.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.6),
            .fadeAlpha(to: 0.30, duration: 0.6),
        ])))
        addChild(band)

        // Marker: horizontal glowing needle (white core + additive halo).
        let needlePath = UIBezierPath(
            roundedRect: CGRect(x: -35, y: -5, width: 70, height: 10),
            cornerRadius: 5
        ).cgPath
        marker = SKShapeNode(path: needlePath)
        marker.fillColor = .white
        marker.strokeColor = .clear
        let needleGlow = SKShapeNode(path: needlePath)
        needleGlow.fillColor = SKColor.white.withAlphaComponent(0.35)
        needleGlow.strokeColor = .clear
        needleGlow.blendMode = .add
        needleGlow.glowWidth = 10
        needleGlow.setScale(1.3)
        marker.addChild(needleGlow)
        marker.position = CGPoint(x: size.width / 2, y: centerY)
        addChild(marker)
        amplitude = size.height * 0.40

        // Embers drifting up along the track, sourced at the furnace (track bottom).
        let embers = GlassRenderer.emberEmitter()
        embers.position = CGPoint(x: size.width / 2, y: centerY - trackH / 2)
        addChild(embers)

        // Instruction + result labels.
        let instruction = SKLabelNode(fontNamed: "AvenirNext-Bold")
        instruction.text = "Tap when the needle is in the glow"
        instruction.fontSize = 20
        instruction.fontColor = SKColor(red: 1, green: 0.96, blue: 0.90, alpha: 1)
        instruction.position = CGPoint(x: size.width / 2, y: size.height - 90)
        addChild(instruction)

        resultLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        resultLabel.fontSize = 30
        resultLabel.fontColor = .white
        resultLabel.position = CGPoint(x: size.width / 2, y: centerY + trackH / 2 + 56)
        resultLabel.alpha = 0
        addChild(resultLabel)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdate = currentTime }
        guard !resolved, let last = lastUpdate else { return }
        // Clamp dt so a backgrounded tab or frame hitch can't teleport the needle.
        let dt = min(0.05, currentTime - last)
        elapsed += dt
        // Needle speeds up from 2.4 -> 4.6 rad/s over the first 8 seconds:
        // easy start, spicy finish.
        let speed = 2.4 + (4.6 - 2.4) * min(1.0, elapsed / 8.0)
        phase += CGFloat(speed * dt)
        marker.position.y = centerY + amplitude * CGFloat(sin(Double(phase)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !resolved, !didFinish else { return }
        resolved = true   // one tap per round; the scene now plays its outro

        let d = Double(abs(marker.position.y - windowCenterY) / windowHalfHeight)
        if d <= 1.0 {
            // Dead-center = 1.0, edge of the band = 0.55.
            let q = max(0.55, 1.0 - 0.45 * d)
            let text = q > 0.92 ? "Perfect!" : (q > 0.75 ? "Great!" : "Good")
            showResult(text: text, quality: q, hit: true)
        } else {
            let tooHot = marker.position.y > windowCenterY
            showResult(text: tooHot ? "Too hot!" : "Too cold…", quality: 0.2, hit: false)
        }
    }

    private func showResult(text: String, quality: Double, hit: Bool) {
        resultLabel.text = text
        resultLabel.run(.sequence([
            .fadeIn(withDuration: 0.15),
            .wait(forDuration: 0.7),
            .fadeOut(withDuration: 0.15),
        ]))

        let furnace = CGPoint(x: size.width / 2, y: centerY - trackH / 2)
        if hit {
            Haptics.success()
            // A fresh blob pops out of the furnace and floats up, trailing a burst.
            let blob = GlassRenderer.moltenBlobNode(radius: 26, color: .orange)
            blob.position = furnace
            blob.setScale(0.2)
            addChild(blob)
            blob.run(.sequence([
                .scale(to: 1.0, duration: 0.25),
                .moveBy(x: 0, y: 70, duration: 0.45),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
            addBurst(at: furnace, color: .orange)
        } else {
            Haptics.error()
            addBurst(at: furnace, color: .gray)   // dull gray puff for a miss
        }

        // Let the player savor the result for a beat, then report the score.
        run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in self?.finish(quality) }]))
    }

    /// Adds a burst and cleans it up after its particles die out.
    private func addBurst(at point: CGPoint, color: SKColor) {
        let burst = GlassRenderer.burst(at: point, color: color)
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
    }

    /// Vertical heat gradient: deep blue (bottom) -> orange -> near-white (top),
    /// drawn into an image and used as the track's fill texture.
    /// (If the gradient ever renders flipped on a device, swap the start/end points below.)
    private func makeHeatGradientTexture() -> SKTexture {
        let w = 46, h = 512
        let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cg = ctx.cgContext
            let colors = [
                SKColor(red: 0.10, green: 0.20, blue: 0.65, alpha: 1).cgColor,  // deep blue, furnace-cold
                SKColor.orange.cgColor,                                        // heating up
                SKColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1).cgColor,   // near-white, hottest
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.55, 1]
            )!
            // Image space has y=0 at the top, so draw from bottom (blue) to top (white).
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: 0, y: h),
                                  end: CGPoint(x: 0, y: 0),
                                  options: [])
        }
        return SKTexture(image: image)
    }
}
