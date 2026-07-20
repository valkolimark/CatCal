import Foundation
import SwiftData
import Testing
@testable import CatCal

@Suite("Sign-in data migration")
@MainActor
struct SessionMigrationTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Persistence.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    @Test("Records created before sign-in are re-homed onto the real Apple ID")
    func migratesMockOwnedRecords() throws {
        let context = try makeContext()
        let mockID = MockAuthService.mockUserID
        let realID = "001234.abcdef.5678"

        context.insert(AppTask(title: "Pre-sign-in task", ownerID: mockID))
        context.insert(UserProgress(ownerID: mockID, totalXP: 300, currentLevel: 3))
        context.insert(Achievement(id: "first_task", title: "Getting Started", achievementDescription: "", isUnlocked: true, ownerID: mockID))
        context.insert(Cosmetic(id: "first_task", name: "Bell Collar", category: "collar", isUnlocked: true, ownerID: mockID))
        try context.save()

        let migrated = SessionController().migrateMockDataIfNeeded(to: realID, context: context)

        #expect(migrated == 4)
        #expect(try context.fetch(FetchDescriptor<AppTask>()).allSatisfy { $0.ownerID == realID })
        #expect(try context.fetch(FetchDescriptor<UserProgress>()).allSatisfy { $0.ownerID == realID })
        #expect(try context.fetch(FetchDescriptor<Achievement>()).allSatisfy { $0.ownerID == realID })
        #expect(try context.fetch(FetchDescriptor<Cosmetic>()).allSatisfy { $0.ownerID == realID })
    }

    @Test("Migration preserves earned progress rather than resetting it")
    func preservesProgress() throws {
        let context = try makeContext()
        context.insert(UserProgress(ownerID: MockAuthService.mockUserID, totalXP: 450, currentLevel: 4, currentStreak: 6))
        try context.save()

        SessionController().migrateMockDataIfNeeded(to: "001234.abcdef.5678", context: context)

        let progress = try #require(try context.fetch(FetchDescriptor<UserProgress>()).first)
        #expect(progress.totalXP == 450)
        #expect(progress.currentLevel == 4)
        #expect(progress.currentStreak == 6)
    }

    /// The important safety property: on a shared device, signing in as a
    /// second Apple ID must never absorb the first user's records.
    @Test("Another signed-in user's records are left untouched")
    func doesNotStealOtherUsersRecords() throws {
        let context = try makeContext()
        let otherUserID = "009999.other.0000"
        let newUserID = "001234.abcdef.5678"

        context.insert(AppTask(title: "Someone else's task", ownerID: otherUserID))
        context.insert(AppTask(title: "Pre-sign-in task", ownerID: MockAuthService.mockUserID))
        try context.save()

        let migrated = SessionController().migrateMockDataIfNeeded(to: newUserID, context: context)

        #expect(migrated == 1)
        let tasks = try context.fetch(FetchDescriptor<AppTask>())
        let otherTask = try #require(tasks.first { $0.title == "Someone else's task" })
        #expect(otherTask.ownerID == otherUserID)
    }

    @Test("Migrating to the mock ID itself is a no-op")
    func mockToMockIsNoOp() throws {
        let context = try makeContext()
        context.insert(AppTask(title: "Task", ownerID: MockAuthService.mockUserID))
        try context.save()

        let migrated = SessionController().migrateMockDataIfNeeded(
            to: MockAuthService.mockUserID,
            context: context
        )

        #expect(migrated == 0)
    }
}

@Suite("Keychain")
struct KeychainTests {
    @Test("Stored values round-trip and can be removed")
    func roundTrip() {
        let value = "001234.roundtrip.5678"
        Keychain.set(value, for: .appleUserID)
        #expect(Keychain.get(.appleUserID) == value)

        // Overwriting replaces rather than duplicating.
        let updated = "009876.updated.4321"
        Keychain.set(updated, for: .appleUserID)
        #expect(Keychain.get(.appleUserID) == updated)

        Keychain.remove(.appleUserID)
        #expect(Keychain.get(.appleUserID) == nil)
    }
}
