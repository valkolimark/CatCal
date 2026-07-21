import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GamificationCenter.self) private var gamificationCenter
    @Query private var tasks: [AppTask]

    @State private var isShowingAddTask = false

    init() {
        let ownerID = CurrentUser.id
        _tasks = Query(
            filter: #Predicate<AppTask> { $0.ownerID == ownerID },
            sort: \AppTask.title
        )
    }

    private var pendingTasks: [AppTask] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [AppTask] {
        tasks.filter { $0.isCompleted }
    }

    /// XP banked so far, shown in the header pill.
    private var earnedXP: Int {
        completedTasks.reduce(0) { $0 + $1.xpValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CatCalBackground()

            VStack(spacing: 0) {
                ScreenHeader(
                    title: "Tasks",
                    subtitle: "\(pendingTasks.count) remaining today"
                ) {
                    StatPill(
                        systemImage: "bolt.fill",
                        text: "+\(earnedXP) XP",
                        tint: CatCalColor.xpGreen,
                        iconTint: CatCalColor.xpGreen
                    )
                }

                content
            }
            .padding(.top, CatCalSpacing.sm)

            CatBuddyImage(height: 170)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, CatCalSpacing.sm)
                .padding(.bottom, CatCalSpacing.xl + CatCalSpacing.md)
                .allowsHitTesting(false)
        }
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskSheet(modelContext: modelContext)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CatCalSpacing.lg) {
                if !pendingTasks.isEmpty {
                    GlassEffectContainer(spacing: CatCalSpacing.sm) {
                        VStack(spacing: CatCalSpacing.sm + 2) {
                            ForEach(pendingTasks) { task in
                                TaskRow(task: task) {
                                    complete(task)
                                }
                            }
                        }
                    }
                }

                if !completedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
                        Text("Completed")
                            .font(CatCalFont.body(16))
                            .foregroundStyle(CatCalColor.textSecondary)

                        GlassEffectContainer(spacing: CatCalSpacing.sm) {
                            VStack(spacing: CatCalSpacing.sm + 2) {
                                ForEach(completedTasks) { task in
                                    CompletedTaskRow(task: task)
                                }
                            }
                        }
                    }
                }

                if tasks.isEmpty {
                    emptyState
                }

                AddTaskCard { isShowingAddTask = true }
            }
            .padding(.horizontal, CatCalSpacing.screen)
            .padding(.bottom, CatCalSpacing.tabBarClearance + 120)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: CatCalSpacing.sm) {
            Text("No tasks yet")
                .font(CatCalFont.headline(18))
                .foregroundStyle(CatCalColor.textPrimary)
            Text("Add one to start earning XP.")
                .font(CatCalFont.body())
                .foregroundStyle(CatCalColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CatCalSpacing.xl)
    }

    private func complete(_ task: AppTask) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            task.isCompleted = true
        }

        let progress = ProgressEngine.currentProgress(in: modelContext)
        let result = ProgressEngine.awardXP(task.xpValue, to: progress)
        gamificationCenter.showXPToast(task.xpValue)

        let completedCount = tasks.filter(\.isCompleted).count
        let unlocked = AchievementEngine.checkTaskCompletion(completedTaskCount: completedCount, context: modelContext)
            + AchievementEngine.checkLevel(result.newLevel, context: modelContext)

        gamificationCenter.celebrate(
            levelUp: result,
            achievement: unlocked.first?.achievement,
            cosmetic: unlocked.first?.cosmetic
        )
    }
}

private struct TaskRow: View {
    let task: AppTask
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Button(action: onComplete) {
                Circle()
                    .strokeBorder(CatCalColor.textSecondary.opacity(0.55), lineWidth: 2)
                    .frame(width: 27, height: 27)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.title)")

            Text(task.title)
                .font(CatCalFont.headline(17))
                .foregroundStyle(CatCalColor.textPrimary)
                .lineLimit(2)

            Spacer(minLength: CatCalSpacing.sm)

            TintedChip(text: "+\(task.xpValue) XP", tint: CatCalColor.xpGreen)
        }
        .padding(.horizontal, CatCalSpacing.md)
        .frame(minHeight: 64)
        .catCalGlassCard(cornerRadius: CatCalRadius.control)
    }
}

private struct CompletedTaskRow: View {
    let task: AppTask

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 27))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, CatCalColor.sourceSuccess)

            Text(task.title)
                .font(CatCalFont.headline(17))
                .foregroundStyle(CatCalColor.textSecondary)
                .lineLimit(2)
                .strikethrough()

            Spacer(minLength: CatCalSpacing.sm)

            TintedChip(text: "+\(task.xpValue) XP", tint: CatCalColor.xpGreen, isMuted: true)
        }
        .padding(.horizontal, CatCalSpacing.md)
        .frame(minHeight: 64)
        .catCalGlassCard(cornerRadius: CatCalRadius.control)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), completed")
    }
}

/// Reads as one more row in the list rather than a floating "+" button —
/// adding a task is part of the list's flow, not an action hovering over it.
private struct AddTaskCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CatCalSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                Text("Add task")
                    .font(CatCalFont.headline(18))
            }
            .foregroundStyle(CatCalColor.brandPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .catCalGlassCard(cornerRadius: CatCalRadius.control)
        }
        .buttonStyle(.plain)
    }
}

private struct AddTaskSheet: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    private var xpValue: Int {
        hasDueDate ? 10 : 5
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                }

                Section {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Date", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                Section {
                    HStack {
                        Text("Reward")
                        Spacer()
                        Text("+\(xpValue) XP")
                            .foregroundStyle(CatCalColor.xpGreen)
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addTask() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addTask() {
        let task = AppTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            xpValue: xpValue,
            ownerID: CurrentUser.id
        )
        modelContext.insert(task)
        dismiss()
    }
}

#Preview {
    TasksView()
        .environment(GamificationCenter())
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
