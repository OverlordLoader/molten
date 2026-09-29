import SwiftUI
import SpriteKit

struct StudioView: View {
    private enum Step { case pickShape, gather, pickTechnique, shape, result }
    private enum Technique: String, CaseIterable {
        case blow, spin, carve
        var title: String {
            switch self {
            case .blow: return "Blow"
            case .spin: return "Spin"
            case .carve: return "Carve"
            }
        }
        var description: String {
            switch self {
            case .blow: return "Press, hold & release in the zone"
            case .spin: return "Tap to keep the needle in the glow"
            case .carve: return "Trace the pattern"
            }
        }
        var systemImage: String {
            switch self {
            case .blow: return "wind"
            case .spin: return "rotate.3d"
            case .carve: return "pencil.and.scribble"
            }
        }
    }

    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var adsManager: AdsManager
    @State private var step: Step = .pickShape
    @State private var selectedShape: PieceShape = .vase
    @State private var selectedColor: PieceColor = .ember
    @State private var selectedTechnique: Technique = .blow
    @State private var hasPickedShape = false
    @State private var gatherQuality: Double = 0
    @State private var shapeQuality: Double = 0
    /// A locked premium color the player tapped — shows the unlock sheet.
    @State private var lockedColor: PieceColor?

    var body: some View {
        Group {
            switch step {
            case .pickShape: pickShapeView
            case .gather: gatherView
            case .pickTechnique: pickTechniqueView
            case .shape: shapeView
            case .result: resultView
            }
        }
        .background(Color(white: 0.05).ignoresSafeArea())
        .tint(.orange)
    }

    // MARK: - Step 1: Pick shape & color

    private var pickShapeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("New Piece")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Shape")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(PieceShape.allCases) { shape in
                            Button {
                                selectedShape = shape
                                hasPickedShape = true
                                Haptics.selection()
                            } label: {
                                Text(shape.displayName)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        selectedShape == shape && hasPickedShape
                                        ? Color.orange.opacity(0.25)
                                        : Color.white.opacity(0.08)
                                    )
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedShape == shape && hasPickedShape ? Color.orange : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Glass color")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(PieceColor.allCases) { color in
                            let available = storeManager.isColorAvailable(color)
                            Button {
                                if available {
                                    selectedColor = color
                                    Haptics.selection()
                                } else {
                                    lockedColor = color
                                    Haptics.light()
                                }
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 44, height: 44)
                                        .opacity(available ? 1 : 0.45)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.orange, lineWidth: selectedColor == color ? 3 : 0)
                                                .padding(-5)
                                        )
                                    if !available {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(5)
                                            .background(Color.black.opacity(0.65))
                                            .clipShape(Circle())
                                            .offset(x: 4, y: 4)
                                    }
                                }
                            }
                            .accessibilityLabel(available ? color.displayName : "\(color.displayName), locked")
                        }
                    }
                }

                Button {
                    Haptics.medium()
                    // Consume a single-use rewarded-ad unlock as the piece begins.
                    storeManager.consumeAdUnlock(for: selectedColor)
                    step = .gather
                } label: {
                    Text("Gather molten glass →")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(hasPickedShape ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasPickedShape ? Color.orange : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!hasPickedShape)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .sheet(item: $lockedColor) { color in
            UnlockColorSheet(color: color, onUnlocked: { selectedColor = color })
        }
    }

    // MARK: - Step 2: Gather mini-game

    private var gatherView: some View {
        MiniGameHost(
            title: "Gather",
            hint: "Tap when the needle is in the glow",
            makeScene: {
                let s = GatherScene(size: CGSize(width: 390, height: 844))
                s.scaleMode = .resizeFill
                return s
            },
            onQuit: { step = .pickShape },
            onComplete: { quality in
                gatherQuality = quality
                Haptics.success()
                step = .pickTechnique
            }
        )
    }

    // MARK: - Step 3: Pick shaping technique

    private var pickTechniqueView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Shape it")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)
                .padding(.top, 16)

            Text("Choose a shaping technique")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            ForEach(Technique.allCases, id: \.self) { technique in
                Button {
                    selectedTechnique = technique
                    Haptics.medium()
                    step = .shape
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: technique.systemImage)
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(technique.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(technique.description)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.65))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding()
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                Haptics.selection()
                step = .gather
            } label: {
                Text("← Back to gather")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Step 4: Shape mini-game

    private var shapeView: some View {
        MiniGameHost(
            title: selectedTechnique.title,
            hint: selectedTechnique.description,
            makeScene: { [selectedTechnique, selectedShape] in
                let size = CGSize(width: 390, height: 844)
                switch selectedTechnique {
                case .blow:
                    let s = BlowScene(size: size)
                    s.scaleMode = .resizeFill
                    return s
                case .spin:
                    let s = SpinScene(size: size)
                    s.scaleMode = .resizeFill
                    return s
                case .carve:
                    let s = CarveScene(size: size)
                    s.scaleMode = .resizeFill
                    let shapeIndex = PieceShape.allCases.firstIndex(of: selectedShape) ?? 0
                    s.patternIndex = shapeIndex % 3
                    return s
                }
            },
            onQuit: { step = .pickTechnique },
            onComplete: { quality in
                shapeQuality = quality
                Haptics.success()
                step = .result
            }
        )
    }

    // MARK: - Step 5: Result

    private var draftPiece: GlassPiece {
        GlassPiece(
            shape: selectedShape,
            color: selectedColor,
            gatherQuality: gatherQuality,
            shapeQuality: shapeQuality
        )
    }

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(draftPiece.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)

                SpriteView(scene: GlassRenderer.previewScene(
                    for: draftPiece,
                    size: CGSize(width: 300, height: 300)
                ))
                .frame(width: 300, height: 300)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(String(repeating: "★", count: draftPiece.stars) + String(repeating: "☆", count: 3 - draftPiece.stars))
                    .font(.title)
                    .foregroundColor(.orange)

                VStack(spacing: 10) {
                    qualityBar(label: "Gather", value: gatherQuality)
                    qualityBar(label: "Shape", value: shapeQuality)
                }
                .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button {
                        store.addPiece(draftPiece)
                        // Throttled interstitial: at most 1 per 3 pieces, never
                        // first session, never with Remove Ads. Safe here —
                        // the result screen is a natural break, not mid-game.
                        adsManager.pieceCompleted()
                        Haptics.success()
                        reset()
                    } label: {
                        Text("Add to Gallery")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        Haptics.selection()
                        reset()
                    } label: {
                        Text("Discard")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func qualityBar(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
            }
            ProgressView(value: value)
                .tint(.orange)
        }
    }

    private func reset() {
        hasPickedShape = false
        gatherQuality = 0
        shapeQuality = 0
        step = .pickShape
    }
}

// MARK: - Premium color unlock sheet

/// Offered when the player taps a locked premium color: watch a rewarded ad
/// to use it once, or buy its pack for permanent unlock. No dead buttons —
/// the ad option only appears when rewarded ads are actually available.
struct UnlockColorSheet: View {
    let color: PieceColor
    let onUnlocked: () -> Void

    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var adsManager: AdsManager
    @Environment(\.dismiss) private var dismiss
    @State private var adFailed = false

    private var pack: ColorPack? { color.pack }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 90, height: 90)
                    .overlay(Circle().stroke(Color.orange, lineWidth: 3).padding(-6))
                    .padding(.top, 24)

                Text("\(color.displayName) Glass")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("A premium color from the \(pack?.displayName ?? "color packs").")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    if canWatchAd {
                        Button {
                            Haptics.medium()
                            adsManager.showRewarded(for: .premiumColor(color)) { earned in
                                if earned {
                                    storeManager.grantAdColorUnlock(color)
                                    onUnlocked()
                                    dismiss()
                                } else {
                                    adFailed = true
                                }
                            }
                        } label: {
                            Label("Watch Ad to Use Once", systemImage: "play.tv")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(adsManager.isRewardedReady ? Color.orange : Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!adsManager.isRewardedReady)
                        if !adsManager.isRewardedReady {
                            Text("Ad is loading — try again in a moment.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        if adFailed {
                            Text("The ad wasn't available. Please try again.")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }

                    if let pack {
                        Button {
                            Haptics.medium()
                            Task { await storeManager.purchase(productID: pack.productID) }
                        } label: {
                            HStack {
                                Text("Buy \(pack.displayName)")
                                Spacer()
                                if storeManager.isPurchasing {
                                    ProgressView()
                                } else {
                                    Text(storeManager.priceString(for: pack.productID, fallback: pack.fallbackPrice))
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(storeManager.isPurchasing)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Color(white: 0.07).ignoresSafeArea())
            .navigationTitle("Premium Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: storeManager.isColorAvailable(color)) { _, available in
                if available {
                    onUnlocked()
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Rewarded ads only make sense when ads aren't removed entirely.
    private var canWatchAd: Bool { !adsManager.isRemoveAdsEnabled }
}
