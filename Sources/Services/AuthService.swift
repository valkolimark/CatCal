import Foundation

protocol AuthServiceProtocol {
    var currentUserID: String { get }
}

/// Stands in for a signed-in user until Cycle 9 wires up Sign in with Apple.
/// The UUID is fixed so local and CloudKit-synced records keep a stable
/// `ownerID` across launches during development.
struct MockAuthService: AuthServiceProtocol {
    let currentUserID: String = "8F14E45F-CEEA-467F-B32C-1B0EAA4C2AA1"
}

/// Every model's `ownerID` should be sourced from `CurrentUser.id`. Swapping
/// `CurrentUser.service` for a real implementation later needs no changes
/// to models or the views that create records.
///
/// `nonisolated(unsafe)`: this is a DI swap point set once at app launch
/// (and in test setup), never mutated concurrently — Swift 6 can't prove
/// that, so we assert it ourselves rather than force every caller onto
/// the main actor.
enum CurrentUser {
    nonisolated(unsafe) static var service: AuthServiceProtocol = MockAuthService()
    static var id: String { service.currentUserID }
}
