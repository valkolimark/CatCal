import Foundation

enum CatStage: String, CaseIterable {
    case newborn = "Newborn"
    case kitten = "Kitten"
    case teen = "Teen cat"
    case adult = "Adult"
    case majestic = "Majestic"
}

struct LevelUpResult: Equatable {
    let previousLevel: Int
    let newLevel: Int
    let previousStage: CatStage
    let newStage: CatStage

    var leveledUp: Bool { newLevel > previousLevel }
    var stageChanged: Bool { newStage != previousStage }
}

enum ProgressEngine {
    /// Flat cost per level. Level 1 is the starting level (0 XP); reaching
    /// level N requires (N - 1) * xpPerLevel cumulative XP.
    static let xpPerLevel = 150

    static func cumulativeXP(forLevel level: Int) -> Int {
        max(0, level - 1) * xpPerLevel
    }

    static func level(forTotalXP totalXP: Int) -> Int {
        max(0, totalXP) / xpPerLevel + 1
    }

    static func xpIntoCurrentLevel(forTotalXP totalXP: Int) -> Int {
        totalXP - cumulativeXP(forLevel: level(forTotalXP: totalXP))
    }

    static func stage(forLevel level: Int) -> CatStage {
        switch level {
        case ..<5: return .newborn
        case 5..<10: return .kitten
        case 10..<17: return .teen
        case 17..<26: return .adult
        default: return .majestic
        }
    }

    /// Adds XP to `progress` and reports whether it crossed a level or
    /// cat-stage boundary, so the UI (Cycle 4) knows when to celebrate.
    @discardableResult
    static func awardXP(_ amount: Int, to progress: UserProgress) -> LevelUpResult {
        let previousLevel = progress.currentLevel
        let previousStage = stage(forLevel: previousLevel)

        progress.totalXP += amount
        progress.currentLevel = level(forTotalXP: progress.totalXP)

        let newStage = stage(forLevel: progress.currentLevel)
        return LevelUpResult(
            previousLevel: previousLevel,
            newLevel: progress.currentLevel,
            previousStage: previousStage,
            newStage: newStage
        )
    }
}
