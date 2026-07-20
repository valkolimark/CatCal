import SwiftData
import SwiftUI

@main
struct CatCalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            AppTask.self,
            UserProgress.self,
            Achievement.self,
            Cosmetic.self
        ])
    }
}
