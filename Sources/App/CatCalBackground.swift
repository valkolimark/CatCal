import SwiftUI

/// The sky every screen sits on: a pale blue wash easing to near-white at the
/// horizon, warmed by an off-screen sun to the right and a soft bounce from
/// the lower left. Glass surfaces need something with variation underneath
/// them to read as glass at all — a flat fill makes them look like plain
/// translucent rectangles.
struct CatCalBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: CatCalColor.skyTop, location: 0),
                    .init(color: CatCalColor.appBackground, location: 0.45),
                    .init(color: CatCalColor.skyBottom, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [CatCalColor.warmGlow.opacity(0.85), CatCalColor.warmGlow.opacity(0)],
                center: UnitPoint(x: 1.05, y: 0.46),
                startRadius: 0,
                endRadius: 460
            )

            RadialGradient(
                colors: [CatCalColor.warmGlow.opacity(0.45), CatCalColor.warmGlow.opacity(0)],
                center: UnitPoint(x: 0.05, y: 0.82),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Puts the shared sky behind a screen's content.
    func catCalBackground() -> some View {
        background(CatCalBackground())
    }
}

#Preview {
    CatCalBackground()
}
