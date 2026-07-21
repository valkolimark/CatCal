import UIKit

/// Finds the view controller an OAuth sheet should be presented from.
///
/// Both GoogleSignIn and MSAL take a `UIViewController` to present over, with
/// no SwiftUI equivalent, so this bit of UIKit reach-through is unavoidable.
/// Shared rather than duplicated per provider.
@MainActor
enum PresentationAnchor {
    static func topViewController() -> UIViewController? {
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
