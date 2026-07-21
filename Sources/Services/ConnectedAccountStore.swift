import Foundation
import SwiftData

/// Reads and writes `ConnectedAccount` rows for the signed-in user.
///
/// Keeps the "one row per provider" invariant in one place, since a
/// CloudKit-backed store can't express it as a unique constraint.
@MainActor
enum ConnectedAccountStore {
    static func account(for provider: CalendarProvider, context: ModelContext) -> ConnectedAccount? {
        let ownerID = CurrentUser.id
        let rawValue = provider.rawValue
        let descriptor = FetchDescriptor<ConnectedAccount>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.providerRawValue == rawValue }
        )
        return try? context.fetch(descriptor).first
    }

    static func allAccounts(context: ModelContext) -> [ConnectedAccount] {
        let ownerID = CurrentUser.id
        let descriptor = FetchDescriptor<ConnectedAccount>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.connectedDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Records a fresh connection, updating the existing row for this provider
    /// rather than adding a second one.
    @discardableResult
    static func upsert(
        provider: CalendarProvider,
        accountEmail: String,
        enabledCalendarIDs: [String]? = nil,
        context: ModelContext
    ) -> ConnectedAccount {
        if let existing = account(for: provider, context: context) {
            existing.accountEmail = accountEmail
            existing.connectedDate = Date()
            if let enabledCalendarIDs {
                existing.enabledCalendarIDs = enabledCalendarIDs
            }
            try? context.save()
            return existing
        }

        let account = ConnectedAccount(
            ownerID: CurrentUser.id,
            provider: provider,
            accountEmail: accountEmail,
            enabledCalendarIDs: enabledCalendarIDs ?? []
        )
        context.insert(account)
        try? context.save()
        return account
    }

    static func remove(provider: CalendarProvider, context: ModelContext) {
        guard let account = account(for: provider, context: context) else { return }
        context.delete(account)
        try? context.save()
    }

    static func setCalendar(_ calendarID: String, enabled: Bool, for provider: CalendarProvider, context: ModelContext) {
        guard let account = account(for: provider, context: context) else { return }
        var enabledIDs = Set(account.enabledCalendarIDs)
        if enabled {
            enabledIDs.insert(calendarID)
        } else {
            enabledIDs.remove(calendarID)
        }
        account.enabledCalendarIDs = enabledIDs.sorted()
        try? context.save()
    }
}
