import Foundation
import SwiftData

/// A calendar provider the user has connected directly through the app
/// (as opposed to one that reaches us via iOS Settings / EventKit).
enum CalendarProvider: String, Sendable, CaseIterable {
    case google
    case microsoft

    var displayName: String {
        switch self {
        case .google: "Google Calendar"
        case .microsoft: "Outlook Calendar"
        }
    }

    /// How events from this provider are tagged and tinted in the UI.
    var eventSource: CalendarSource {
        switch self {
        case .google: .google
        case .microsoft: .outlook
        }
    }
}

/// A direct OAuth connection to Google or Microsoft.
///
/// No tokens live here — GoogleSignIn and MSAL each keep their own
/// Keychain-backed token caches. This row is just the durable record that the
/// connection exists, plus which of that account's calendars the user wants
/// included.
///
/// CloudKit requires every non-optional property to carry a default value, and
/// doesn't support unique constraints — `ConnectedAccountStore` guards against
/// duplicate rows by fetching on `provider` first.
@Model
final class ConnectedAccount {
    var id: String = ""
    var ownerID: String = ""
    /// Stored as the raw string rather than the enum: CloudKit-backed stores
    /// handle plain scalars most predictably, and it keeps the schema readable
    /// in the CloudKit dashboard.
    var providerRawValue: String = CalendarProvider.google.rawValue
    var accountEmail: String = ""
    var connectedDate: Date = Date.distantPast
    var enabledCalendarIDs: [String] = []

    var provider: CalendarProvider {
        get { CalendarProvider(rawValue: providerRawValue) ?? .google }
        set { providerRawValue = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        ownerID: String,
        provider: CalendarProvider,
        accountEmail: String,
        connectedDate: Date = Date(),
        enabledCalendarIDs: [String] = []
    ) {
        self.id = id
        self.ownerID = ownerID
        self.providerRawValue = provider.rawValue
        self.accountEmail = accountEmail
        self.connectedDate = connectedDate
        self.enabledCalendarIDs = enabledCalendarIDs
    }
}
