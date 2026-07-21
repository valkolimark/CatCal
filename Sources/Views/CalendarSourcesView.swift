import SwiftData
import SwiftUI

/// Where the user connects Google and Outlook directly, on top of whatever
/// already reaches them through iOS Settings.
struct CalendarSourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarAggregator.self) private var aggregator
    @Environment(GoogleCalendarSource.self) private var google

    /// Per-provider calendar lists, loaded lazily once connected.
    @State private var calendars: [CalendarProvider: [SourceCalendar]] = [:]
    @State private var busyProvider: CalendarProvider?
    @State private var errorMessage: String?

    private var connectableSources: [any ConnectableCalendarSource] {
        [google]
    }

    var body: some View {
        ZStack {
            CatCalBackground()

            ScrollView {
                VStack(spacing: CatCalSpacing.md) {
                    SystemCalendarsCard()

                    ForEach(connectableSources, id: \.sourceID) { source in
                        ConnectableSourceCard(
                            source: source,
                            calendars: calendars[source.provider] ?? [],
                            isBusy: busyProvider == source.provider,
                            onConnect: { connect(source) },
                            onDisconnect: { disconnect(source) },
                            onToggleCalendar: { calendarID, isEnabled in
                                setCalendar(calendarID, enabled: isEnabled, for: source)
                            }
                        )
                    }

                    Text("Connecting an account here pulls its events directly, even if you haven't added it in iOS Settings.")
                        .font(CatCalFont.caption(12))
                        .foregroundStyle(CatCalColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, CatCalSpacing.md)
                        .padding(.top, CatCalSpacing.sm)
                }
                .padding(.horizontal, CatCalSpacing.screen)
                .padding(.bottom, CatCalSpacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Calendar Sources")
        .navigationBarTitleDisplayMode(.large)
        .task {
            for source in connectableSources where source.hasConnectedAccount {
                await loadCalendars(for: source)
            }
        }
        .alert("Couldn't connect", isPresented: showingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var showingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    private func connect(_ source: any ConnectableCalendarSource) {
        Task {
            busyProvider = source.provider
            defer { busyProvider = nil }

            do {
                let email = try await source.connect()
                aggregator.register(source)

                let account = ConnectedAccountStore.upsert(
                    provider: source.provider,
                    accountEmail: email,
                    context: modelContext
                )

                await loadCalendars(for: source)

                // Everything on by default, so a fresh connection shows the
                // user's whole calendar rather than nothing.
                let allIDs = (calendars[source.provider] ?? []).map(\.id)
                account.enabledCalendarIDs = allIDs
                source.enabledCalendarIDs = Set(allIDs)
                try? modelContext.save()
            } catch CalendarSourceError.cancelled {
                // Backing out of the sheet isn't an error worth surfacing.
            } catch {
                errorMessage = (error as? CalendarSourceError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func disconnect(_ source: any ConnectableCalendarSource) {
        source.disconnect()
        aggregator.remove(sourceID: source.sourceID)
        ConnectedAccountStore.remove(provider: source.provider, context: modelContext)
        calendars[source.provider] = nil
    }

    private func setCalendar(_ calendarID: String, enabled: Bool, for source: any ConnectableCalendarSource) {
        var enabledIDs = source.enabledCalendarIDs ?? Set((calendars[source.provider] ?? []).map(\.id))
        if enabled {
            enabledIDs.insert(calendarID)
        } else {
            enabledIDs.remove(calendarID)
        }
        source.enabledCalendarIDs = enabledIDs
        ConnectedAccountStore.setCalendar(calendarID, enabled: enabled, for: source.provider, context: modelContext)
    }

    private func loadCalendars(for source: any ConnectableCalendarSource) async {
        do {
            let fetched = try await source.availableCalendars()
            calendars[source.provider] = fetched

            // Adopt whatever was stored last time, so toggles survive relaunch.
            if let account = ConnectedAccountStore.account(for: source.provider, context: modelContext),
               !account.enabledCalendarIDs.isEmpty {
                source.enabledCalendarIDs = Set(account.enabledCalendarIDs)
            }
        } catch {
            // Not fatal: the row still shows as connected, just without the
            // per-calendar list. The failure surfaces on Today if it persists.
            calendars[source.provider] = []
        }
    }
}

/// iCloud and anything else the user added in iOS Settings. Nothing to
/// configure here — it's listed so the screen shows the whole picture.
private struct SystemCalendarsCard: View {
    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            SourceGlyph(systemImage: "iphone", tint: CatCalColor.sourceSuccess)

            VStack(alignment: .leading, spacing: 2) {
                Text("iPhone Calendars")
                    .font(CatCalFont.headline(17))
                    .foregroundStyle(CatCalColor.textPrimary)
                Text("iCloud and any account added in iOS Settings")
                    .font(CatCalFont.caption(12))
                    .foregroundStyle(CatCalColor.textSecondary)
            }

            Spacer(minLength: CatCalSpacing.sm)

            TintedChip(text: "Always on", tint: CatCalColor.sourceSuccess)
        }
        .padding(CatCalSpacing.md)
        .catCalGlassCard()
    }
}

/// One OAuth provider: connect button when disconnected, account plus
/// per-calendar toggles when connected.
private struct ConnectableSourceCard: View {
    let source: any ConnectableCalendarSource
    let calendars: [SourceCalendar]
    let isBusy: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onToggleCalendar: (String, Bool) -> Void

    @State private var isConfirmingDisconnect = false

    private var tint: Color {
        source.provider.eventSource.tagColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.md) {
            header

            if source.needsReconnect {
                InlineNotice(
                    systemImage: "exclamationmark.triangle.fill",
                    message: "Your session expired. Reconnect to keep these events showing up.",
                    tint: CatCalColor.warning
                )
            }

            if !source.isConfigured {
                InlineNotice(
                    systemImage: "wrench.and.screwdriver.fill",
                    message: "This build doesn't have a \(source.displayName) client ID yet. Add one in project.yml to enable connecting.",
                    tint: CatCalColor.textSecondary
                )
            }

            if source.hasConnectedAccount, !calendars.isEmpty {
                Divider().overlay(CatCalColor.textSecondary.opacity(0.2))
                calendarToggles
            }
        }
        .padding(CatCalSpacing.md)
        .catCalGlassCard()
        .confirmationDialog(
            "Disconnect \(source.displayName)?",
            isPresented: $isConfirmingDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive, action: onDisconnect)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its events stop showing on Today. Nothing is deleted, and you can reconnect anytime.")
        }
    }

    private var header: some View {
        HStack(spacing: CatCalSpacing.md) {
            SourceGlyph(systemImage: "calendar", tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(CatCalFont.headline(17))
                    .foregroundStyle(CatCalColor.textPrimary)

                Text(source.accountEmail ?? "Not connected")
                    .font(CatCalFont.caption(12))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: CatCalSpacing.sm)

            action
        }
    }

    @ViewBuilder
    private var action: some View {
        if isBusy {
            ProgressView()
        } else if source.hasConnectedAccount {
            Button("Disconnect") { isConfirmingDisconnect = true }
                .font(CatCalFont.caption(13))
                .foregroundStyle(CatCalColor.danger)
                .buttonStyle(.plain)
        } else {
            Button(source.needsReconnect ? "Reconnect" : "Connect", action: onConnect)
                .font(CatCalFont.headline(15))
                .foregroundStyle(.white)
                .padding(.horizontal, CatCalSpacing.md)
                .padding(.vertical, CatCalSpacing.sm)
                .background(source.isConfigured ? CatCalColor.brandPrimary : CatCalColor.textSecondary, in: Capsule())
                .buttonStyle(.plain)
                .disabled(!source.isConfigured)
        }
    }

    private var calendarToggles: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
            Text("Calendars")
                .font(CatCalFont.caption(12))
                .foregroundStyle(CatCalColor.textSecondary)

            ForEach(calendars) { calendar in
                Toggle(isOn: binding(for: calendar)) {
                    Text(calendar.title)
                        .font(CatCalFont.body(15))
                        .foregroundStyle(CatCalColor.textPrimary)
                        .lineLimit(1)
                }
                .tint(tint)
            }
        }
    }

    private func binding(for calendar: SourceCalendar) -> Binding<Bool> {
        Binding(
            get: { source.enabledCalendarIDs?.contains(calendar.id) ?? true },
            set: { onToggleCalendar(calendar.id, $0) }
        )
    }
}

private struct SourceGlyph: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: CatCalRadius.tile, style: .continuous))
    }
}

struct InlineNotice: View {
    let systemImage: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: CatCalSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 13))
                .foregroundStyle(tint)

            Text(message)
                .font(CatCalFont.caption(12))
                .foregroundStyle(CatCalColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(CatCalSpacing.sm + 2)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CatCalRadius.tile, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CalendarSourcesView()
    }
    .environment(CalendarAggregator(sources: [EventKitCalendarSource()]))
    .environment(GoogleCalendarSource())
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
