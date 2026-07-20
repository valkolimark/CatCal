import Foundation
import SwiftData

@Model
final class Cosmetic {
    @Attribute(.unique) var id: String
    var name: String
    var category: String
    var isUnlocked: Bool
    var ownerID: String

    init(
        id: String,
        name: String,
        category: String,
        isUnlocked: Bool = false,
        ownerID: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isUnlocked = isUnlocked
        self.ownerID = ownerID
    }
}
