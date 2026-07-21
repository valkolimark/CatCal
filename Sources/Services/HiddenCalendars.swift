import Foundation

/// Per-source set of calendar identifiers the user has switched off on the
/// Manage Calendars screen.
///
/// Deliberately `UserDefaults` rather than SwiftData/CloudKit: which
/// calendars are visible is device-local (calendar identifiers differ per
/// device for EventKit anyway), so syncing it would do more harm than good.
enum HiddenCalendars {
    private static func key(forSourceID sourceID: String) -> String {
        "hiddenCalendarIDs.\(sourceID)"
    }

    static func identifiers(forSourceID sourceID: String) -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: key(forSourceID: sourceID)) ?? []
        return Set(stored)
    }

    static func setIdentifiers(_ identifiers: Set<String>, forSourceID sourceID: String) {
        UserDefaults.standard.set(Array(identifiers).sorted(), forKey: key(forSourceID: sourceID))
    }

    static func isHidden(_ calendarID: String, forSourceID sourceID: String) -> Bool {
        identifiers(forSourceID: sourceID).contains(calendarID)
    }

    static func setHidden(_ isHidden: Bool, calendarID: String, forSourceID sourceID: String) {
        var identifiers = self.identifiers(forSourceID: sourceID)
        if isHidden {
            identifiers.insert(calendarID)
        } else {
            identifiers.remove(calendarID)
        }
        setIdentifiers(identifiers, forSourceID: sourceID)
    }

    static func hideAll(_ calendarIDs: [String], forSourceID sourceID: String) {
        setIdentifiers(identifiers(forSourceID: sourceID).union(calendarIDs), forSourceID: sourceID)
    }
}
