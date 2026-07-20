import EventKit
import Foundation

enum CalendarSource: String, Sendable {
    case google
    case outlook
    case iCloud

    var label: String {
        switch self {
        case .google: "Google"
        case .outlook: "Outlook"
        case .iCloud: "iCloud"
        }
    }
}

struct CalendarEvent: Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let source: CalendarSource
}

enum CalendarAccessState: Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Wraps EventKit to present one merged, time-sorted feed of today's events
/// across every calendar account the user has added in iOS Settings
/// (Google/Outlook/iCloud all surface as EventKit calendars automatically).
/// An actor because EKEventStore's fetch APIs are blocking and shouldn't
/// run on the main thread.
actor CalendarService {
    private let eventStore = EKEventStore()

    func accessState() -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> CalendarAccessState {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    /// Every distinct calendar source the user currently has connected,
    /// independent of whether they have events today — used to trigger the
    /// "connect a calendar" achievements.
    func connectedSources() -> Set<CalendarSource> {
        Set(eventStore.calendars(for: .event).map(Self.source(for:)))
    }

    func fetchTodayEvents(referenceDate: Date = Date()) -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)

        return eventStore.events(matching: predicate)
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title?.isEmpty == false ? event.title! : "Untitled event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    source: Self.source(for: event.calendar)
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Best-effort classification: EventKit doesn't expose a "Google" source
    /// type directly (Google syncs over CalDAV), so we match on the account
    /// title first, then fall back to the source type. Anything unrecognized
    /// defaults to iCloud styling, per design.
    private static func source(for calendar: EKCalendar) -> CalendarSource {
        let title = calendar.source.title.lowercased()

        if title.contains("gmail") || title.contains("google") {
            return .google
        }
        if title.contains("outlook") || title.contains("office 365") || title.contains("microsoft") {
            return .outlook
        }

        switch calendar.source.sourceType {
        case .exchange:
            return .outlook
        default:
            return .iCloud
        }
    }
}
