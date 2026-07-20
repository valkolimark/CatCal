import Foundation
import SwiftData

enum AchievementID: String, CaseIterable {
    case firstCalendar = "first_calendar"
    case allCalendars = "all_calendars"
    case firstTask = "first_task"
    case hundredTasks = "hundred_tasks"
    case weekStreak = "week_streak"
    case monthStreak = "month_streak"
    case teenStage = "teen_stage"
    case majesticStage = "majestic_stage"
}

struct AchievementDefinition {
    let id: AchievementID
    let title: String
    let achievementDescription: String
    let cosmeticName: String
    let cosmeticCategory: String
}

enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        AchievementDefinition(
            id: .firstCalendar,
            title: "Plugged In",
            achievementDescription: "Connect your first calendar",
            cosmeticName: "Blue Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .allCalendars,
            title: "Fully Synced",
            achievementDescription: "Connect all three calendar sources",
            cosmeticName: "Rainbow Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .firstTask,
            title: "Getting Started",
            achievementDescription: "Complete your first task",
            cosmeticName: "Bell Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .hundredTasks,
            title: "Task Master",
            achievementDescription: "Complete 100 tasks",
            cosmeticName: "Golden Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .weekStreak,
            title: "On a Roll",
            achievementDescription: "Reach a 7-day streak",
            cosmeticName: "Flame Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .monthStreak,
            title: "Dedicated",
            achievementDescription: "Reach a 30-day streak",
            cosmeticName: "Diamond Collar",
            cosmeticCategory: "collar"
        ),
        AchievementDefinition(
            id: .teenStage,
            title: "Growing Up",
            achievementDescription: "Reach the Teen cat stage",
            cosmeticName: "Bowtie",
            cosmeticCategory: "accessory"
        ),
        AchievementDefinition(
            id: .majesticStage,
            title: "Majestic",
            achievementDescription: "Reach the Majestic stage",
            cosmeticName: "Royal Crown",
            cosmeticCategory: "accessory"
        )
    ]
}

/// Wires the trigger/unlock plumbing for the Cycle 4 achievement pass: each
/// `check*` function inspects current progress and unlocks any achievement
/// (plus its paired cosmetic) whose condition is now met. The achievements
/// screen itself comes later — for now these just need to fire correctly.
@MainActor
enum AchievementEngine {
    static func seedIfNeeded(context: ModelContext) {
        let ownerID = CurrentUser.id
        let descriptor = FetchDescriptor<Achievement>(predicate: #Predicate { $0.ownerID == ownerID })
        let existingIDs = Set((try? context.fetch(descriptor))?.map(\.id) ?? [])

        for definition in AchievementCatalog.all where !existingIDs.contains(definition.id.rawValue) {
            context.insert(
                Achievement(
                    id: definition.id.rawValue,
                    title: definition.title,
                    achievementDescription: definition.achievementDescription,
                    ownerID: ownerID
                )
            )
            context.insert(
                Cosmetic(
                    id: definition.id.rawValue,
                    name: definition.cosmeticName,
                    category: definition.cosmeticCategory,
                    ownerID: ownerID
                )
            )
        }
    }

    static func checkTaskCompletion(
        completedTaskCount: Int,
        context: ModelContext
    ) -> [(achievement: Achievement, cosmetic: Cosmetic)] {
        var unlocked: [(achievement: Achievement, cosmetic: Cosmetic)] = []
        if completedTaskCount >= 1, let result = unlock(.firstTask, context: context) {
            unlocked.append(result)
        }
        if completedTaskCount >= 100, let result = unlock(.hundredTasks, context: context) {
            unlocked.append(result)
        }
        return unlocked
    }

    static func checkStreak(
        _ streak: Int,
        context: ModelContext
    ) -> [(achievement: Achievement, cosmetic: Cosmetic)] {
        var unlocked: [(achievement: Achievement, cosmetic: Cosmetic)] = []
        if streak >= 7, let result = unlock(.weekStreak, context: context) {
            unlocked.append(result)
        }
        if streak >= 30, let result = unlock(.monthStreak, context: context) {
            unlocked.append(result)
        }
        return unlocked
    }

    static func checkLevel(
        _ level: Int,
        context: ModelContext
    ) -> [(achievement: Achievement, cosmetic: Cosmetic)] {
        var unlocked: [(achievement: Achievement, cosmetic: Cosmetic)] = []
        let stage = ProgressEngine.stage(forLevel: level)
        if stage == .teen || stage == .adult || stage == .majestic,
           let result = unlock(.teenStage, context: context) {
            unlocked.append(result)
        }
        if stage == .majestic, let result = unlock(.majesticStage, context: context) {
            unlocked.append(result)
        }
        return unlocked
    }

    static func checkCalendarSources(
        _ sources: Set<CalendarSource>,
        context: ModelContext
    ) -> [(achievement: Achievement, cosmetic: Cosmetic)] {
        var unlocked: [(achievement: Achievement, cosmetic: Cosmetic)] = []
        if !sources.isEmpty, let result = unlock(.firstCalendar, context: context) {
            unlocked.append(result)
        }
        if sources.isSuperset(of: [.google, .outlook, .iCloud]), let result = unlock(.allCalendars, context: context) {
            unlocked.append(result)
        }
        return unlocked
    }

    private static func unlock(
        _ id: AchievementID,
        context: ModelContext
    ) -> (achievement: Achievement, cosmetic: Cosmetic)? {
        let ownerID = CurrentUser.id
        let rawID = id.rawValue

        let achievementDescriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.id == rawID && $0.ownerID == ownerID }
        )
        guard let achievement = try? context.fetch(achievementDescriptor).first, !achievement.isUnlocked else {
            return nil
        }

        let cosmeticDescriptor = FetchDescriptor<Cosmetic>(
            predicate: #Predicate { $0.id == rawID && $0.ownerID == ownerID }
        )
        guard let cosmetic = try? context.fetch(cosmeticDescriptor).first else {
            return nil
        }

        achievement.isUnlocked = true
        achievement.unlockedDate = Date()
        cosmetic.isUnlocked = true

        return (achievement, cosmetic)
    }
}
