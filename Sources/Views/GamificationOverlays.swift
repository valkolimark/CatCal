import SwiftUI

struct XPToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(CatCalFont.headline())
            .foregroundStyle(.white)
            .padding(.horizontal, CatCalSpacing.lg)
            .padding(.vertical, CatCalSpacing.sm)
            .background(CatCalColor.brandSecondary, in: Capsule())
            .shadow(radius: 8, y: 4)
    }
}

struct LevelUpCelebrationView: View {
    let celebration: GamificationCenter.Celebration
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: CatCalSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(CatCalColor.xpGold)

                Text(celebration.leveledUp ? "Level \(celebration.newLevel)!" : "Achievement Unlocked!")
                    .font(CatCalFont.title(28))
                    .foregroundStyle(CatCalColor.textPrimary)
                    .multilineTextAlignment(.center)

                if celebration.stageChanged {
                    Text("Your cat is now a \(celebration.newStage.rawValue)")
                        .font(CatCalFont.headline())
                        .foregroundStyle(CatCalColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let achievement = celebration.unlockedAchievement {
                    UnlockRow(icon: "rosette", title: achievement.title)
                }

                if let cosmetic = celebration.unlockedCosmetic {
                    UnlockRow(icon: "gift.fill", title: "\(cosmetic.name) unlocked")
                }

                Button(action: onDismiss) {
                    Text("Nice!")
                        .font(CatCalFont.headline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CatCalSpacing.sm)
                        .background(CatCalColor.brandPrimary, in: Capsule())
                }
                .padding(.top, CatCalSpacing.sm)
            }
            .padding(CatCalSpacing.lg)
            .background(CatCalColor.surface, in: RoundedRectangle(cornerRadius: CatCalRadius.card))
            .padding(.horizontal, CatCalSpacing.xl)
        }
    }
}

private struct UnlockRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: CatCalSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(CatCalColor.xpGold)
            Text(title)
                .font(CatCalFont.body(14))
                .foregroundStyle(CatCalColor.textPrimary)
        }
    }
}
