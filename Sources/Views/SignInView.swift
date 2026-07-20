import AuthenticationServices
import SwiftData
import SwiftUI

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let session: SessionController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CatCalColor.brandPrimary, CatCalColor.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: CatCalSpacing.lg) {
                Spacer()

                pawLogo

                VStack(spacing: CatCalSpacing.xs) {
                    Text("Welcome back")
                        .font(CatCalFont.title(30))
                        .foregroundStyle(.white)

                    Text("Sign in to keep your streak going.")
                        .font(CatCalFont.body())
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                VStack(spacing: CatCalSpacing.sm) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        session.handleSignInResult(result, context: modelContext)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(Capsule())

                    ComingSoonButton(title: "Continue with Google", systemImage: "globe")
                    ComingSoonButton(title: "Continue with email", systemImage: "envelope.fill")
                }

                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(CatCalFont.caption())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CatCalSpacing.md)
                        .padding(.vertical, CatCalSpacing.sm)
                        .background(CatCalColor.danger.opacity(0.9), in: Capsule())
                }

                Text("More sign-in options are coming soon.")
                    .font(CatCalFont.caption(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, CatCalSpacing.lg)
            }
            .padding(.horizontal, CatCalSpacing.xl)
        }
    }

    private var pawLogo: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 120, height: 120)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
        }
    }
}

/// Shown for the moment it takes to read the Keychain and re-check the
/// stored credential with Apple, so the app doesn't flash the sign-in
/// screen at an already-signed-in user on every launch.
struct RestoringSessionView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CatCalColor.brandPrimary, CatCalColor.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Image(systemName: "pawprint.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
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
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .disabled(true)
        .accessibilityHint("Coming soon")
    }
}

#Preview {
    SignInView(session: SessionController())
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self], inMemory: true)
}
