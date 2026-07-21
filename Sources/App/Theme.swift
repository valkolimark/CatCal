import SwiftUI

/// CatCal's design tokens: color, type, spacing, and radii.
/// Every screen should build from these rather than hardcoding values.
enum CatCalColor {
    /// The one interactive color: Add task, chevrons, the selected tab.
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")

    /// Base tint under the sky gradient. Screens should use
    /// `CatCalBackground()` rather than filling with this directly.
    static let appBackground = Color("AppBackground")
    static let skyTop = Color("SkyTop")
    static let skyBottom = Color("SkyBottom")
    /// The warm sun glow that keeps the sky from reading cold.
    static let warmGlow = Color("WarmGlow")

    static let surface = Color("Surface")

    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    /// Calendar source tags: Google, Outlook, iCloud.
    static let sourceGoogle = Color("SourceGoogle")
    static let sourcePro = Color("SourcePro")
    static let sourceSuccess = Color("SourceSuccess")

    /// XP chips on Today and Tasks.
    static let xpGreen = Color("XPGreen")
    /// Reserved for celebration moments and the Buddy progress bar, where
    /// gold reads as a reward rather than as a running total.
    static let xpGold = Color("XPGold")
    static let warning = Color("Warning")
    static let danger = Color("Danger")
}

enum CatCalFont {
    /// Screen titles ("Today", "Tasks"). Default design, not rounded —
    /// the weight does the work at this size, and rounded turns mushy.
    static func largeTitle(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

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

    /// Gutter between a screen's cards and the display edge. Every top-level
    /// screen uses this so headers and content share one left edge.
    static let screen: CGFloat = 20

    /// Room the floating tab bar needs at the bottom of a scroll view so the
    /// last row isn't parked underneath it.
    static let tabBarClearance: CGFloat = 96
}

enum CatCalRadius {
    static let card: CGFloat = 22
    static let control: CGFloat = 18
    static let tile: CGFloat = 14
    static let pill: CGFloat = 999
}
