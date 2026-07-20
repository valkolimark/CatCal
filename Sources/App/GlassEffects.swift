import SwiftUI

extension View {
    /// Applies iOS 26 Liquid Glass to card-like surfaces (event cards, task
    /// rows), falling back to `.ultraThinMaterial` on earlier OS versions.
    /// Wrap groups of these in a `GlassEffectContainer` where several sit
    /// together, per Apple's guidance, so they can render/merge as one
    /// glass surface instead of independently.
    @ViewBuilder
    func catCalGlassCard(cornerRadius: CGFloat = CatCalRadius.card) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
