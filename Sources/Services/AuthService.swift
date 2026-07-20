import Foundation

protocol AuthServiceProtocol {
    var currentUserID: String { get }
}

/// Pre-auth stand-in, still used by SwiftUI previews and tests. The UUID is
/// fixed so records created before the user ever signs in share one stable
/// `ownerID` — `SessionController` migrates those records onto the real
/// Apple identifier the first time someone signs in.
struct MockAuthService: AuthServiceProtocol {
    static let mockUserID = "8F14E45F-CEEA-467F-B32C-1B0EAA4C2AA1"
    let currentUserID: String = mockUserID
}

/// Backed by the stable user identifier Apple hands back from Sign in with
/// Apple, persisted in the Keychain.
struct AppleAuthService: AuthServiceProtocol {
    let currentUserID: String
}

/// Every model's `ownerID` is sourced from `CurrentUser.id`, so swapping the
/// backing service is all it takes to move from the mock user to a real
/// signed-in one — no model or view changes required.
///
/// `nonisolated(unsafe)`: this is a DI swap point set at app launch and on
/// sign-in/sign-out, never mutated concurrently — Swift 6 can't prove that,
/// so we assert it ourselves rather than force every caller onto the main
/// actor.
enum CurrentUser {
    nonisolated(unsafe) static var service: AuthServiceProtocol = MockAuthService()
    static var id: String { service.currentUserID }
}
