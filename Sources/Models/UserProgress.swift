import Foundation
import SwiftData

@Model
final class UserProgress {
    var ownerID: String
    var totalXP: Int
    var currentLevel: Int
    var currentStreak: Int
    var lastActiveDate: Date?

    init(
        ownerID: String,
        totalXP: Int = 0,
        currentLevel: Int = 1,
        currentStreak: Int = 0,
        lastActiveDate: Date? = nil
    ) {
        self.ownerID = ownerID
        self.totalXP = totalXP
        self.currentLevel = currentLevel
        self.currentStreak = currentStreak
        self.lastActiveDate = lastActiveDate
    }
}
