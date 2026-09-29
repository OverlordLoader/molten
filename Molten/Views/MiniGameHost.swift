import SwiftUI
import SpriteKit

/// Generic host for one mini-game round. The scene is created once in `init`;
/// when the scene calls `onFinish`, we flash a result and then hand the
/// quality score back to the caller.
struct MiniGameHost: View {
    let title: String
    let hint: String
    let makeScene: () -> MiniGameScene
    let onQuit: () -> Void
    let onComplete: (Double) -> Void

    @State private var scene: MiniGameScene?
    @State private var resultFlash: String?
    @State private var hasFinished = false

    init(title: String,
         hint: String,
         makeScene: @escaping () -> MiniGameScene,
         onQuit: @escaping () -> Void,
         onComplete: @escaping (Double) -> Void) {
        self.title = title
        self.hint = hint
        self.makeScene = makeScene
        self.onQuit = onQuit
        self.onComplete = onComplete
        _scene = State(initialValue: makeScene())
    }

    var body: some View {
        ZStack {
            if let sk = scene as? SKScene {
                SpriteView(scene: sk)
                    .ignoresSafeArea()
            } else {
                Color(white: 0.05)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        Haptics.selection()
                        onQuit()
                    }) {
                        Text("Quit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding()

                Spacer()

                if let flash = resultFlash {
                    Text(flash)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .transition(.scale)
                }

                Text(hint)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            scene?.onFinish = { quality in
                DispatchQueue.main.async {
                    guard !hasFinished else { return }
                    hasFinished = true
                    let pct = Int((quality * 100).rounded())
                    withAnimation {
                        resultFlash = quality >= 0.6 ? "Nice! \(pct)%" : "\(pct)%"
                    }
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onComplete(quality)
                    }
                }
            }
        }
    }
}
