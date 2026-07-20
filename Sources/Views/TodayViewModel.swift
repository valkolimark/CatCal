import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private let calendarService = CalendarService()

    var accessState: CalendarAccessState = .notDetermined
    var events: [CalendarEvent] = []
    var connectedSources: Set<CalendarSource> = []
    var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let state = await calendarService.accessState()

        switch state {
        case .authorized:
            accessState = .authorized
            await loadEventsAndSources()
        case .notDetermined:
            accessState = await calendarService.requestAccess()
            if accessState == .authorized {
                await loadEventsAndSources()
            }
        case .denied:
            accessState = .denied
        }
    }

    private func loadEventsAndSources() async {
        events = await calendarService.fetchTodayEvents()
        connectedSources = await calendarService.connectedSources()
    }
}
