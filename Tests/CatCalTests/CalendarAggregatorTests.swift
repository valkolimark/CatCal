import Foundation
import Testing
@testable import CatCal

/// Stand-in for a real provider: returns a fixed set of events, or throws a
/// fixed error, so the aggregator's merge and partial-failure behavior can be
/// exercised without EventKit or the network.
private struct StubCalendarSource: CalendarSourceProviding {
    let sourceID: String
    let displayName: String
    let connected: Bool
    let events: [UnifiedEvent]
    let error: (any Error)?

    init(
        sourceID: String,
        displayName: String? = nil,
        connected: Bool = true,
        events: [UnifiedEvent] = [],
        error: (any Error)? = nil
    ) {
        self.sourceID = sourceID
        self.displayName = displayName ?? sourceID.capitalized
        self.connected = connected
        self.events = events
        self.error = error
    }

    var isConnected: Bool { connected }

    func fetchEvents(from start: Date, to end: Date) async throws -> [UnifiedEvent] {
        if let error { throw error }
        return events
    }
}

private func makeEvent(
    id: String,
    title: String = "Event",
    minutesFromMidnight: Int,
    source: CalendarSource = .iCloud
) -> UnifiedEvent {
    let midnight = Date(timeIntervalSince1970: 1_700_000_000)
    let start = midnight.addingTimeInterval(TimeInterval(minutesFromMidnight * 60))
    return UnifiedEvent(
        id: id,
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(1800),
        isAllDay: false,
        source: source,
        calendarID: "cal-\(source.rawValue)"
    )
}

private let windowStart = Date(timeIntervalSince1970: 1_700_000_000)
private let windowEnd = windowStart.addingTimeInterval(86_400)

@MainActor
@Suite("CalendarAggregator")
struct CalendarAggregatorTests {
    @Test("Merges events from every connected source into one time-sorted list")
    func mergesAndSorts() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "google", events: [
                makeEvent(id: "g1", title: "Standup", minutesFromMidnight: 540, source: .google),
                makeEvent(id: "g2", title: "Client review", minutesFromMidnight: 660, source: .google)
            ]),
            StubCalendarSource(sourceID: "eventkit", events: [
                makeEvent(id: "e1", title: "Dentist", minutesFromMidnight: 900),
                makeEvent(id: "e2", title: "Gym", minutesFromMidnight: 420)
            ])
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.failures.isEmpty)
        #expect(result.events.map(\.id) == ["e2", "g1", "g2", "e1"])
    }

    @Test("Sorts same-start events by title so the order stays stable")
    func stableOrderForTiedStarts() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "b", events: [makeEvent(id: "b1", title: "Zebra", minutesFromMidnight: 600)]),
            StubCalendarSource(sourceID: "a", events: [makeEvent(id: "a1", title: "Apple", minutesFromMidnight: 600)])
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.map(\.title) == ["Apple", "Zebra"])
    }

    @Test("One failing source doesn't blank out the others")
    func partialFailureKeepsGoodSources() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(
                sourceID: "google",
                displayName: "Google Calendar",
                error: CalendarSourceError.network("Offline")
            ),
            StubCalendarSource(sourceID: "eventkit", events: [
                makeEvent(id: "e1", title: "Dentist", minutesFromMidnight: 900)
            ])
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.map(\.id) == ["e1"])
        #expect(result.failures.count == 1)
        #expect(result.failures.first?.sourceID == "google")
        #expect(result.failures.first?.displayName == "Google Calendar")
        #expect(result.failures.first?.message == "Offline")
        #expect(result.failures.first?.needsReconnect == false)
    }

    @Test("A 401 from a provider is reported as needing reconnection")
    func expiredTokenAsksForReconnect() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "microsoft", error: CalendarSourceError.needsReconnect)
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.failures.first?.needsReconnect == true)
    }

    @Test("Disconnected sources are skipped silently rather than reported as errors")
    func disconnectedSourcesAreSkipped() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "google", connected: false, events: [
                makeEvent(id: "g1", minutesFromMidnight: 540, source: .google)
            ]),
            StubCalendarSource(sourceID: "eventkit", events: [makeEvent(id: "e1", minutesFromMidnight: 600)])
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.map(\.id) == ["e1"])
        #expect(result.failures.isEmpty)
    }

    @Test("Every source failing yields no events and every failure")
    func allSourcesFailing() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "google", error: CalendarSourceError.network("Offline")),
            StubCalendarSource(sourceID: "microsoft", error: CalendarSourceError.needsReconnect)
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.isEmpty)
        // Registration order, not completion order.
        #expect(result.failures.map(\.sourceID) == ["google", "microsoft"])
    }

    @Test("The same event arriving from two sources is only listed once")
    func deduplicatesByID() async {
        let shared = makeEvent(id: "dupe", title: "Standup", minutesFromMidnight: 540, source: .google)
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "eventkit", events: [shared]),
            StubCalendarSource(sourceID: "google", events: [shared])
        ])

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.count == 1)
    }

    @Test("Registering a source twice replaces it instead of duplicating it")
    func registerReplacesBySourceID() async {
        let aggregator = CalendarAggregator(sources: [StubCalendarSource(sourceID: "google", events: [])])
        aggregator.register(
            StubCalendarSource(sourceID: "google", events: [makeEvent(id: "g1", minutesFromMidnight: 540, source: .google)])
        )

        #expect(aggregator.sources.count == 1)

        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)
        #expect(result.events.map(\.id) == ["g1"])
    }

    @Test("Removing a source drops its events from the merge")
    func removeSource() async {
        let aggregator = CalendarAggregator(sources: [
            StubCalendarSource(sourceID: "google", events: [makeEvent(id: "g1", minutesFromMidnight: 540, source: .google)]),
            StubCalendarSource(sourceID: "eventkit", events: [makeEvent(id: "e1", minutesFromMidnight: 600)])
        ])

        aggregator.remove(sourceID: "google")
        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result.events.map(\.id) == ["e1"])
    }

    @Test("No sources registered yields an empty result rather than an error")
    func noSources() async {
        let aggregator = CalendarAggregator()
        let result = await aggregator.fetchEvents(from: windowStart, to: windowEnd)

        #expect(result == AggregatedCalendarResult())
    }
}
