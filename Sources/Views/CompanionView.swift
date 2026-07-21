import SwiftData
import SwiftUI

private extension CatStage {
    var accentColor: Color {
        switch self {
        case .newborn: CatCalColor.textSecondary
        case .kitten: CatCalColor.sourceSuccess
        case .teen: CatCalColor.sourcePro
        case .adult: CatCalColor.sourceGoogle
        case .majestic: CatCalColor.xpGold
        }
    }
}

struct CompanionView: View {
    @Query private var progressRecords: [UserProgress]
    @Query private var collarCosmetics: [Cosmetic]
    @Query private var achievements: [Achievement]
    @Query private var pendingTasks: [AppTask]

    init() {
        let ownerID = CurrentUser.id
        _progressRecords = Query(filter: #Predicate<UserProgress> { $0.ownerID == ownerID })
        _collarCosmetics = Query(
            filter: #Predicate<Cosmetic> { $0.ownerID == ownerID && $0.category == "collar" },
            sort: \Cosmetic.name
        )
        _achievements = Query(filter: #Predicate<Achievement> { $0.ownerID == ownerID })
        _pendingTasks = Query(
            filter: #Predicate<AppTask> { $0.ownerID == ownerID && $0.isCompleted == false }
        )
    }

    private var progress: UserProgress? { progressRecords.first }
    private var catName: String { progress?.catName ?? "Whiskers" }
    private var level: Int { progress?.currentLevel ?? 1 }
    private var totalXP: Int { progress?.totalXP ?? 0 }
    private var stage: CatStage { ProgressEngine.stage(forLevel: level) }

    private var hasOverdueTasks: Bool {
        let now = Date()
        return pendingTasks.contains { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < now
        }
    }

    private var moodLine: String {
        hasOverdueTasks ? "Ready when you are" : "Feeling great today"
    }

    var body: some View {
        ZStack {
            CatCalBackground()

            VStack(spacing: 0) {
                ScreenHeader(title: catName, subtitle: "\(stage.rawValue) stage") {
                    StatPill(
                        systemImage: "star.fill",
                        text: "Lv \(level)",
                        iconTint: stage.accentColor
                    )
                }

                ScrollView {
                    VStack(spacing: CatCalSpacing.lg) {
                        avatarSection

                        XPProgressBar(
                            currentXP: ProgressEngine.xpIntoCurrentLevel(forTotalXP: totalXP),
                            neededXP: ProgressEngine.xpPerLevel
                        )
                        .padding(CatCalSpacing.md)
                        .catCalGlassCard()

                        collarsSection
                    }
                    .padding(.horizontal, CatCalSpacing.screen)
                    .padding(.bottom, CatCalSpacing.tabBarClearance)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, CatCalSpacing.sm)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            SoundService.shared.startPurr()
        }
        .onDisappear {
            SoundService.shared.stopPurr()
        }
    }

    private var avatarSection: some View {
        VStack(spacing: CatCalSpacing.sm) {
            CatBuddyImage(height: 200)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CatCalSpacing.sm)
                .background(
                    Circle()
                        .fill(stage.accentColor.opacity(0.12))
                        .frame(width: 220, height: 220)
                )

            Text(moodLine)
                .font(CatCalFont.body(16))
                .foregroundStyle(CatCalColor.textSecondary)
        }
        .padding(.top, CatCalSpacing.sm)
    }

    private var collarsSection: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
            Text("Collars")
                .font(CatCalFont.headline(18))
                .foregroundStyle(CatCalColor.textPrimary)

            // Fixed row height rather than intrinsic: locked cells carry an
            // extra "how to unlock" line, and a ragged grid looks broken.
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: CatCalSpacing.md
            ) {
                ForEach(collarCosmetics) { cosmetic in
                    CosmeticCell(cosmetic: cosmetic, achievementTitle: achievementTitle(forCosmeticID: cosmetic.id))
                        .frame(height: 168)
                }
            }
        }
    }

    private func achievementTitle(forCosmeticID id: String) -> String? {
        achievements.first { $0.id == id }?.title
    }
}

private struct XPProgressBar: View {
    let currentXP: Int
    let neededXP: Int

    private var fraction: Double {
        neededXP > 0 ? min(1, Double(currentXP) / Double(neededXP)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(CatCalColor.textSecondary.opacity(0.18))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [CatCalColor.xpGreen, CatCalColor.xpGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 12)

            Text("\(currentXP) / \(neededXP) XP to next level")
                .font(CatCalFont.caption(13))
                .foregroundStyle(CatCalColor.textSecondary)
        }
    }
}

private struct CosmeticCell: View {
    let cosmetic: Cosmetic
    let achievementTitle: String?

    var body: some View {
        VStack(spacing: CatCalSpacing.sm) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(cosmetic.isUnlocked ? CatCalColor.brandPrimary.opacity(0.15) : CatCalColor.textSecondary.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: cosmetic.isUnlocked ? "seal.fill" : "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(cosmetic.isUnlocked ? CatCalColor.brandPrimary : CatCalColor.textSecondary)
            }

            Text(cosmetic.name)
                .font(CatCalFont.headline(15))
                .foregroundStyle(cosmetic.isUnlocked ? CatCalColor.textPrimary : CatCalColor.textSecondary)
                .multilineTextAlignment(.center)

            if !cosmetic.isUnlocked, let achievementTitle {
                Text(achievementTitle)
                    .font(CatCalFont.caption(11))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(CatCalSpacing.md)
        .frame(maxWidth: .infinity)
        .catCalGlassCard()
        .opacity(cosmetic.isUnlocked ? 1 : 0.7)
    }
}

#Preview {
    NavigationStack {
        CompanionView()
    }
    .environment(GamificationCenter())
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
