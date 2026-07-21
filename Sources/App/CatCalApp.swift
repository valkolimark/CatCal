import SwiftData
import SwiftUI

@main
struct CatCalApp: App {
    @State private var gamificationCenter = GamificationCenter()
    @State private var session = SessionController()
    /// App-level so a connection made on the Calendar Sources screen is
    /// immediately visible to Today's next refresh.
    @State private var calendarAggregator = CalendarAggregator(sources: [EventKitCalendarSource()])
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let modelContainer = Persistence.makeModelContainer()

    /// `-seedSampleData` is for looking at the populated app, so it skips
    /// onboarding too rather than making every launch page through it.
    private var showsOnboarding: Bool {
        #if DEBUG
        !hasCompletedOnboarding && !SampleData.isEnabled
        #else
        !hasCompletedOnboarding
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showsOnboarding {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                } else {
                    switch session.state {
                    case .restoring:
                        RestoringSessionView()
                    case .signedOut:
                        SignInView(session: session)
                    case .signedIn:
                        // Built only once signed in, so the @Query predicates
                        // inside capture the real ownerID rather than the mock.
                        RootTabView(session: session)
                    }
                }
            }
            .task {
                #if DEBUG
                if SampleData.isEnabled {
                    calendarAggregator.register(SampleData.CalendarSource())
                    SampleData.seedTasks(context: modelContainer.mainContext)
                }
                #endif
                await session.restore()
            }
            .animation(.easeInOut(duration: 0.25), value: session.isSignedIn)
            .environment(gamificationCenter)
            .environment(calendarAggregator)
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
