import Foundation
import Observation

/// One source's fetch going wrong, surfaced to the UI as an inline banner
/// rather than swallowing it or blanking the whole day.
struct CalendarSourceFailure: Identifiable, Sendable, Equatable {
    let sourceID: String
    let displayName: String
    let message: String
    /// True when the fix is "sign in again" rather than "try later" — the UI
    /// offers a Reconnect button for these.
    let needsReconnect: Bool

    var id: String { sourceID }
}

struct AggregatedCalendarResult: Sendable, Equatable {
    var events: [UnifiedEvent] = []
    var failures: [CalendarSourceFailure] = []
}

/// Fans a single date range out across every connected source concurrently
/// and merges the answers into one time-sorted list.
///
/// The contract that matters: one bad source never blanks the view. A source
/// that throws contributes a `CalendarSourceFailure` and drops out of the
/// merge; every other source's events still land.
@MainActor
@Observable
final class CalendarAggregator {
    private(set) var sources: [any CalendarSourceProviding]

    init(sources: [any CalendarSourceProviding] = []) {
        self.sources = sources
    }

    // MARK: - Source registry

    /// Adds a source, replacing any existing one with the same `sourceID`
    /// (reconnecting Google shouldn't leave two Google sources registered).
    func register(_ source: any CalendarSourceProviding) {
        if let index = sources.firstIndex(where: { $0.sourceID == source.sourceID }) {
            sources[index] = source
        } else {
            sources.append(source)
        }
    }

    func remove(sourceID: String) {
        sources.removeAll { $0.sourceID == sourceID }
    }

    func source(withID sourceID: String) -> (any CalendarSourceProviding)? {
        sources.first { $0.sourceID == sourceID }
    }

    func source<T: CalendarSourceProviding>(as type: T.Type) -> T? {
        sources.compactMap { $0 as? T }.first
    }

    // MARK: - Fetching

    /// Every event in `[start, end)` across all connected sources, merged and
    /// time-sorted, plus whatever went wrong along the way.
    ///
    /// Uses `withTaskGroup` rather than `withThrowingTaskGroup` on purpose:
    /// a throwing group cancels its siblings on the first error, which is the
    /// opposite of what partial-failure tolerance needs here. Each child task
    /// converts its own throw into an `.failure` outcome instead.
    func fetchEvents(from start: Date, to end: Date) async -> AggregatedCalendarResult {
        let candidates = sources

        let outcomes = await withTaskGroup(of: (offset: Int, outcome: SourceOutcome).self) { group in
            for (offset, source) in candidates.enumerated() {
                group.addTask {
                    (offset, await Self.fetch(from: source, start: start, end: end))
                }
            }

            var collected: [(offset: Int, outcome: SourceOutcome)] = []
            for await result in group {
                collected.append(result)
            }
            // Restore registration order so the UI doesn't reshuffle failure
            // banners between refreshes just because a source was slower.
            return collected.sorted { $0.offset < $1.offset }.map(\.outcome)
        }

        var result = AggregatedCalendarResult()
        for outcome in outcomes {
            switch outcome {
            case .skipped:
                continue
            case .events(let events):
                result.events.append(contentsOf: events)
            case .failure(let failure):
                result.failures.append(failure)
            }
        }

        result.events = Self.merge(result.events)
        return result
    }

    /// Deduplicates and time-sorts. Sorting by title and id after the start
    /// date keeps the order stable across refreshes when several events share
    /// a start time.
    static func merge(_ events: [UnifiedEvent]) -> [UnifiedEvent] {
        var seen = Set<String>()
        let unique = events.filter { seen.insert($0.id).inserted }

        return unique.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }

    private enum SourceOutcome: Sendable {
        /// Not connected — normal, not worth reporting to the user.
        case skipped
        case events([UnifiedEvent])
        case failure(CalendarSourceFailure)
    }

    private static func fetch(
        from source: any CalendarSourceProviding,
        start: Date,
        end: Date
    ) async -> SourceOutcome {
        guard await source.isConnected else { return .skipped }

        do {
            return .events(try await source.fetchEvents(from: start, to: end))
        } catch CalendarSourceError.notConnected {
            return .skipped
        } catch {
            let sourceError = error as? CalendarSourceError
            return .failure(
                CalendarSourceFailure(
                    sourceID: source.sourceID,
                    displayName: source.displayName,
                    message: sourceError?.errorDescription
                        ?? "Couldn't load events from \(source.displayName).",
                    needsReconnect: sourceError == .needsReconnect
                )
            )
        }
    }
}
