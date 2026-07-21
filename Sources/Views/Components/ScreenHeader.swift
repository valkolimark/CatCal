import SwiftUI

/// The big left-aligned title, its quiet subtitle, and an optional glass pill
/// on the right — the shape every top-level screen opens with.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CatCalFont.largeTitle())
                    .foregroundStyle(CatCalColor.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(CatCalFont.body(17))
                        .foregroundStyle(CatCalColor.textSecondary)
                }
            }

            Spacer(minLength: CatCalSpacing.md)

            trailing()
                .padding(.top, CatCalSpacing.sm)
        }
        .padding(.horizontal, CatCalSpacing.screen)
        .padding(.bottom, CatCalSpacing.md)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Glass capsule for a single headline number: the streak flame on Today,
/// today's earned XP on Tasks.
struct StatPill: View {
    let systemImage: String
    let text: String
    var tint: Color = CatCalColor.textPrimary
    var iconTint: Color = CatCalColor.warning

    var body: some View {
        HStack(spacing: CatCalSpacing.xs + 2) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(iconTint)

            Text(text)
                .font(CatCalFont.headline(17))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, CatCalSpacing.md)
        .padding(.vertical, 10)
        .catCalGlassPill()
    }
}

/// Tinted capsule label — calendar source tags and XP amounts.
struct TintedChip: View {
    let text: String
    let tint: Color
    var isMuted = false

    var body: some View {
        Text(text)
            .font(CatCalFont.caption(13))
            .foregroundStyle(isMuted ? CatCalColor.textSecondary : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (isMuted ? CatCalColor.textSecondary : tint).opacity(0.14),
                in: Capsule()
            )
    }
}

#Preview {
    ZStack {
        CatCalBackground()

        VStack(alignment: .leading, spacing: CatCalSpacing.lg) {
            ScreenHeader(title: "Today", subtitle: "Sunday, July 19") {
                StatPill(systemImage: "flame.fill", text: "12")
            }

            HStack {
                TintedChip(text: "Google", tint: CatCalColor.sourceGoogle)
                TintedChip(text: "Outlook", tint: CatCalColor.sourcePro)
                TintedChip(text: "iCloud", tint: CatCalColor.sourceSuccess)
                TintedChip(text: "+5 XP", tint: CatCalColor.xpGreen)
            }
            .padding(.horizontal, CatCalSpacing.screen)

            Spacer()
        }
        .padding(.top, CatCalSpacing.xl)
    }
}
