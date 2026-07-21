import Foundation

/// Which service an event came from. Drives the accent bar and source tag in
/// the UI. Note this is the *visual/provider* classification — it's separate
/// from `CalendarSourceProviding.sourceID`, which identifies the concrete
/// pipe the event arrived through (the same Google account can reach us
/// either via EventKit or via a direct API connection).
enum CalendarSource: String, Sendable, CaseIterable {
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

/// One calendar event, normalized across every provider so the Today screen
/// never has to know where a given event came from.
struct UnifiedEvent: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let source: CalendarSource
    /// Identifier of the specific calendar within the provider (Google's
    /// calendarList id, Graph's calendar id, or the EKCalendar identifier).
    /// Cycle 13's per-calendar toggles key off this.
    let calendarID: String

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        source: CalendarSource,
        calendarID: String = ""
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.source = source
        self.calendarID = calendarID
    }
}

/// A calendar the user can individually show or hide.
struct SourceCalendar: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    /// Provider-supplied account this calendar belongs to, where known —
    /// used by Cycle 13's duplicate-source check.
    let accountEmail: String?

    init(id: String, title: String, accountEmail: String? = nil) {
        self.id = id
        self.title = title
        self.accountEmail = accountEmail
    }
}

enum CalendarSourceError: LocalizedError, Equatable {
    /// The source isn't connected, so there was nothing to fetch.
    case notConnected
    /// The provider rejected our token — the user has to sign in again.
    case needsReconnect
    case accessDenied
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Not connected."
        case .needsReconnect:
            "Your session expired — reconnect to keep seeing these events."
        case .accessDenied:
            "Calendar access is turned off."
        case .network(let detail):
            detail
        case .decoding(let detail):
            "Couldn't read the response: \(detail)"
        }
    }
}

/// The seam every calendar backend plugs into. EventKit, Google, and
/// Microsoft each conform, so `CalendarAggregator` merges them without
/// knowing which is which — adding a fourth provider means adding a
/// conformance, not forking the merge logic.
///
/// Requirements are `async` so both actors (EventKit, whose fetch APIs
/// block) and `@MainActor` types (the OAuth SDKs, which present UI) can
/// conform without contorting.
protocol CalendarSourceProviding: Sendable {
    /// Stable identifier for this pipe: "eventkit", "google", "microsoft".
    nonisolated var sourceID: String { get }
    nonisolated var displayName: String { get }
    var isConnected: Bool { get async }

    /// Events overlapping `[start, end)`. Throws `CalendarSourceError` so the
    /// aggregator can tell "reconnect me" apart from a transient blip.
    func fetchEvents(from start: Date, to end: Date) async throws -> [UnifiedEvent]

    /// Individual calendars this source exposes, for the Manage Calendars
    /// screen. Sources with nothing to toggle return an empty array.
    func availableCalendars() async throws -> [SourceCalendar]
}

extension CalendarSourceProviding {
    func availableCalendars() async throws -> [SourceCalendar] { [] }
}
