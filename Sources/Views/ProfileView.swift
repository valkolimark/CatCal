import SwiftUI

/// Minimal placeholder — Cycle 9 replaces the sign-out stub with real
/// Sign in with Apple session management.
struct ProfileView: View {
    @State private var isShowingSignOutStub = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            CatCalColor.appBackground.ignoresSafeArea()

            List {
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(CatCalColor.textSecondary)
                    }
                }
                .listRowBackground(CatCalColor.surface)

                Section {
                    Button(role: .destructive) {
                        isShowingSignOutStub = true
                    } label: {
                        Text("Sign Out")
                    }
                }
                .listRowBackground(CatCalColor.surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Profile")
        .alert("Not available yet", isPresented: $isShowingSignOutStub) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign-in isn't wired up yet, so there's nothing to sign out of.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
