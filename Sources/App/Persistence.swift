import Foundation
import SwiftData

enum Persistence {
    static let cloudKitContainerID = "iCloud.com.valkolimark.catcal"

    static let schema = Schema([
        AppTask.self,
        UserProgress.self,
        Achievement.self,
        Cosmetic.self
    ])

    /// Builds the app's `ModelContainer`, syncing through the private
    /// CloudKit database so a user's progress follows their iCloud account
    /// across devices and survives a delete/reinstall.
    ///
    /// Conflict resolution is CloudKit's default last-write-wins. Known
    /// simplification for v1: two devices editing the same record while
    /// offline will keep whichever write syncs last rather than merging
    /// (e.g. XP earned on one device during that window can be lost).
    ///
    /// Falls back to a local-only store when the CloudKit container can't be
    /// opened — no iCloud account signed in, or a build whose provisioning
    /// profile lacks the container. The app stays fully usable offline; it
    /// just doesn't sync.
    static func makeModelContainer() -> ModelContainer {
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            // Not fatal: fall back to local-only persistence.
            let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                // A local store that won't open means the app has nowhere to
                // persist anything — there's no meaningful way to continue.
                fatalError("Could not create a local ModelContainer: \(error)")
            }
        }
    }
}
