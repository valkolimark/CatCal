import SwiftData
import SwiftUI

@main
struct CatCalApp: App {
    @State private var gamificationCenter = GamificationCenter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let modelContainer = Persistence.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environment(gamificationCenter)
            .overlay(alignment: .top) {
                if let toast = gamificationCenter.toast {
                    XPToastView(message: toast.message)
                        .padding(.top, CatCalSpacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if let celebration = gamificationCenter.celebration {
                    LevelUpCelebrationView(celebration: celebration) {
                        gamificationCenter.dismissCelebration()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.spring(duration: 0.35), value: gamificationCenter.toast)
            .animation(.spring(duration: 0.35), value: gamificationCenter.celebration)
        }
        .modelContainer(modelContainer)
    }
}
