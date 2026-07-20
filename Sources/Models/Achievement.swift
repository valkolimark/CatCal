import Foundation
import SwiftData

/// CloudKit requires every non-optional property to carry a default value,
/// so the stored properties below are all defaulted even though the
/// initializer sets them explicitly.
///
/// `id` is deliberately *not* `@Attribute(.unique)`: CloudKit-backed stores
/// don't support unique constraints. `AchievementEngine.seedIfNeeded` guards
/// against duplicates by fetching existing IDs first, which covers the
/// single-device case; two devices seeding simultaneously before their first
/// sync could still produce a duplicate row. Accepted for v1 alongside
/// last-write-wins — reads use `.first`, so a duplicate degrades gracefully.
@Model
final class Achievement {
    var id: String = ""
    var title: String = ""
    var achievementDescription: String = ""
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    var ownerID: String = ""

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
