import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private let calendarService = CalendarService()

    var accessState: CalendarAccessState = .notDetermined
    var events: [CalendarEvent] = []
    var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let state = await calendarService.accessState()

        switch state {
        case .authorized:
            accessState = .authorized
            events = await calendarService.fetchTodayEvents()
        case .notDetermined:
            accessState = await calendarService.requestAccess()
            if accessState == .authorized {
                events = await calendarService.fetchTodayEvents()
            }
        case .denied:
            accessState = .denied
        }
    }
}
