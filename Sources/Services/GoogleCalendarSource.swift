import Foundation
import GoogleSignIn
import Observation
import UIKit

/// A direct connection to Google Calendar over OAuth, independent of whatever
/// the user has added in iOS Settings.
///
/// GoogleSignIn owns token storage and refresh — it keeps its own
/// Keychain-backed cache, so there's deliberately no token handling here. All
/// this type does is drive the sign-in flow, remember who's connected, and
/// translate Calendar API responses into `UnifiedEvent`s.
@MainActor
@Observable
final class GoogleCalendarSource: ConnectableCalendarSource {
    /// `nonisolated` so the protocol's non-isolated `sourceID` can read it.
    nonisolated static let id = "google"

    /// Read-only access is all CatCal ever needs; asking for more would fail
    /// verification for no benefit.
    nonisolated static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    nonisolated var sourceID: String { Self.id }
    nonisolated var displayName: String { "Google Calendar" }
    nonisolated var provider: CalendarProvider { .google }

    private(set) var accountEmail: String?
    /// Set when the API answers 401 — the token was revoked or expired beyond
    /// refresh, and only a fresh sign-in fixes it.
    private(set) var needsReconnect = false

    /// Calendars the user has switched on. Nil means "all of them", which is
    /// the state right after connecting, before anyone touches the toggles.
    var enabledCalendarIDs: Set<String>?

    private let api: GoogleCalendarAPI

    init(api: GoogleCalendarAPI = GoogleCalendarAPI()) {
        self.api = api
    }

    var isConnected: Bool { accountEmail != nil }

    var isConfigured: Bool { OAuthConfig.isGoogleConfigured }

    // MARK: - Connecting

    /// Re-adopts a session from a previous launch. Safe to call when nobody
    /// has ever signed in — it just leaves the source disconnected.
    func restorePreviousSignIn() async {
        guard isConfigured, GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            adopt(user)
        } catch {
            // A restore that fails means the stored grant is gone. Staying
            // disconnected is the honest state; the user can reconnect.
            accountEmail = nil
        }
    }

    @discardableResult
    func connect() async throws -> String {
        guard isConfigured else { throw CalendarSourceError.notConfigured }

        guard let presenter = Self.topViewController() else {
            throw CalendarSourceError.network("Couldn't find a window to present Google sign-in.")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: [Self.scope]
            )
            adopt(result.user)

            // Consent is per-scope and the user can decline just this one, in
            // which case sign-in still "succeeds" but every read would 403.
            guard result.user.grantedScopes?.contains(Self.scope) == true else {
                GIDSignIn.sharedInstance.signOut()
                accountEmail = nil
                throw CalendarSourceError.scopeDeclined
            }

            return accountEmail ?? ""
        } catch let error as CalendarSourceError {
            throw error
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            throw CalendarSourceError.cancelled
        } catch {
            throw CalendarSourceError.network(error.localizedDescription)
        }
    }

    func disconnect() {
        GIDSignIn.sharedInstance.signOut()
        accountEmail = nil
        needsReconnect = false
        enabledCalendarIDs = nil
    }

    private func adopt(_ user: GIDGoogleUser) {
        accountEmail = user.profile?.email ?? "Google account"
        needsReconnect = false
    }

    // MARK: - Reading

    func availableCalendars() async throws -> [SourceCalendar] {
        let token = try await accessToken()
        do {
            return try await api.calendars(token: token)
        } catch {
            throw handling(error)
        }
    }

    func fetchEvents(from start: Date, to end: Date) async throws -> [UnifiedEvent] {
        guard isConnected else { throw CalendarSourceError.notConnected }

        let token = try await accessToken()

        do {
            let calendars = try await api.calendars(token: token)
            let wanted = calendars.filter { enabledCalendarIDs?.contains($0.id) ?? true }

            // One request per calendar, concurrently — a user with six
            // calendars shouldn't wait six round trips.
            return try await withThrowingTaskGroup(of: [UnifiedEvent].self) { group in
                let api = self.api
                for calendar in wanted {
                    group.addTask {
                        try await api.events(calendarID: calendar.id, token: token, from: start, to: end)
                    }
                }

                var events: [UnifiedEvent] = []
                for try await batch in group {
                    events.append(contentsOf: batch)
                }
                return events
            }
        } catch {
            throw handling(error)
        }
    }

    /// GoogleSignIn refreshes silently when the access token is stale; we only
    /// have to ask for it.
    private func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            accountEmail = nil
            throw CalendarSourceError.notConnected
        }

        do {
            let refreshed = try await user.refreshTokensIfNeeded()
            return refreshed.accessToken.tokenString
        } catch {
            needsReconnect = true
            throw CalendarSourceError.needsReconnect
        }
    }

    /// Records the reconnect state on the way past, so the Calendar Sources
    /// screen can offer a Reconnect button without re-deriving it.
    private func handling(_ error: any Error) -> any Error {
        if case CalendarSourceError.needsReconnect = error {
            needsReconnect = true
        }
        return error
    }

    /// The view controller Google's flow should be presented from. Reaching
    /// into UIKit is unavoidable — `signIn(withPresenting:)` takes a
    /// `UIViewController`, with no SwiftUI equivalent.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

// MARK: - REST

/// The slice of the Google Calendar v3 API CatCal reads. Kept separate from
/// the source so the network shape can be tested and swapped without dragging
/// GoogleSignIn along.
struct GoogleCalendarAPI: Sendable {
    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func calendars(token: String) async throws -> [SourceCalendar] {
        let url = baseURL.appending(path: "users/me/calendarList")
        let response: CalendarListResponse = try await get(url, token: token)

        return response.items.map { item in
            SourceCalendar(
                id: item.id,
                title: item.summaryOverride ?? item.summary ?? item.id,
                accountEmail: item.id.contains("@") ? item.id : nil
            )
        }
    }

    func events(calendarID: String, token: String, from start: Date, to end: Date) async throws -> [UnifiedEvent] {
        var components = URLComponents(
            url: baseURL.appending(path: "calendars/\(calendarID)/events"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: start)),
            URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: end)),
            // Expands recurring series into individual instances, which is
            // what a day view needs.
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "100")
        ]

        guard let url = components?.url else {
            throw CalendarSourceError.network("Couldn't build the Google Calendar request URL.")
        }

        let response: EventListResponse = try await get(url, token: token)

        return response.items.compactMap { item in
            guard item.status != "cancelled",
                  let startDate = item.start?.resolvedDate,
                  let endDate = item.end?.resolvedDate else {
                return nil
            }

            return UnifiedEvent(
                id: "google:\(calendarID):\(item.id)",
                title: item.summary?.isEmpty == false ? item.summary! : "Untitled event",
                startDate: startDate,
                endDate: endDate,
                isAllDay: item.start?.date != nil,
                source: .google,
                calendarID: calendarID
            )
        }
    }

    private func get<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CalendarSourceError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CalendarSourceError.network("Unexpected response from Google Calendar.")
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw CalendarSourceError.needsReconnect
        default:
            throw CalendarSourceError.network("Google Calendar returned \(http.statusCode).")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CalendarSourceError.decoding(error.localizedDescription)
        }
    }

    // MARK: Wire format

    private struct CalendarListResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let summary: String?
            let summaryOverride: String?
        }

        let items: [Item]
    }

    private struct EventListResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let summary: String?
            let status: String?
            let start: EventDate?
            let end: EventDate?
        }

        /// Google sends `date` for all-day events and `dateTime` otherwise;
        /// exactly one is present.
        struct EventDate: Decodable {
            let date: String?
            let dateTime: String?

            var resolvedDate: Date? {
                if let dateTime {
                    return ISO8601DateFormatter.googleDateTime.date(from: dateTime)
                        ?? ISO8601DateFormatter.googleDateTimeWithFractionalSeconds.date(from: dateTime)
                }
                guard let date else { return nil }
                return DateFormatter.googleAllDay.date(from: date)
            }
        }

        let items: [Item]
    }
}

/// `nonisolated(unsafe)` on the shared formatters below: `DateFormatter` and
/// `ISO8601DateFormatter` are documented as thread-safe for concurrent use once
/// configured, and these are configured exactly once here and never mutated.
/// Building a formatter per event would be far more expensive than the parse.
private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let googleDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) static let googleDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    /// All-day dates are calendar days with no zone, so they're parsed in the
    /// device's zone — an all-day event on the 19th should read as the 19th
    /// wherever the user is.
    static let googleAllDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
