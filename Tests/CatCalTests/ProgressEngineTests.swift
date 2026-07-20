import Foundation
import Testing
@testable import CatCal

@Suite("ProgressEngine XP curve")
struct ProgressEngineXPTests {
    @Test(
        "Cumulative XP required for a level",
        arguments: [
            (level: 1, expected: 0),
            (level: 2, expected: 150),
            (level: 3, expected: 300),
            (level: 5, expected: 600),
            (level: 26, expected: 3750)
        ]
    )
    func cumulativeXP(_ case: (level: Int, expected: Int)) {
        #expect(ProgressEngine.cumulativeXP(forLevel: `case`.level) == `case`.expected)
    }

    @Test(
        "Level for a given total XP",
        arguments: [
            (totalXP: 0, expected: 1),
            (totalXP: 149, expected: 1),
            (totalXP: 150, expected: 2),
            (totalXP: 299, expected: 2),
            (totalXP: 300, expected: 3),
            (totalXP: 3750, expected: 26)
        ]
    )
    func level(_ case: (totalXP: Int, expected: Int)) {
        #expect(ProgressEngine.level(forTotalXP: `case`.totalXP) == `case`.expected)
    }

    @Test("XP earned into the current level resets at each threshold")
    func xpIntoCurrentLevel() {
        #expect(ProgressEngine.xpIntoCurrentLevel(forTotalXP: 0) == 0)
        #expect(ProgressEngine.xpIntoCurrentLevel(forTotalXP: 75) == 75)
        #expect(ProgressEngine.xpIntoCurrentLevel(forTotalXP: 150) == 0)
        #expect(ProgressEngine.xpIntoCurrentLevel(forTotalXP: 220) == 70)
    }
}

@Suite("ProgressEngine cat stages")
struct ProgressEngineStageTests {
    @Test(
        "Level maps to the correct cat growth stage",
        arguments: [
            (level: 1, expected: CatStage.newborn),
            (level: 4, expected: CatStage.newborn),
            (level: 5, expected: CatStage.kitten),
            (level: 9, expected: CatStage.kitten),
            (level: 10, expected: CatStage.teen),
            (level: 16, expected: CatStage.teen),
            (level: 17, expected: CatStage.adult),
            (level: 25, expected: CatStage.adult),
            (level: 26, expected: CatStage.majestic),
            (level: 100, expected: CatStage.majestic)
        ]
    )
    func stage(_ case: (level: Int, expected: CatStage)) {
        #expect(ProgressEngine.stage(forLevel: `case`.level) == `case`.expected)
    }
}

@Suite("ProgressEngine XP awarding")
struct ProgressEngineAwardTests {
    @Test("Awarding XP below the next threshold does not level up")
    func noLevelUp() {
        let progress = UserProgress(ownerID: "test-owner")
        let result = ProgressEngine.awardXP(50, to: progress)

        #expect(progress.totalXP == 50)
        #expect(progress.currentLevel == 1)
        #expect(result.leveledUp == false)
        #expect(result.stageChanged == false)
    }

    @Test("Awarding enough XP levels up and reports the transition")
    func levelUp() {
        let progress = UserProgress(ownerID: "test-owner")
        let result = ProgressEngine.awardXP(150, to: progress)

        #expect(progress.totalXP == 150)
        #expect(progress.currentLevel == 2)
        #expect(result.previousLevel == 1)
        #expect(result.newLevel == 2)
        #expect(result.leveledUp == true)
        #expect(result.stageChanged == false)
    }

    @Test("Crossing a stage boundary is reported alongside the level-up")
    func stageChange() {
        let progress = UserProgress(ownerID: "test-owner", totalXP: 450, currentLevel: 4)
        let result = ProgressEngine.awardXP(150, to: progress)

        #expect(progress.currentLevel == 5)
        #expect(result.previousStage == .newborn)
        #expect(result.newStage == .kitten)
        #expect(result.stageChanged == true)
    }

    @Test("Awarding XP over multiple levels at once still lands on the right level")
    func multiLevelJump() {
        let progress = UserProgress(ownerID: "test-owner")
        let result = ProgressEngine.awardXP(1000, to: progress)

        #expect(progress.currentLevel == ProgressEngine.level(forTotalXP: 1000))
        #expect(result.newLevel == 7)
    }
}

@Suite("ProgressEngine streaks")
struct ProgressEngineStreakTests {
    private let calendar = Calendar.current

    @Test("First-ever activity starts the streak at 1")
    func firstActivity() {
        let progress = UserProgress(ownerID: "test-owner")
        let today = Date()

        ProgressEngine.updateStreak(for: progress, referenceDate: today)

        #expect(progress.currentStreak == 1)
        #expect(progress.lastActiveDate == calendar.startOfDay(for: today))
    }

    @Test("Being active again the same day does not double-count")
    func sameDayIsNoOp() {
        let progress = UserProgress(ownerID: "test-owner")
        let today = Date()

        ProgressEngine.updateStreak(for: progress, referenceDate: today)
        ProgressEngine.updateStreak(for: progress, referenceDate: today.addingTimeInterval(3600))

        #expect(progress.currentStreak == 1)
    }

    @Test("Being active on the very next day extends the streak")
    func consecutiveDayExtends() {
        let progress = UserProgress(ownerID: "test-owner")
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        ProgressEngine.updateStreak(for: progress, referenceDate: yesterday)
        ProgressEngine.updateStreak(for: progress, referenceDate: today)

        #expect(progress.currentStreak == 2)
    }

    @Test("Missing a day resets the streak to 1")
    func gapResets() {
        let progress = UserProgress(ownerID: "test-owner")
        let today = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        ProgressEngine.updateStreak(for: progress, referenceDate: threeDaysAgo)
        ProgressEngine.updateStreak(for: progress, referenceDate: today)

        #expect(progress.currentStreak == 1)
    }
}
