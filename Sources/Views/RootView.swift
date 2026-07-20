import SwiftUI

/// Placeholder root shown until Cycle 6 wires up onboarding + the tab shell.
struct RootView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CatCalColor.brandPrimary, CatCalColor.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: CatCalSpacing.md) {
                Image(systemName: "cat.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text("CatCal")
                    .font(CatCalFont.title(36))
                    .foregroundStyle(.white)

                Text("Level up your day, one task at a time.")
                    .font(CatCalFont.body())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

#Preview {
    RootView()
}
