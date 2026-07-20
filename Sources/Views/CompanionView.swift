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
            CatCalColor.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CatCalSpacing.lg) {
                    header
                    avatarSection

                    XPProgressBar(
                        currentXP: ProgressEngine.xpIntoCurrentLevel(forTotalXP: totalXP),
                        neededXP: ProgressEngine.xpPerLevel
                    )
                    .padding(.horizontal, CatCalSpacing.md)

                    collarsSection
                }
                .padding(.vertical, CatCalSpacing.md)
            }
        }
        .navigationTitle("Buddy")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: CatCalSpacing.xs) {
                Text(catName)
                    .font(CatCalFont.title(24))
                    .foregroundStyle(CatCalColor.textPrimary)
                Text("\(stage.rawValue) stage")
                    .font(CatCalFont.body())
                    .foregroundStyle(CatCalColor.textSecondary)
            }

            Spacer()

            LevelPill(level: level)
        }
        .padding(.horizontal, CatCalSpacing.md)
    }

    private var avatarSection: some View {
        VStack(spacing: CatCalSpacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CatCalColor.brandPrimary, CatCalColor.brandSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .overlay(Circle().stroke(stage.accentColor, lineWidth: 4))

                Image(systemName: "cat.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
            }

            Text(moodLine)
                .font(CatCalFont.body())
                .foregroundStyle(CatCalColor.textSecondary)
        }
    }

    private var collarsSection: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
            Text("Collars")
                .font(CatCalFont.headline(18))
                .foregroundStyle(CatCalColor.textPrimary)
                .padding(.horizontal, CatCalSpacing.md)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CatCalSpacing.md) {
                ForEach(collarCosmetics) { cosmetic in
                    CosmeticCell(cosmetic: cosmetic, achievementTitle: achievementTitle(forCosmeticID: cosmetic.id))
                }
            }
            .padding(.horizontal, CatCalSpacing.md)
        }
    }

    private func achievementTitle(forCosmeticID id: String) -> String? {
        achievements.first { $0.id == id }?.title
    }
}

private struct LevelPill: View {
    let level: Int

    var body: some View {
        Text("Lv \(level)")
            .font(CatCalFont.headline(15))
            .foregroundStyle(CatCalColor.textPrimary)
            .padding(.horizontal, CatCalSpacing.md)
            .padding(.vertical, CatCalSpacing.sm)
            .background(CatCalColor.surface, in: Capsule())
    }
}

private struct XPProgressBar: View {
    let currentXP: Int
    let neededXP: Int

    private var fraction: Double {
        neededXP > 0 ? min(1, Double(currentXP) / Double(neededXP)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(CatCalColor.surface)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [CatCalColor.brandPrimary, CatCalColor.xpGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 12)

            Text("\(currentXP) / \(neededXP) XP to next level")
                .font(CatCalFont.caption())
                .foregroundStyle(CatCalColor.textSecondary)
        }
    }
}

private struct CosmeticCell: View {
    let cosmetic: Cosmetic
    let achievementTitle: String?

    var body: some View {
        VStack(spacing: CatCalSpacing.sm) {
            ZStack {
                Circle()
                    .fill(cosmetic.isUnlocked ? CatCalColor.brandPrimary.opacity(0.15) : CatCalColor.appBackground)
                    .frame(width: 56, height: 56)

                Image(systemName: cosmetic.isUnlocked ? "seal.fill" : "lock.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(cosmetic.isUnlocked ? CatCalColor.brandPrimary : CatCalColor.textSecondary)
            }

            Text(cosmetic.name)
                .font(CatCalFont.caption(12))
                .foregroundStyle(cosmetic.isUnlocked ? CatCalColor.textPrimary : CatCalColor.textSecondary)
                .multilineTextAlignment(.center)

            if !cosmetic.isUnlocked, let achievementTitle {
                Text(achievementTitle)
                    .font(CatCalFont.caption(10))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(CatCalSpacing.md)
        .frame(maxWidth: .infinity)
        .background(CatCalColor.surface, in: RoundedRectangle(cornerRadius: CatCalRadius.card))
        .opacity(cosmetic.isUnlocked ? 1 : 0.55)
    }
}

#Preview {
    NavigationStack {
        CompanionView()
    }
    .environment(GamificationCenter())
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self], inMemory: true)
}
