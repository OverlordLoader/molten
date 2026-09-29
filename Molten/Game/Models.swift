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
    // Premium colors — locked until their color pack is purchased
    // (or a single color is unlocked for one piece via rewarded ad).
    case aurora, opal      // Aurora Pack
    case magma, solar      // Inferno Pack
    case abyss, void       // Abyss Pack

    var id: String { rawValue }

    /// The color pack this color belongs to, or nil for the 6 base colors
    /// that are always available.
    var pack: ColorPack? {
        switch self {
        case .aurora, .opal: return .aurora
        case .magma, .solar: return .inferno
        case .abyss, .void: return .abyss
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .ember: return "Ember"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .violet: return "Violet"
        case .rose: return "Rose"
        case .frost: return "Frost"
        case .aurora: return "Aurora"
        case .opal: return "Opal"
        case .magma: return "Magma"
        case .solar: return "Solar"
        case .abyss: return "Abyss"
        case .void: return "Void"
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
        case .aurora: return Color(red: 0.20, green: 0.90, blue: 0.70)
        case .opal: return Color(red: 0.95, green: 0.88, blue: 0.95)
        case .magma: return Color(red: 0.75, green: 0.12, blue: 0.08)
        case .solar: return Color(red: 1.0, green: 0.80, blue: 0.20)
        case .abyss: return Color(red: 0.08, green: 0.15, blue: 0.35)
        case .void: return Color(red: 0.15, green: 0.08, blue: 0.22)
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
        case .aurora: return SKColor(red: 0.20, green: 0.90, blue: 0.70, alpha: 1.0)
        case .opal: return SKColor(red: 0.95, green: 0.88, blue: 0.95, alpha: 1.0)
        case .magma: return SKColor(red: 0.75, green: 0.12, blue: 0.08, alpha: 1.0)
        case .solar: return SKColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1.0)
        case .abyss: return SKColor(red: 0.08, green: 0.15, blue: 0.35, alpha: 1.0)
        case .void: return SKColor(red: 0.15, green: 0.08, blue: 0.22, alpha: 1.0)
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
        case .aurora: return SKColor(red: 0.45, green: 1.0, blue: 0.85, alpha: 1.0)
        case .opal: return SKColor(red: 1.0, green: 0.95, blue: 1.0, alpha: 1.0)
        case .magma: return SKColor(red: 1.0, green: 0.35, blue: 0.15, alpha: 1.0)
        case .solar: return SKColor(red: 1.0, green: 0.92, blue: 0.45, alpha: 1.0)
        case .abyss: return SKColor(red: 0.25, green: 0.40, blue: 0.75, alpha: 1.0)
        case .void: return SKColor(red: 0.35, green: 0.20, blue: 0.50, alpha: 1.0)
        }
    }
}

/// A purchasable color pack: 2 premium glass colors, yours forever.
enum ColorPack: String, CaseIterable, Identifiable {
    case aurora, inferno, abyss

    var id: String { rawValue }

    /// Must match the product created in App Store Connect exactly.
    var productID: String { "app.molten.studio.colorpack.\(rawValue)" }

    var displayName: String {
        switch self {
        case .aurora: return "Aurora Pack"
        case .inferno: return "Inferno Pack"
        case .abyss: return "Abyss Pack"
        }
    }

    var tagline: String {
        switch self {
        case .aurora: return "Shimmering northern-light glass"
        case .inferno: return "Forged in the heart of the volcano"
        case .abyss: return "Colors from the deep dark"
        }
    }

    var colors: [PieceColor] {
        PieceColor.allCases.filter { $0.pack == self }
    }

    /// Fallback price shown if the App Store product hasn't loaded yet.
    var fallbackPrice: String { "$1.99" }
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
