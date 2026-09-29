import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    private static let storageKey = "molten.gallery.v1"

    @Published private(set) var pieces: [GlassPiece] = []

    init() {
        load()
    }

    func addPiece(_ piece: GlassPiece) {
        pieces.insert(piece, at: 0)
        save()
    }

    func deletePiece(_ piece: GlassPiece) {
        pieces.removeAll { $0.id == piece.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([GlassPiece].self, from: data)
            pieces = decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            pieces = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(pieces)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Persistence is best-effort; the in-memory gallery keeps working.
        }
    }
}
