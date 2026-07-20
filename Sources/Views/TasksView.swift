import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [AppTask]
    @Query private var progressRecords: [UserProgress]

    @State private var isShowingAddTask = false

    init() {
        let ownerID = CurrentUser.id
        _tasks = Query(
            filter: #Predicate<AppTask> { $0.ownerID == ownerID },
            sort: \AppTask.title
        )
        _progressRecords = Query(filter: #Predicate<UserProgress> { $0.ownerID == ownerID })
    }

    private var pendingTasks: [AppTask] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [AppTask] {
        tasks.filter { $0.isCompleted }
    }

    var body: some View {
        ZStack {
            CatCalColor.appBackground.ignoresSafeArea()

            if tasks.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(pendingTasks) { task in
                            TaskRow(task: task) {
                                complete(task)
                            }
                        }
                    }

                    if !completedTasks.isEmpty {
                        Section("Completed") {
                            ForEach(completedTasks) { task in
                                CompletedTaskRow(task: task)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Task", systemImage: "plus") {
                    isShowingAddTask = true
                }
            }
        }
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskSheet(modelContext: modelContext)
        }
    }

    private var emptyState: some View {
        VStack(spacing: CatCalSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(CatCalColor.textSecondary)
            Text("No tasks yet")
                .font(CatCalFont.headline(18))
                .foregroundStyle(CatCalColor.textPrimary)
            Text("Add one to start earning XP.")
                .font(CatCalFont.body())
                .foregroundStyle(CatCalColor.textSecondary)
        }
    }

    private func complete(_ task: AppTask) {
        withAnimation {
            task.isCompleted = true
        }
        ProgressEngine.awardXP(task.xpValue, to: currentProgress())
    }

    private func currentProgress() -> UserProgress {
        if let existing = progressRecords.first {
            return existing
        }
        let progress = UserProgress(ownerID: CurrentUser.id)
        modelContext.insert(progress)
        return progress
    }
}

private struct TaskRow: View {
    let task: AppTask
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(CatCalColor.textSecondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(CatCalFont.body(16))
                .foregroundStyle(CatCalColor.textPrimary)

            Spacer()

            XPTag(value: task.xpValue, muted: false)
        }
        .padding(.vertical, CatCalSpacing.xs)
        .listRowBackground(CatCalColor.surface)
    }
}

private struct CompletedTaskRow: View {
    let task: AppTask

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(CatCalColor.sourceSuccess)

            Text(task.title)
                .font(CatCalFont.body(16))
                .foregroundStyle(CatCalColor.textSecondary)
                .strikethrough()

            Spacer()

            XPTag(value: task.xpValue, muted: true)
        }
        .padding(.vertical, CatCalSpacing.xs)
        .listRowBackground(CatCalColor.surface)
    }
}

private struct XPTag: View {
    let value: Int
    let muted: Bool

    private var tint: Color {
        muted ? CatCalColor.textSecondary : CatCalColor.xpGold
    }

    var body: some View {
        Text("+\(value) XP")
            .font(CatCalFont.caption(11))
            .foregroundStyle(tint)
            .padding(.horizontal, CatCalSpacing.sm)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
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
                            .foregroundStyle(CatCalColor.xpGold)
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
    NavigationStack {
        TasksView()
    }
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self], inMemory: true)
}
