import SwiftData
import SwiftUI

@main
struct CatCalApp: App {
    @State private var gamificationCenter = GamificationCenter()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TodayView()
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
        .modelContainer(for: [
            AppTask.self,
            UserProgress.self,
            Achievement.self,
            Cosmetic.self
        ])
    }
}
