import SwiftData
import SwiftUI

extension CalendarSource {
    var tagColor: Color {
        switch self {
        case .google: CatCalColor.sourceGoogle
        case .outlook: CatCalColor.sourcePro
        case .iCloud: CatCalColor.sourceSuccess
        }
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GamificationCenter.self) private var gamificationCenter
    @Environment(CalendarAggregator.self) private var aggregator
    @Query private var progressRecords: [UserProgress]
    @Query private var pendingTasks: [AppTask]

    @State private var viewModel = TodayViewModel()

    /// Switches the root TabView to the Tasks tab. Nil (and the card
    /// becomes inert) when previewed outside `RootTabView`.
    var onSelectTasks: (() -> Void)?

    init(onSelectTasks: (() -> Void)? = nil) {
        self.onSelectTasks = onSelectTasks
        let ownerID = CurrentUser.id
        _progressRecords = Query(filter: #Predicate<UserProgress> { $0.ownerID == ownerID })
        _pendingTasks = Query(
            filter: #Predicate<AppTask> { $0.ownerID == ownerID && $0.isCompleted == false }
        )
    }

    private var streak: Int {
        progressRecords.first?.currentStreak ?? 0
    }

    private var pendingXP: Int {
        pendingTasks.reduce(0) { $0 + $1.xpValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CatCalBackground()

            VStack(spacing: 0) {
                ScreenHeader(
                    title: "Today",
                    subtitle: Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
                ) {
                    StatPill(systemImage: "flame.fill", text: "\(streak)")
                }

                if viewModel.showsPermissionState {
                    PermissionDeniedView()
                } else {
                    content
                }
            }
            .padding(.top, CatCalSpacing.sm)

            // Sits behind the tab bar and below the scrolling content, so
            // the day's list scrolls past it rather than pushing it around.
            CatBuddyImage()
                .padding(.bottom, CatCalSpacing.xl + CatCalSpacing.md)
                .allowsHitTesting(false)
        }
        .refreshable {
            await viewModel.load(using: aggregator)
        }
        .task {
            AchievementEngine.seedIfNeeded(context: modelContext)
            await viewModel.load(using: aggregator)
            guard !viewModel.connectedSources.isEmpty else { return }

            let progress = ProgressEngine.currentProgress(in: modelContext)
            ProgressEngine.updateStreak(for: progress)

            let unlocked = AchievementEngine.checkCalendarSources(viewModel.connectedSources, context: modelContext)
                + AchievementEngine.checkStreak(progress.currentStreak, context: modelContext)

            if let first = unlocked.first {
                gamificationCenter.celebrate(levelUp: nil, achievement: first.achievement, cosmetic: first.cosmetic)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: CatCalSpacing.md) {
                ForEach(viewModel.failures) { failure in
                    SourceFailureBanner(failure: failure)
                }

                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView()
                        .padding(.top, CatCalSpacing.xl)
                } else if viewModel.events.isEmpty {
                    emptyEventsState
                } else {
                    GlassEffectContainer(spacing: CatCalSpacing.md) {
                        VStack(spacing: CatCalSpacing.md) {
                            ForEach(viewModel.events) { event in
                                EventCard(event: event)
                            }
                        }
                    }
                }

                TasksTeaserCard(remaining: pendingTasks.count, xp: pendingXP, onTap: onSelectTasks)
            }
            .padding(.horizontal, CatCalSpacing.screen)
            .padding(.bottom, CatCalSpacing.tabBarClearance + 140)
        }
        .scrollIndicators(.hidden)
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
        .padding(.vertical, CatCalSpacing.xl)
    }
}

/// Inline, non-blocking: one source failing shouldn't hide the rest of the
/// day, so this sits above the events it couldn't add rather than replacing
/// them.
private struct SourceFailureBanner: View {
    let failure: CalendarSourceFailure

    var body: some View {
        HStack(spacing: CatCalSpacing.sm) {
            Image(systemName: failure.needsReconnect ? "arrow.clockwise.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(CatCalColor.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(failure.displayName)
                    .font(CatCalFont.headline(14))
                    .foregroundStyle(CatCalColor.textPrimary)
                Text(failure.message)
                    .font(CatCalFont.caption())
                    .foregroundStyle(CatCalColor.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(CatCalSpacing.md)
        .background(CatCalColor.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: CatCalRadius.control, style: .continuous))
    }
}

private struct EventCard: View {
    let event: UnifiedEvent

    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            Capsule()
                .fill(event.source.tagColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(CatCalFont.headline(19))
                    .foregroundStyle(CatCalColor.textPrimary)
                    .lineLimit(2)

                Text(timeLabel)
                    .font(CatCalFont.body(15))
                    .foregroundStyle(CatCalColor.textSecondary)
            }

            Spacer(minLength: CatCalSpacing.sm)

            TintedChip(text: event.source.label, tint: event.source.tagColor)
        }
        .padding(CatCalSpacing.md)
        .frame(minHeight: 76)
        .catCalGlassCard()
        .accessibilityElement(children: .combine)
    }

    private var timeLabel: String {
        guard !event.isAllDay else { return "All day" }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }
}

private struct TasksTeaserCard: View {
    let remaining: Int
    let xp: Int
    let onTap: (() -> Void)?

    /// Broken deliberately after the dash: the two halves are "what's left"
    /// and "what it's worth", and letting them reflow mid-clause reads worse
    /// than a fixed break.
    private var message: String {
        guard remaining > 0 else { return "All caught up for today" }
        return "\(remaining) task\(remaining == 1 ? "" : "s") left today —\nfinish them for +\(xp) XP"
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: CatCalSpacing.md) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(CatCalColor.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(CatCalColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: CatCalRadius.tile, style: .continuous))

                Text(message)
                    .font(CatCalFont.body(16))
                    .foregroundStyle(CatCalColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: CatCalSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(CatCalColor.surface.opacity(0.7), in: Circle())
            }
            .padding(CatCalSpacing.md)
            .catCalGlassCard()
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
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
                    .padding(.horizontal, CatCalSpacing.screen)
                    .padding(.vertical, CatCalSpacing.sm + 2)
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
    TodayView()
        .environment(GamificationCenter())
        .environment(CalendarAggregator(sources: [EventKitCalendarSource()]))
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
