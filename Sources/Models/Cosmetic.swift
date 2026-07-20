import Foundation
import SwiftData

/// CloudKit requires every non-optional property to carry a default value,
/// so the stored properties below are all defaulted even though the
/// initializer sets them explicitly.
///
/// See `Achievement` for why `id` is no longer `@Attribute(.unique)`.
@Model
final class Cosmetic {
    var id: String = ""
    var name: String = ""
    var category: String = "collar"
    var isUnlocked: Bool = false
    var ownerID: String = ""

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
