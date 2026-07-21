import AuthenticationServices
import SwiftData
import SwiftUI

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext

    let session: SessionController

    var body: some View {
        ZStack {
            CatCalBackground()

            VStack(spacing: CatCalSpacing.lg) {
                Spacer()

                CatBuddyImage(height: 200)

                VStack(spacing: CatCalSpacing.xs) {
                    Text("Welcome back")
                        .font(CatCalFont.largeTitle(34))
                        .foregroundStyle(CatCalColor.textPrimary)

                    Text("Sign in to keep your streak going.")
                        .font(CatCalFont.body(17))
                        .foregroundStyle(CatCalColor.textSecondary)
                }

                Spacer()

                VStack(spacing: CatCalSpacing.sm + 2) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        session.handleSignInResult(result, context: modelContext)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(Capsule())

                    ComingSoonButton(title: "Continue with Google", systemImage: "globe")
                    ComingSoonButton(title: "Continue with email", systemImage: "envelope.fill")
                }

                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(CatCalFont.caption(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CatCalSpacing.md)
                        .padding(.vertical, CatCalSpacing.sm)
                        .background(CatCalColor.danger.opacity(0.92), in: Capsule())
                }

                Text("More sign-in options are coming soon.")
                    .font(CatCalFont.caption(12))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .padding(.bottom, CatCalSpacing.lg)
            }
            .padding(.horizontal, CatCalSpacing.xl)
        }
    }
}

/// Shown for the moment it takes to read the Keychain and re-check the
/// stored credential with Apple, so the app doesn't flash the sign-in
/// screen at an already-signed-in user on every launch.
struct RestoringSessionView: View {
    var body: some View {
        ZStack {
            CatCalBackground()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(CatCalColor.brandPrimary.opacity(0.6))
        }
    }
}

/// Visible but inert, so the sign-in screen reads as the finished design
/// while only Apple is actually wired up.
private struct ComingSoonButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Button {
            // Intentionally empty — disabled below.
        } label: {
            HStack(spacing: CatCalSpacing.sm) {
                Image(systemName: systemImage)
                Text(title)
                    .font(CatCalFont.headline())
            }
            .foregroundStyle(CatCalColor.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .catCalGlassCard(cornerRadius: CatCalRadius.pill)
        }
        .disabled(true)
        .opacity(0.75)
        .accessibilityHint("Coming soon")
    }
}

#Preview {
    SignInView(session: SessionController())
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
