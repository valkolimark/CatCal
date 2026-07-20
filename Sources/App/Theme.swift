import SwiftUI

/// CatCal's design tokens: color, type, spacing, and radii.
/// Every screen should build from these rather than hardcoding values,
/// so the Liquid Glass pass in Cycle 7 has one place to adjust.
enum CatCalColor {
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")

    static let appBackground = Color("AppBackground")
    static let surface = Color("Surface")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    /// Calendar source tags (Cycle 2): Google, Outlook, iCloud.
    static let sourceGoogle = Color("SourceGoogle")
    static let sourcePro = Color("SourcePro")
    static let sourceSuccess = Color("SourceSuccess")

    static let xpGold = Color("XPGold")
    static let warning = Color("Warning")
    static let danger = Color("Danger")
}

enum CatCalFont {
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

enum CatCalSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum CatCalRadius {
    static let card: CGFloat = 20
    static let control: CGFloat = 14
    static let pill: CGFloat = 999
}
