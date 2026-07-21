import SwiftData
import SwiftUI

/// Everything feeding the Today screen, in one place: the calendars that
/// arrive through iOS Settings, plus the Google and Outlook accounts CatCal
/// connects to directly.
struct ManageCalendarsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarAggregator.self) private var aggregator
    @Environment(GoogleCalendarSource.self) private var google
    @Environment(MicrosoftCalendarSource.self) private var microsoft

    /// Per-provider calendar lists, loaded lazily once connected.
    @State private var calendars: [CalendarProvider: [SourceCalendar]] = [:]
    @State private var eventKitAccounts: [EventKitAccount] = []
    /// Bumped whenever a hidden-calendar toggle flips, to re-read
    /// `HiddenCalendars` (which lives in UserDefaults, not in SwiftUI state).
    @State private var hiddenCalendarsRevision = 0
    @State private var busyProvider: CalendarProvider?
    @State private var errorMessage: String?

    private var connectableSources: [any ConnectableCalendarSource] {
        [google, microsoft]
    }

    var body: some View {
        ZStack {
            CatCalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: CatCalSpacing.md) {
                    SectionLabel("On this iPhone")

                    if eventKitAccounts.isEmpty {
                        EmptyEventKitCard()
                    } else {
                        ForEach(eventKitAccounts) { account in
                            EventKitAccountCard(
                                account: account,
                                revision: hiddenCalendarsRevision,
                                onToggle: { calendarID, isVisible in
                                    HiddenCalendars.setHidden(
                                        !isVisible,
                                        calendarID: calendarID,
                                        forSourceID: EventKitCalendarSource.id
                                    )
                                    hiddenCalendarsRevision += 1
                                }
                            )
                        }
                    }

                    SectionLabel("Connected directly")
                        .padding(.top, CatCalSpacing.sm)

                    ForEach(connectableSources, id: \.sourceID) { source in
                        ConnectableSourceCard(
                            source: source,
                            calendars: calendars[source.provider] ?? [],
                            duplicateAccount: duplicateAccount(for: source),
                            isBusy: busyProvider == source.provider,
                            onConnect: { connect(source) },
                            onDisconnect: { disconnect(source) },
                            onToggleCalendar: { calendarID, isEnabled in
                                setCalendar(calendarID, enabled: isEnabled, for: source)
                            },
                            onHideDuplicates: { account in hideEventKitCalendars(of: account) }
                        )
                    }

                    Text("Connecting an account here pulls its events directly, even if you haven't added it in iOS Settings.")
                        .font(CatCalFont.caption(12))
                        .foregroundStyle(CatCalColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, CatCalSpacing.md)
                        .padding(.top, CatCalSpacing.sm)
                }
                .padding(.horizontal, CatCalSpacing.screen)
                .padding(.bottom, CatCalSpacing.tabBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadEventKitAccounts()
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

    /// The EventKit account, if any, that's already syncing the same address
    /// this source is connected to — the setup that produces duplicate events.
    private func duplicateAccount(for source: any ConnectableCalendarSource) -> EventKitAccount? {
        guard let email = source.accountEmail else { return nil }
        return DuplicateSourceDetector.account(
            matching: email,
            in: eventKitAccounts,
            provider: source.provider
        )
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

    /// The one-tap fix for a duplicated account: keep the direct connection
    /// (which has the per-calendar toggles) and switch off the EventKit copy.
    private func hideEventKitCalendars(of account: EventKitAccount) {
        HiddenCalendars.hideAll(account.calendars.map(\.id), forSourceID: EventKitCalendarSource.id)
        hiddenCalendarsRevision += 1
    }

    private func loadEventKitAccounts() async {
        guard let eventKit = aggregator.source(as: EventKitCalendarSource.self) else { return }
        eventKitAccounts = await eventKit.accounts()
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

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(CatCalFont.body(16))
            .foregroundStyle(CatCalColor.textSecondary)
            .padding(.leading, CatCalSpacing.xs)
    }
}

private struct EmptyEventKitCard: View {
    var body: some View {
        HStack(spacing: CatCalSpacing.md) {
            SourceGlyph(systemImage: "iphone", tint: CatCalColor.textSecondary)

            Text("No calendars from iOS Settings yet. Anything you add there shows up here automatically.")
                .font(CatCalFont.body(15))
                .foregroundStyle(CatCalColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(CatCalSpacing.md)
        .catCalGlassCard()
    }
}

/// One account from iOS Settings, with a visibility toggle per calendar.
private struct EventKitAccountCard: View {
    let account: EventKitAccount
    /// Only here to re-run `body` when `HiddenCalendars` changes; the toggle
    /// state itself lives in UserDefaults, which SwiftUI can't observe.
    let revision: Int
    let onToggle: (String, Bool) -> Void

    private var tint: Color { account.kind.tagColor }

    var body: some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.md) {
            HStack(spacing: CatCalSpacing.md) {
                SourceGlyph(systemImage: "iphone", tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.title)
                        .font(CatCalFont.headline(17))
                        .foregroundStyle(CatCalColor.textPrimary)
                        .lineLimit(1)
                    Text("Synced through iOS Settings")
                        .font(CatCalFont.caption(12))
                        .foregroundStyle(CatCalColor.textSecondary)
                }

                Spacer(minLength: CatCalSpacing.sm)

                TintedChip(text: account.kind.label, tint: tint)
            }

            if !account.calendars.isEmpty {
                Divider().overlay(CatCalColor.textSecondary.opacity(0.2))

                ForEach(account.calendars) { calendar in
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
        .padding(CatCalSpacing.md)
        .catCalGlassCard()
    }

    private func binding(for calendar: SourceCalendar) -> Binding<Bool> {
        Binding(
            get: {
                !HiddenCalendars.isHidden(calendar.id, forSourceID: EventKitCalendarSource.id)
            },
            set: { onToggle(calendar.id, $0) }
        )
    }
}

/// One OAuth provider: connect button when disconnected, account plus
/// per-calendar toggles when connected.
private struct ConnectableSourceCard: View {
    let source: any ConnectableCalendarSource
    let calendars: [SourceCalendar]
    let duplicateAccount: EventKitAccount?
    let isBusy: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onToggleCalendar: (String, Bool) -> Void
    let onHideDuplicates: (EventKitAccount) -> Void

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
                    message: "This build doesn't have an OAuth client ID for \(source.displayName) yet. Add one in project.yml to enable connecting.",
                    tint: CatCalColor.textSecondary
                )
            }

            if let duplicateAccount {
                duplicateWarning(for: duplicateAccount)
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

    /// Both paths active for one account means every event is listed twice.
    /// Offered as a one-tap fix rather than applied automatically — some
    /// people genuinely want both, and silently hiding calendars would be a
    /// worse surprise than the duplicates.
    private func duplicateWarning(for account: EventKitAccount) -> some View {
        VStack(alignment: .leading, spacing: CatCalSpacing.sm) {
            InlineNotice(
                systemImage: "doc.on.doc.fill",
                message: "This account is already syncing through iOS Settings — connecting it directly may cause duplicate events.",
                tint: CatCalColor.warning
            )

            Button {
                onHideDuplicates(account)
            } label: {
                Text("Hide “\(account.title)” calendars from iOS Settings")
                    .font(CatCalFont.caption(13))
                    .foregroundStyle(CatCalColor.brandPrimary)
            }
            .buttonStyle(.plain)
            .padding(.leading, CatCalSpacing.xs)
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

struct SourceGlyph: View {
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
        ManageCalendarsView()
    }
    .environment(CalendarAggregator(sources: [EventKitCalendarSource()]))
    .environment(GoogleCalendarSource())
    .environment(MicrosoftCalendarSource())
    .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
