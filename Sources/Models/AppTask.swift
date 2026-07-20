import Foundation
import SwiftData

@Model
final class AppTask {
    var title: String
    var notes: String
    var dueDate: Date?
    var isCompleted: Bool
    var xpValue: Int
    var ownerID: String

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        xpValue: Int = 5,
        ownerID: String
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.xpValue = xpValue
        self.ownerID = ownerID
    }
}
