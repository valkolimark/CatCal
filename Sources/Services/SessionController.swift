import AuthenticationServices
import Observation
import SwiftData

@MainActor
@Observable
final class SessionController {
    enum State {
        /// Still checking the Keychain / credential state at launch.
        case restoring
        case signedOut
        case signedIn(userID: String)
    }

    private(set) var state: State = .restoring
    private(set) var errorMessage: String?

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    // MARK: - Launch

    /// Restores a previous session from the Keychain, re-checking with Apple
    /// that the credential is still valid — the user can revoke it from
    /// Settings at any time, in which case we fall back to signed out.
    func restore() async {
        guard let storedID = Keychain.get(.appleUserID) else {
            state = .signedOut
            return
        }

        let credentialState = try? await ASAuthorizationAppleIDProvider()
            .credentialState(forUserID: storedID)

        switch credentialState {
        case .authorized:
            adoptSignedIn(userID: storedID)
        case .revoked, .notFound, .none:
            Keychain.remove(.appleUserID)
            state = .signedOut
        case .transferred:
            // The app moved to a different developer team. Nothing sensible
            // to do for v1 beyond signing out and letting them sign in again.
            Keychain.remove(.appleUserID)
            state = .signedOut
        @unknown default:
            state = .signedOut
        }
    }

    // MARK: - Sign in

    func handleSignInResult(_ result: Result<ASAuthorization, any Error>, context: ModelContext) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type from Apple."
                return
            }
            completeSignIn(userID: credential.user, context: context)

        case .failure(let error):
            // The user tapping Cancel surfaces here too; that isn't an error
            // worth showing them.
            if (error as? ASAuthorizationError)?.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = "Couldn't sign in with Apple. Please try again."
            }
        }
    }

    private func completeSignIn(userID: String, context: ModelContext) {
        errorMessage = nil
        Keychain.set(userID, for: .appleUserID)
        migrateMockDataIfNeeded(to: userID, context: context)
        adoptSignedIn(userID: userID)
    }

    private func adoptSignedIn(userID: String) {
        CurrentUser.service = AppleAuthService(currentUserID: userID)
        state = .signedIn(userID: userID)
    }

    // MARK: - Sign out

    /// Clears the session but deliberately leaves local records in place, so
    /// signing back in with the same Apple ID picks up where the user left
    /// off (and CloudKit rehydrates anything created on another device).
    func signOut() {
        Keychain.remove(.appleUserID)
        CurrentUser.service = MockAuthService()
        state = .signedOut
    }

    // MARK: - Migration

    /// Re-homes anything created before the user ever signed in — records
    /// stamped with the mock `ownerID` — onto their real Apple identifier.
    /// Scoped to the mock ID specifically so a second Apple ID signing in on
    /// a shared device can never absorb the first user's data.
    // Internal rather than private so tests can exercise it directly.
    @discardableResult
    func migrateMockDataIfNeeded(to realUserID: String, context: ModelContext) -> Int {
        let mockID = MockAuthService.mockUserID
        guard realUserID != mockID else { return 0 }

        var migrated = 0

        func reassign<T: PersistentModel>(_ type: T.Type, ownerID: ReferenceWritableKeyPath<T, String>) {
            let descriptor = FetchDescriptor<T>()
            guard let records = try? context.fetch(descriptor) else { return }
            for record in records where record[keyPath: ownerID] == mockID {
                record[keyPath: ownerID] = realUserID
                migrated += 1
            }
        }

        reassign(AppTask.self, ownerID: \.ownerID)
        reassign(UserProgress.self, ownerID: \.ownerID)
        reassign(Achievement.self, ownerID: \.ownerID)
        reassign(Cosmetic.self, ownerID: \.ownerID)

        if migrated > 0 {
            try? context.save()
        }
        return migrated
    }
}
