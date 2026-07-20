import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: String
    var title: String
    var achievementDescription: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    var ownerID: String

    init(
        id: String,
        title: String,
        achievementDescription: String,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil,
        ownerID: String
    ) {
        self.id = id
        self.title = title
        self.achievementDescription = achievementDescription
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
        self.ownerID = ownerID
    }
}
