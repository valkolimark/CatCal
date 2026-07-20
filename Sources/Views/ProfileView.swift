import SwiftUI

struct ProfileView: View {
    let session: SessionController

    @State private var isConfirmingSignOut = false
    @AppStorage(SoundService.muteDefaultsKey) private var isSoundMuted = false

    /// Routes writes through `SoundService` (not just `UserDefaults`) so
    /// toggling mute while the purr loop is playing stops it immediately.
    private var soundMutedBinding: Binding<Bool> {
        Binding(
            get: { isSoundMuted },
            set: { SoundService.shared.isMuted = $0 }
        )
    }

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
                    Toggle("Mute Sounds", isOn: soundMutedBinding)
                }
                .listRowBackground(CatCalColor.surface)

                Section {
                    Button(role: .destructive) {
                        isConfirmingSignOut = true
                    } label: {
                        Text("Sign Out")
                    }
                }
                .listRowBackground(CatCalColor.surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Profile")
        .confirmationDialog("Sign out of CatCal?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress stays synced to your iCloud account — sign back in anytime to pick up where you left off.")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(session: SessionController())
    }
}
