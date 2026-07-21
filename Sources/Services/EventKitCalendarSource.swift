import EventKit
import Foundation

enum CalendarAccessState: Sendable {
    case notDetermined
    case denied
    case authorized
}

/// Events from every calendar account the user has added in iOS Settings —
/// Google, Outlook and iCloud all surface as EventKit calendars automatically
/// once added as system accounts.
///
/// An actor because EKEventStore's fetch APIs are blocking and shouldn't run
/// on the main thread. Previously `CalendarService`; renamed in Cycle 10 when
/// it became one of several `CalendarSourceProviding` implementations rather
/// than the only path to calendar data.
actor EventKitCalendarSource: CalendarSourceProviding {
    static let id = "eventkit"

    nonisolated var sourceID: String { Self.id }
    nonisolated var displayName: String { "iPhone Calendars" }

    private let eventStore = EKEventStore()

    var isConnected: Bool {
        accessState() == .authorized
    }

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
        Set(visibleCalendars().map(Self.source(for:)))
    }

    func availableCalendars() -> [SourceCalendar] {
        eventStore.calendars(for: .event)
            .map { calendar in
                SourceCalendar(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    accountEmail: calendar.source.title
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchEvents(from start: Date, to end: Date) throws -> [UnifiedEvent] {
        guard accessState() == .authorized else {
            throw CalendarSourceError.accessDenied
        }

        let calendars = visibleCalendars()
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)

        return eventStore.events(matching: predicate).map { event in
            UnifiedEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title?.isEmpty == false ? event.title! : "Untitled event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                source: Self.source(for: event.calendar),
                calendarID: event.calendar.calendarIdentifier
            )
        }
    }

    /// Calendars the user hasn't hidden on the Manage Calendars screen.
    private func visibleCalendars() -> [EKCalendar] {
        let hidden = HiddenCalendars.identifiers(forSourceID: Self.id)
        return eventStore.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
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
