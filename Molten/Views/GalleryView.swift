import SwiftUI
import SpriteKit

struct GalleryView: View {
    @EnvironmentObject private var store: GameStore
    @Binding var goToStudio: Bool

    @State private var selectedPiece: GlassPiece?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if store.pieces.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Gallery")
            .background(Color(white: 0.05).ignoresSafeArea())
            .sheet(item: $selectedPiece) { piece in
                PieceDetailView(piece: piece)
                    .environmentObject(store)
            }
        }
        .tint(.orange)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "flame")
                .font(.system(size: 56))
                .foregroundColor(.orange.opacity(0.7))
            Text("No pieces yet")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            Text("Fire up the furnace and blow your first piece of glass.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                Haptics.medium()
                goToStudio = true
            } label: {
                Text("Craft your first piece")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.pieces) { piece in
                    Button {
                        selectedPiece = piece
                        Haptics.selection()
                    } label: {
                        VStack(spacing: 8) {
                            SpriteView(scene: GlassRenderer.previewScene(
                                for: piece,
                                size: CGSize(width: 180, height: 180)
                            ))
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(piece.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(String(repeating: "★", count: piece.stars) + String(repeating: "☆", count: 3 - piece.stars))
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(16)
        }
    }
}

/// Detail sheet for a single piece: big preview, stats, working Delete + Close.
private struct PieceDetailView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let piece: GlassPiece

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SpriteView(scene: GlassRenderer.previewScene(
                        for: piece,
                        size: CGSize(width: 300, height: 300)
                    ))
                    .frame(width: 300, height: 300)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 8)

                    Text(piece.title)
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text(String(repeating: "★", count: piece.stars) + String(repeating: "☆", count: 3 - piece.stars))
                        .font(.title2)
                        .foregroundColor(.orange)

                    VStack(spacing: 10) {
                        statRow(label: "Gather quality", value: piece.gatherQuality)
                        statRow(label: "Shape quality", value: piece.shapeQuality)
                        statRow(label: "Overall", value: piece.overallQuality)
                    }
                    .padding(.horizontal, 20)

                    Text("Crafted \(piece.createdAt, style: .date) at \(piece.createdAt, style: .time)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.55))

                    Button(role: .destructive) {
                        store.deletePiece(piece)
                        Haptics.error()
                        dismiss()
                    } label: {
                        Text("Delete piece")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .navigationTitle("Piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        Haptics.selection()
                        dismiss()
                    }
                }
            }
        }
        .tint(.orange)
    }

    private func statRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text("\(Int((value * 100).rounded()))%")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
        }
    }
}
