import SwiftUI

enum AppTab: Hashable {
    case today
    case tasks
    case buddy
    case profile
}

struct RootTabView: View {
    let session: SessionController

    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(onSelectTasks: { selectedTab = .tasks })
            }
            .tabItem { Label("Today", systemImage: "sun.max.fill") }
            .tag(AppTab.today)

            NavigationStack {
                TasksView()
            }
            .tabItem { Label("Tasks", systemImage: "checkmark.circle.fill") }
            .tag(AppTab.tasks)

            NavigationStack {
                CompanionView()
            }
            .tabItem { Label("Buddy", systemImage: "cat.fill") }
            .tag(AppTab.buddy)

            NavigationStack {
                ProfileView(session: session)
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
            .tag(AppTab.profile)
        }
        .tint(CatCalColor.brandPrimary)
    }
}

#Preview {
    RootTabView(session: SessionController())
        .environment(GamificationCenter())
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self], inMemory: true)
}
