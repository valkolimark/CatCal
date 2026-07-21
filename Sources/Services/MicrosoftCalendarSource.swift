import Foundation
import MSAL
import Observation
import UIKit

/// A direct connection to Outlook / Microsoft 365 calendars over OAuth,
/// independent of whatever the user has added in iOS Settings.
///
/// Deliberately shaped like `GoogleCalendarSource` — same protocol, same
/// connect/restore/disconnect lifecycle — so the Calendar Sources screen
/// renders one row type for both and the two providers feel like one system.
///
/// MSAL owns the token cache (Keychain-backed) and silent refresh; there's no
/// token handling here beyond asking for one.
@MainActor
@Observable
final class MicrosoftCalendarSource: ConnectableCalendarSource {
    nonisolated static let id = "microsoft"

    /// Delegated read-only calendar access. `Calendars.Read` needs no admin
    /// consent for personal use.
    nonisolated static let scopes = ["Calendars.Read"]

    nonisolated var sourceID: String { Self.id }
    nonisolated var displayName: String { "Outlook Calendar" }
    nonisolated var provider: CalendarProvider { .microsoft }

    private(set) var accountEmail: String?
    private(set) var needsReconnect = false

    /// Calendars the user has switched on. Nil means "all of them".
    var enabledCalendarIDs: Set<String>?

    private let api: MicrosoftGraphAPI
    /// Built lazily: constructing it with a placeholder client ID throws, and
    /// an unconfigured build should show a message rather than crash.
    private var application: MSALPublicClientApplication?
    private var account: MSALAccount?

    init(api: MicrosoftGraphAPI = MicrosoftGraphAPI()) {
        self.api = api
    }

    var isConnected: Bool { accountEmail != nil }

    var isConfigured: Bool { OAuthConfig.isMicrosoftConfigured }

    // MARK: - Connecting

    /// Picks up the account MSAL cached on a previous launch. No UI, no
    /// network round trip beyond a silent token refresh when one is needed.
    func restorePreviousSignIn() async {
        guard isConfigured, let application = try? clientApplication() else { return }

        guard let cached = try? application.allAccounts().first else { return }
        account = cached
        accountEmail = cached.username ?? "Microsoft account"
        needsReconnect = false
    }

    @discardableResult
    func connect() async throws -> String {
        guard isConfigured else { throw CalendarSourceError.notConfigured }

        let application = try clientApplication()

        guard let presenter = PresentationAnchor.topViewController() else {
            throw CalendarSourceError.network("Couldn't find a window to present Microsoft sign-in.")
        }

        let webParameters = MSALWebviewParameters(authPresentationViewController: presenter)
        let parameters = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webParameters)
        parameters.promptType = .selectAccount

        let result = try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: parameters) { result, error in
                continuation.resume(with: Self.outcome(result: result, error: error))
            }
        }

        account = result.account
        accountEmail = result.username
        needsReconnect = false
        return result.username
    }

    func disconnect() {
        if let application = try? clientApplication(), let account {
            // Clears MSAL's cached tokens for this account. Signing out of
            // the Microsoft session itself is the user's business, not ours.
            try? application.remove(account)
        }
        account = nil
        accountEmail = nil
        needsReconnect = false
        enabledCalendarIDs = nil
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
            // `calendarView` returns the union across the user's calendars in
            // one request — unlike Google, there's no need to fan out per
            // calendar, so the per-calendar filter is applied afterwards.
            let events = try await api.calendarViewEvents(token: token, from: start, to: end)

            guard let enabledCalendarIDs else { return events }
            return events.filter { enabledCalendarIDs.contains($0.calendarID) || $0.calendarID.isEmpty }
        } catch {
            throw handling(error)
        }
    }

    /// MSAL refreshes silently when it can; only a genuinely dead grant needs
    /// the user back.
    private func accessToken() async throws -> String {
        guard let application = try? clientApplication(), let account else {
            throw CalendarSourceError.notConnected
        }

        let parameters = MSALSilentTokenParameters(scopes: Self.scopes, account: account)

        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                application.acquireTokenSilent(with: parameters) { result, error in
                    continuation.resume(with: Self.outcome(result: result, error: error))
                }
            }
            return result.accessToken
        } catch {
            needsReconnect = true
            throw CalendarSourceError.needsReconnect
        }
    }

    private func clientApplication() throws -> MSALPublicClientApplication {
        if let application { return application }

        guard let authorityURL = URL(string: OAuthConfig.microsoftAuthority),
              let authority = try? MSALAADAuthority(url: authorityURL) else {
            throw CalendarSourceError.notConfigured
        }

        let configuration = MSALPublicClientApplicationConfig(
            clientId: OAuthConfig.microsoftClientID,
            redirectUri: OAuthConfig.microsoftRedirectURI,
            authority: authority
        )

        do {
            let created = try MSALPublicClientApplication(configuration: configuration)
            application = created
            return created
        } catch {
            throw CalendarSourceError.notConfigured
        }
    }

    private func handling(_ error: any Error) -> any Error {
        if case CalendarSourceError.needsReconnect = error {
            needsReconnect = true
        }
        return error
    }

    /// Collapses MSAL's `(result, error)` callback pair into a `Result` of a
    /// `Sendable` value — `MSALResult` itself isn't `Sendable`, so only the
    /// fields we need cross the continuation.
    private nonisolated static func outcome(
        result: MSALResult?,
        error: (any Error)?
    ) -> Result<TokenOutcome, any Error> {
        if let error {
            let nsError = error as NSError
            if nsError.domain == MSALErrorDomain, nsError.code == MSALError.userCanceled.rawValue {
                return .failure(CalendarSourceError.cancelled)
            }
            return .failure(CalendarSourceError.network(error.localizedDescription))
        }

        guard let result else {
            return .failure(CalendarSourceError.network("Microsoft returned neither a token nor an error."))
        }

        return .success(
            TokenOutcome(
                accessToken: result.accessToken,
                username: result.account.username ?? "Microsoft account",
                account: result.account
            )
        )
    }

    private struct TokenOutcome: @unchecked Sendable {
        let accessToken: String
        let username: String
        /// `@unchecked Sendable` covers this: `MSALAccount` is an immutable
        /// value holder in practice, and it only ever travels from MSAL's
        /// callback back to this main-actor type.
        let account: MSALAccount
    }
}

// MARK: - Graph

/// The slice of Microsoft Graph v1.0 CatCal reads.
struct MicrosoftGraphAPI: Sendable {
    private let baseURL = URL(string: "https://graph.microsoft.com/v1.0")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func calendars(token: String) async throws -> [SourceCalendar] {
        let url = baseURL.appending(path: "me/calendars")
        let response: CalendarsResponse = try await get(url, token: token)

        return response.value.map { item in
            SourceCalendar(
                id: item.id,
                title: item.name ?? "Calendar",
                accountEmail: item.owner?.address
            )
        }
    }

    func calendarViewEvents(token: String, from start: Date, to end: Date) async throws -> [UnifiedEvent] {
        var components = URLComponents(
            url: baseURL.appending(path: "me/calendarView"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "startDateTime", value: ISO8601DateFormatter().string(from: start)),
            URLQueryItem(name: "endDateTime", value: ISO8601DateFormatter().string(from: end)),
            URLQueryItem(name: "$select", value: "id,subject,start,end,isAllDay,isCancelled"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$top", value: "100")
        ]

        guard let url = components?.url else {
            throw CalendarSourceError.network("Couldn't build the Microsoft Graph request URL.")
        }

        let response: EventsResponse = try await get(url, token: token)

        return response.value.compactMap { item in
            guard item.isCancelled != true,
                  let startDate = item.start?.resolvedDate,
                  let endDate = item.end?.resolvedDate else {
                return nil
            }

            return UnifiedEvent(
                id: "microsoft:\(item.id)",
                title: item.subject?.isEmpty == false ? item.subject! : "Untitled event",
                startDate: startDate,
                endDate: endDate,
                isAllDay: item.isAllDay ?? false,
                source: .outlook,
                // `calendarView` doesn't return the owning calendar per event
                // without an extra expand; an empty value means "unfiltered",
                // which the source treats as always-included.
                calendarID: ""
            )
        }
    }

    private func get<T: Decodable>(_ url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Without this Graph answers in the user's mailbox time zone, which
        // makes the already zone-less `dateTime` strings ambiguous.
        request.setValue("outlook.timezone=\"UTC\"", forHTTPHeaderField: "Prefer")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CalendarSourceError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CalendarSourceError.network("Unexpected response from Microsoft Graph.")
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw CalendarSourceError.needsReconnect
        default:
            throw CalendarSourceError.network("Microsoft Graph returned \(http.statusCode).")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CalendarSourceError.decoding(error.localizedDescription)
        }
    }

    // MARK: Wire format

    private struct CalendarsResponse: Decodable {
        struct Owner: Decodable {
            let address: String?
        }

        struct Item: Decodable {
            let id: String
            let name: String?
            let owner: Owner?
        }

        let value: [Item]
    }

    private struct EventsResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let subject: String?
            let isAllDay: Bool?
            let isCancelled: Bool?
            let start: GraphDateTime?
            let end: GraphDateTime?
        }

        /// Graph sends a zone-less local time plus a separate `timeZone`
        /// name, rather than an offset — so the two have to be recombined.
        struct GraphDateTime: Decodable {
            let dateTime: String?
            let timeZone: String?

            var resolvedDate: Date? {
                ProviderDateParsing.graphDate(dateTime: dateTime, timeZone: timeZone)
            }
        }

        let value: [Item]
    }
}
