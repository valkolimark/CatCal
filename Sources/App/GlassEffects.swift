import SwiftUI

extension View {
    /// Applies iOS 26 Liquid Glass to card-like surfaces (event cards, task
    /// rows), falling back to `.ultraThinMaterial` on earlier OS versions.
    /// Wrap groups of these in a `GlassEffectContainer` where several sit
    /// together, per Apple's guidance, so they can render/merge as one
    /// glass surface instead of independently.
    ///
    /// The hairline highlight and soft drop shadow are what lift a card off
    /// the sky behind it — glass alone reads flat against a light background.
    func catCalGlassCard(cornerRadius: CGFloat = CatCalRadius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return glassBackground(in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.45), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    /// Small capsule surfaces: the streak/XP pill in a screen header.
    func catCalGlassPill() -> some View {
        catCalGlassCard(cornerRadius: CatCalRadius.pill)
    }

    @ViewBuilder
    private func glassBackground(in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
