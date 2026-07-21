import Foundation
import SwiftData
import Testing
@testable import CatCal

@Suite("Persistence schema")
@MainActor
struct PersistenceSchemaTests {
    /// CloudKit-backed stores reject uniqueness constraints outright. Adding
    /// `@Attribute(.unique)` back to a model would break sync at runtime
    /// rather than at compile time, so assert it here instead.
    @Test("No model declares a uniqueness constraint")
    func noUniquenessConstraints() {
        for entity in Persistence.schema.entities {
            #expect(
                entity.uniquenessConstraints.isEmpty,
                "\(entity.name) declares a uniqueness constraint, which CloudKit does not support"
            )
        }
    }

    @Test("Schema covers every model")
    func schemaCoversAllModels() {
        let names = Set(Persistence.schema.entities.map(\.name))
        #expect(names == ["AppTask", "UserProgress", "Achievement", "Cosmetic", "ConnectedAccount"])
    }

    @Test("Models round-trip through a container")
    func modelsRoundTrip() throws {
        let container = try ModelContainer(
            for: Persistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        context.insert(AppTask(title: "Water the plants", xpValue: 5, ownerID: "owner-1"))
        context.insert(UserProgress(ownerID: "owner-1", totalXP: 150, currentLevel: 2))
        try context.save()

        let tasks = try context.fetch(FetchDescriptor<AppTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Water the plants")

        let progress = try context.fetch(FetchDescriptor<UserProgress>())
        #expect(progress.first?.currentLevel == 2)
    }
}
