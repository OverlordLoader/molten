import SwiftUI
import SpriteKit

enum PieceShape: String, CaseIterable, Codable, Identifiable {
    case vase, orb, teardrop, twist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vase: return "Vase"
        case .orb: return "Orb"
        case .teardrop: return "Teardrop"
        case .twist: return "Twist"
        }
    }
}

enum PieceColor: String, CaseIterable, Codable, Identifiable {
    case ember, ocean, forest, violet, rose, frost

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ember: return "Ember"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .violet: return "Violet"
        case .rose: return "Rose"
        case .frost: return "Frost"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .ember: return Color(red: 1.0, green: 0.36, blue: 0.12)
        case .ocean: return Color(red: 0.10, green: 0.55, blue: 0.78)
        case .forest: return Color(red: 0.20, green: 0.62, blue: 0.28)
        case .violet: return Color(red: 0.55, green: 0.30, blue: 0.85)
        case .rose: return Color(red: 0.95, green: 0.35, blue: 0.55)
        case .frost: return Color(red: 0.65, green: 0.85, blue: 0.95)
        }
    }

    var skColor: SKColor {
        switch self {
        case .ember: return SKColor(red: 1.0, green: 0.36, blue: 0.12, alpha: 1.0)
        case .ocean: return SKColor(red: 0.10, green: 0.55, blue: 0.78, alpha: 1.0)
        case .forest: return SKColor(red: 0.20, green: 0.62, blue: 0.28, alpha: 1.0)
        case .violet: return SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1.0)
        case .rose: return SKColor(red: 0.95, green: 0.35, blue: 0.55, alpha: 1.0)
        case .frost: return SKColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 1.0)
        }
    }

    var glowColor: SKColor {
        switch self {
        case .ember: return SKColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0)
        case .ocean: return SKColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 1.0)
        case .forest: return SKColor(red: 0.45, green: 0.90, blue: 0.50, alpha: 1.0)
        case .violet: return SKColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 1.0)
        case .rose: return SKColor(red: 1.0, green: 0.60, blue: 0.75, alpha: 1.0)
        case .frost: return SKColor(red: 0.90, green: 0.97, blue: 1.0, alpha: 1.0)
        }
    }
}

struct GlassPiece: Identifiable, Codable {
    let id: UUID
    var shape: PieceShape
    var color: PieceColor
    var gatherQuality: Double
    var shapeQuality: Double
    var createdAt: Date

    init(shape: PieceShape, color: PieceColor, gatherQuality: Double, shapeQuality: Double) {
        self.id = UUID()
        self.shape = shape
        self.color = color
        self.gatherQuality = gatherQuality
        self.shapeQuality = shapeQuality
        self.createdAt = Date()
    }

    var overallQuality: Double {
        0.35 * gatherQuality + 0.65 * shapeQuality
    }

    var stars: Int {
        if overallQuality >= 0.85 { return 3 }
        if overallQuality >= 0.6 { return 2 }
        return 1
    }

    var title: String {
        "\(color.displayName) \(shape.displayName)"
    }
}
