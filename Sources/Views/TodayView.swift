import SwiftData
import SwiftUI

private extension CalendarSource {
    var tagColor: Color {
        switch self {
        case .google: CatCalColor.sourceGoogle
        case .outlook: CatCalColor.sourcePro
        case .iCloud: CatCalColor.sourceSuccess
        }
    }
}

enum TodayDestination: Hashable {
    case tasks
}

struct TodayView: View {
    @Query private var progressRecords: [UserProgress]
    @Query private var pendingTasks: [AppTask]

    @State private var viewModel = TodayViewModel()

    init() {
        let ownerID = CurrentUser.id
        _progressRecords = Query(filter: #Predicate<UserProgress> { $0.ownerID == ownerID })
        _pendingTasks = Query(
            filter: #Predicate<AppTask> { $0.ownerID == ownerID && $0.isCompleted == false }
        )
    }

    private var streak: Int {
        progressRecords.first?.currentStreak ?? 0
    }

    var body: some View {
        ZStack {
            CatCalColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                switch viewModel.accessState {
                case .denied:
                    PermissionDeniedView()
                case .notDetermined, .authorized:
                    ScrollView {
                        VStack(spacing: CatCalSpacing.md) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.top, CatCalSpacing.xl)
                            } else if viewModel.events.isEmpty {
                                emptyEventsState
                            } else {
                                ForEach(viewModel.events) { event in
                                    EventCard(event: event)
                                }
                            }

                            TasksTeaserCard(remaining: pendingTasks.count)
                        }
                        .padding(CatCalSpacing.md)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .navigationDestination(for: TodayDestination.self) { destination in
            switch destination {
            case .tasks:
                // Placeholder until Cycle 3 adds TasksView.
                Text("Tasks — coming in Cycle 3")
                    .font(CatCalFont.body())
                    .foregroundStyle(CatCalColor.textSecondary)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(CatCalFont.title(24))
                .foregroundStyle(CatCalColor.textPrimary)

            Spacer()

            StreakPill(streak: streak)
        }
        .padding(CatCalSpacing.md)
    }

    private var emptyEventsState: some View {
        VStack(spacing: CatCalSpacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(CatCalColor.textSecondary)
            Text("Nothing on your calendar today")
                .font(CatCalFont.body())
                .foregroundStyle(CatCalColor.textSecondary)
        }
        .padding(.top, CatCalSpacing.xl)
    }
}

private struct StreakPill: View {
    let streak: Int

    var body: some View {
        HStack(spacing: CatCalSpacing.xs) {
            Image(systemName: "flame.fill")
                .foregroundStyle(CatCalColor.warning)
            Text("\(streak)")
                .font(CatCalFont.headline(15))
                .foregroundStyle(CatCalColor.textPrimary)
        }
        .padding(.horizontal, CatCalSpacing.md)
        .padding(.vertical, CatCalSpacing.sm)
        .background(CatCalColor.surface, in: Capsule())
    }
}

private struct EventCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            RoundedRectangle(cornerRadius: CatCalRadius.pill)
                .fill(event.source.tagColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: CatCalSpacing.xs) {
                Text(event.title)
                    .font(CatCalFont.headline())
                    .foregroundStyle(CatCalColor.textPrimary)
                    .lineLimit(2)

                Text(timeLabel)
                    .font(CatCalFont.caption())
                    .foregroundStyle(CatCalColor.textSecondary)
            }

            Spacer()

            SourceTag(source: event.source)
        }
        .padding(CatCalSpacing.md)
        .background(CatCalColor.surface, in: RoundedRectangle(cornerRadius: CatCalRadius.card))
    }

    private var timeLabel: String {
        event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened)
    }
}

private struct SourceTag: View {
    let source: CalendarSource

    var body: some View {
        Text(source.label)
            .font(CatCalFont.caption(11))
            .foregroundStyle(source.tagColor)
            .padding(.horizontal, CatCalSpacing.sm)
            .padding(.vertical, 4)
            .background(source.tagColor.opacity(0.15), in: Capsule())
    }
}

private struct TasksTeaserCard: View {
    let remaining: Int

    var body: some View {
        NavigationLink(value: TodayDestination.tasks) {
            HStack {
                VStack(alignment: .leading, spacing: CatCalSpacing.xs) {
                    Text("\(remaining) task\(remaining == 1 ? "" : "s") left today")
                        .font(CatCalFont.headline())
                        .foregroundStyle(CatCalColor.textPrimary)
                    Text("Tap to see your list")
                        .font(CatCalFont.caption())
                        .foregroundStyle(CatCalColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(CatCalColor.textSecondary)
            }
            .padding(CatCalSpacing.md)
            .background(CatCalColor.brandPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: CatCalRadius.card))
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: CatCalSpacing.md) {
            Spacer()

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(CatCalColor.textSecondary)

            Text("Calendar access is off")
                .font(CatCalFont.headline(18))
                .foregroundStyle(CatCalColor.textPrimary)

            Text("CatCal needs calendar access to show your day. Turn it on in Settings to see events from Google, Outlook, and iCloud in one place.")
                .font(CatCalFont.body())
                .foregroundStyle(CatCalColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CatCalSpacing.xl)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(CatCalFont.headline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, CatCalSpacing.lg)
                    .padding(.vertical, CatCalSpacing.sm)
                    .background(CatCalColor.brandPrimary, in: Capsule())
            }
            .padding(.top, CatCalSpacing.sm)

            Spacer()
            Spacer()
        }
        .padding(CatCalSpacing.md)
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self], inMemory: true)
}
