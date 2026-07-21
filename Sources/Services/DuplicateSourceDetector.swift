import Foundation

/// One account EventKit surfaces — an iCloud account, a Google account added
/// in iOS Settings, an Exchange mailbox — and the calendars under it.
struct EventKitAccount: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    /// How events from this account are tagged in the UI.
    let kind: CalendarSource
    let calendars: [SourceCalendar]
}

/// Spots the case where the same account reaches CatCal twice: once through
/// iOS Settings via EventKit, and again through a direct OAuth connection.
/// Left unflagged, the user just sees every event listed twice and assumes
/// the app is broken.
///
/// EventKit gives us the account *title*, not a guaranteed email address —
/// depending on how the account was added it might be the full address
/// ("mark@gmail.com"), a service name ("Gmail", "Google"), or something the
/// user typed. So this matches conservatively across the plausible shapes and
/// only ever produces a note the user can dismiss by ignoring it, never an
/// automatic change.
enum DuplicateSourceDetector {
    static func account(
        matching email: String,
        in accounts: [EventKitAccount],
        provider: CalendarProvider
    ) -> EventKitAccount? {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return nil }

        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        let domain = email.split(separator: "@").dropFirst().first.map(String.init)

        // Exact and containment matches on the full address are the strong
        // signals — check those across every account before falling back.
        if let exact = accounts.first(where: { $0.title.lowercased() == email }) {
            return exact
        }
        if let contained = accounts.first(where: { $0.title.lowercased().contains(email) }) {
            return contained
        }

        // Weaker: the account is tagged as the same provider *and* its title
        // looks related. Requiring both keeps a generic "Gmail" account from
        // matching an unrelated Google address.
        return accounts.first { account in
            guard account.kind == provider.eventSource else { return false }

            let title = account.title.lowercased()
            if title.contains(localPart), localPart.count >= 3 { return true }
            if let domain, title.contains(domain) { return true }
            return false
        }
    }
}
