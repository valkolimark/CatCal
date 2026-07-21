import SwiftUI

struct RootTabView: View {
    let session: SessionController

    @State private var selectedTab: AppTab

    init(session: SessionController) {
        self.session = session
        #if DEBUG
        _selectedTab = State(initialValue: SampleData.startTab ?? .today)
        #else
        _selectedTab = State(initialValue: .today)
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CatCalBackground()

            // Still a TabView, with its own bar hidden: it keeps each tab's
            // view state and navigation stack alive across switches, which a
            // hand-rolled `switch` over the selection would throw away.
            TabView(selection: $selectedTab) {
                TodayView(onSelectTasks: { selectedTab = .tasks })
                    .tabBarHidden()
                    .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
                    .tag(AppTab.today)

                TasksView()
                    .tabBarHidden()
                    .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.systemImage) }
                    .tag(AppTab.tasks)

                NavigationStack {
                    CompanionView()
                }
                .tabBarHidden()
                .tabItem { Label(AppTab.buddy.title, systemImage: AppTab.buddy.systemImage) }
                .tag(AppTab.buddy)

                NavigationStack {
                    ProfileView(session: session)
                }
                .tabBarHidden()
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
            }

            FloatingTabBar(selection: $selectedTab)
                .padding(.bottom, CatCalSpacing.xs)
        }
        .tint(CatCalColor.brandPrimary)
    }
}

private extension View {
    /// Hides the system tab bar (and reclaims its safe-area inset) so the
    /// custom `FloatingTabBar` is the only one on screen.
    func tabBarHidden() -> some View {
        toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
    }
}

#Preview {
    RootTabView(session: SessionController())
        .environment(GamificationCenter())
        .environment(CalendarAggregator(sources: [EventKitCalendarSource()]))
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
