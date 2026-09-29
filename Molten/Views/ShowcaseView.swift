import SwiftUI
import SpriteKit

struct ShowcaseView: View {
    @Binding var goToStudio: Bool

    var body: some View {
        ZStack {
            SpriteView(
                scene: {
                    let s = DemoScene(size: CGSize(width: 390, height: 844))
                    s.scaleMode = .resizeFill
                    return s
                }()
            )
            .ignoresSafeArea()

            VStack {
                VStack(spacing: 6) {
                    Text("MOLTEN")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .orange.opacity(0.6), radius: 18)
                    Text("Blow glass. Shape fire.")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 72)

                Spacer()

                Button {
                    Haptics.medium()
                    goToStudio = true
                } label: {
                    Text("Start crafting")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.5), radius: 12)
                }
                .padding(.bottom, 56)
            }
        }
    }
}
