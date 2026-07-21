import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    /// EventKit's system permission, tracked separately from the aggregator's
    /// results: a denial there shouldn't hide events arriving from a directly
    /// connected Google or Outlook account.
    var accessState: CalendarAccessState = .notDetermined
    var events: [UnifiedEvent] = []
    var failures: [CalendarSourceFailure] = []
    var connectedSources: Set<CalendarSource> = []
    var isLoading = false

    /// True when EventKit is off *and* nothing else is feeding us events —
    /// only then is the full-screen permission state the whole story.
    var showsPermissionState: Bool {
        accessState == .denied && events.isEmpty
    }

    func load(using aggregator: CalendarAggregator, referenceDate: Date = Date()) async {
        isLoading = true
        defer { isLoading = false }

        if let eventKit = aggregator.source(as: EventKitCalendarSource.self) {
            let state = await eventKit.accessState()
            accessState = state == .notDetermined ? await eventKit.requestAccess() : state

            if accessState == .authorized {
                connectedSources = await eventKit.connectedSources()
            }
        } else {
            accessState = .authorized
        }

        let bounds = Self.dayBounds(for: referenceDate)
        let result = await aggregator.fetchEvents(from: bounds.start, to: bounds.end)

        events = result.events
        failures = result.failures
        // Directly connected providers count toward the "connect a calendar"
        // achievements too, not just the ones EventKit surfaces.
        connectedSources.formUnion(result.events.map(\.source))
    }

    private static func dayBounds(for referenceDate: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }
}
