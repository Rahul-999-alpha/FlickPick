import SwiftUI

/// Design tokens from DESIGN.md — colors, typography, spacing.
enum FP {
    // MARK: - Colors

    static let background = Color(hex: 0x0A0A0C)
    static let surface = Color(hex: 0x161619)
    static let surfaceHover = Color(hex: 0x1E1E22)
    static let border = Color(hex: 0x2A2A30)

    static let textPrimary = Color(hex: 0xE8E8ED)
    static let textSecondary = Color(hex: 0x8B8B96)

    static let accent = Color(hex: 0x6366F1)
    static let accentGlow = Color(hex: 0x6366F1).opacity(0.2)
    static let watched = Color(hex: 0x22C55E)
    static let newBadge = Color(hex: 0xF59E0B)

    // MARK: - Dimensions

    static let cardRadius: CGFloat = 12
    static let cardWidth: CGFloat = 220
    static let cardHeight: CGFloat = 124
    static let sectionPadding: CGFloat = 24
    static let cardSpacing: CGFloat = 16

    // MARK: - Typography

    static let titleFont = Font.system(size: 28, weight: .bold)
    static let subtitleFont = Font.system(size: 18, weight: .semibold)
    static let sectionFont = Font.system(size: 20, weight: .semibold)
    static let bodyFont = Font.system(size: 14, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
    static let monoFont = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let badgeFont = Font.system(size: 9, weight: .bold)
}

// MARK: - Color hex initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
