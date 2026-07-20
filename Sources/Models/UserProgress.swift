import Foundation
import SwiftData

/// CloudKit requires every non-optional property to carry a default value,
/// so the stored properties below are all defaulted even though the
/// initializer sets them explicitly.
@Model
final class UserProgress {
    var ownerID: String = ""
    var catName: String = "Whiskers"
    var totalXP: Int = 0
    var currentLevel: Int = 1
    var currentStreak: Int = 0
    var lastActiveDate: Date?

    init(
        ownerID: String,
        catName: String = "Whiskers",
        totalXP: Int = 0,
        currentLevel: Int = 1,
        currentStreak: Int = 0,
        lastActiveDate: Date? = nil
    ) {
        self.ownerID = ownerID
        self.catName = catName
        self.totalXP = totalXP
        self.currentLevel = currentLevel
        self.currentStreak = currentStreak
        self.lastActiveDate = lastActiveDate
    }
}
