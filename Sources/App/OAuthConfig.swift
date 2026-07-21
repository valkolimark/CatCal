import Foundation

/// The OAuth client IDs for the direct Google and Microsoft calendar
/// connections, read from `Info.plist` (see `project.yml`).
///
/// Neither value is a secret — public client IDs are designed to be shipped
/// inside the app binary, and both are safe to commit.
///
/// Until the placeholders are replaced with real values from the Google Cloud
/// Console and the Azure Portal, `isConfigured` is false and the connect rows
/// say so instead of starting a sign-in that can only fail. See the README
/// for the console steps.
enum OAuthConfig {
    /// Substring shared by every unreplaced placeholder value.
    private static let placeholderMarker = "YOUR_"

    static let googleClientID = infoValue(for: "GIDClientID")

    /// Azure Application (client) ID. Registered by hand rather than through
    /// Info.plist convention, since MSAL takes it as a constructor argument.
    static let microsoftClientID = infoValue(for: "MSALClientID")

    static var isGoogleConfigured: Bool { isReal(googleClientID) }
    static var isMicrosoftConfigured: Bool { isReal(microsoftClientID) }

    /// MSAL derives this from the bundle ID; it has to match the redirect URI
    /// Azure generated for the iOS platform registration.
    static var microsoftRedirectURI: String {
        "msauth.\(Bundle.main.bundleIdentifier ?? "com.valkolimark.catcal")://auth"
    }

    /// Supports both work/school and personal Microsoft accounts.
    static let microsoftAuthority = "https://login.microsoftonline.com/common"

    private static func infoValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    private static func isReal(_ value: String) -> Bool {
        !value.isEmpty && !value.contains(placeholderMarker)
    }
}
