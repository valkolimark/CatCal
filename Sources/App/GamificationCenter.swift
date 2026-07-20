import Observation
import UIKit

/// App-wide coordinator for the two feedback moments Cycle 4 adds: a small
/// XP toast on task completion, and a full-screen celebration when a
/// level-up and/or achievement unlock happens. Injected via `.environment`
/// at the app root so any screen that awards XP can trigger it without
/// owning overlay presentation itself.
@MainActor
@Observable
final class GamificationCenter {
    struct Toast: Identifiable, Equatable {
        let id: UUID
        let message: String
    }

    struct Celebration: Identifiable, Equatable {
        let id: UUID
        let leveledUp: Bool
        let newLevel: Int
        let stageChanged: Bool
        let newStage: CatStage
        let unlockedAchievement: Achievement?
        let unlockedCosmetic: Cosmetic?

        static func == (lhs: Celebration, rhs: Celebration) -> Bool {
            lhs.id == rhs.id
        }
    }

    var toast: Toast?
    var celebration: Celebration?

    private var toastDismissTask: Task<Void, Never>?

    func showXPToast(_ amount: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SoundService.shared.playTaskCompletion()

        toastDismissTask?.cancel()
        toast = Toast(id: UUID(), message: "+\(amount) XP")
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    /// Shows the celebration overlay if a level-up occurred and/or an
    /// achievement unlocked. No-ops if neither happened.
    func celebrate(levelUp: LevelUpResult?, achievement: Achievement?, cosmetic: Cosmetic?) {
        let leveledUp = levelUp?.leveledUp ?? false
        guard leveledUp || achievement != nil else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if leveledUp {
            SoundService.shared.playLevelUp()
        }

        celebration = Celebration(
            id: UUID(),
            leveledUp: leveledUp,
            newLevel: levelUp?.newLevel ?? 0,
            stageChanged: levelUp?.stageChanged ?? false,
            newStage: levelUp?.newStage ?? .newborn,
            unlockedAchievement: achievement,
            unlockedCosmetic: cosmetic
        )
    }

    func dismissCelebration() {
        celebration = nil
    }
}
