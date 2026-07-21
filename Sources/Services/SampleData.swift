#if DEBUG
import Foundation
import SwiftData

/// Debug-only fixtures for running the app in the Simulator, where there's no
/// real calendar account and no task history to look at. Pass
/// `-seedSampleData` as a launch argument alongside `-skipAuth`.
///
/// Compiled out of release builds entirely.
enum SampleData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleData")
    }

    /// `-startTab tasks` opens straight to a given tab, so a screen can be
    /// checked against its design without tapping through the app first.
    static var startTab: AppTab? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-startTab"), index + 1 < arguments.count else {
            return nil
        }
        return AppTab(rawValue: arguments[index + 1])
    }

    /// Stands in for a connected provider so the Today screen has something
    /// to render. Conforms to the same protocol as the real sources, so this
    /// also exercises the Cycle 10 seam end to end.
    struct CalendarSource: CalendarSourceProviding {
        nonisolated var sourceID: String { "sample" }
        nonisolated var displayName: String { "Sample Calendar" }
        var isConnected: Bool { true }

        func fetchEvents(from start: Date, to end: Date) async throws -> [UnifiedEvent] {
            [
                event(id: "sample-1", title: "Team standup", start: 9, durationMinutes: 30, source: .google),
                event(id: "sample-2", title: "Client review", start: 11, durationMinutes: 60, source: .outlook),
                event(id: "sample-3", title: "Dentist appointment", start: 15, durationMinutes: 45, source: .iCloud)
            ]
        }

        private func event(
            id: String,
            title: String,
            start hour: Int,
            durationMinutes: Int,
            source: CatCal.CalendarSource
        ) -> UnifiedEvent {
            let calendar = Calendar.current
            let startDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            return UnifiedEvent(
                id: id,
                title: title,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                isAllDay: false,
                source: source,
                calendarID: "sample"
            )
        }
    }

    @MainActor
    static func seedTasks(context: ModelContext) {
        let ownerID = CurrentUser.id
        let descriptor = FetchDescriptor<AppTask>(predicate: #Predicate { $0.ownerID == ownerID })
        guard (try? context.fetch(descriptor))?.isEmpty ?? false else { return }

        let samples: [(String, Int, Bool)] = [
            ("Reply to Maya's email", 5, false),
            ("Prep slides for Monday", 10, false),
            ("Pick up dry cleaning", 5, false),
            ("Morning walk", 5, true)
        ]

        for (title, xp, isCompleted) in samples {
            context.insert(AppTask(title: title, isCompleted: isCompleted, xpValue: xp, ownerID: ownerID))
        }
        try? context.save()
    }
}
#endif
