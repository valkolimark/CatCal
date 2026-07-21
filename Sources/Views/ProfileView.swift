import SwiftUI

struct ProfileView: View {
    let session: SessionController

    @State private var isConfirmingSignOut = false
    @State private var isShowingCalendarSources = false
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
            CatCalBackground()

            VStack(spacing: 0) {
                ScreenHeader(title: "Profile", subtitle: "Your account and preferences")

                ScrollView {
                    VStack(spacing: CatCalSpacing.md) {
                        Button {
                            isShowingCalendarSources = true
                        } label: {
                            SettingsCard {
                                HStack {
                                    SettingsLabel(systemImage: "calendar.badge.plus", title: "Calendar sources")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(CatCalColor.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        SettingsCard {
                            Toggle(isOn: soundMutedBinding) {
                                SettingsLabel(systemImage: "speaker.slash.fill", title: "Mute sounds")
                            }
                            .tint(CatCalColor.brandPrimary)
                        }

                        SettingsCard {
                            HStack {
                                SettingsLabel(systemImage: "info.circle.fill", title: "Version")
                                Spacer()
                                Text(appVersion)
                                    .font(CatCalFont.body(16))
                                    .foregroundStyle(CatCalColor.textSecondary)
                            }
                        }

                        Button {
                            isConfirmingSignOut = true
                        } label: {
                            SettingsCard {
                                HStack {
                                    SettingsLabel(
                                        systemImage: "rectangle.portrait.and.arrow.right",
                                        title: "Sign out",
                                        tint: CatCalColor.danger
                                    )
                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, CatCalSpacing.screen)
                    .padding(.bottom, CatCalSpacing.tabBarClearance)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, CatCalSpacing.sm)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingCalendarSources) {
            CalendarSourcesView()
        }
        .task {
            #if DEBUG
            isShowingCalendarSources = SampleData.opensCalendarSources
            #endif
        }
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

/// One glass panel in the settings stack.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, CatCalSpacing.md)
            .frame(minHeight: 60)
            .catCalGlassCard(cornerRadius: CatCalRadius.control)
    }
}

/// Icon-plus-title pairing shared by every settings row.
struct SettingsLabel: View {
    let systemImage: String
    let title: String
    var tint: Color = CatCalColor.brandPrimary

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(CatCalFont.body(16))
                .foregroundStyle(CatCalColor.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(session: SessionController())
    }
}
