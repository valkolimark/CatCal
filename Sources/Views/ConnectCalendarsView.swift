import SwiftData
import SwiftUI

/// The optional step right after Sign in with Apple: connect Google or
/// Outlook directly, or skip.
///
/// Deliberately skippable and shown once — CatCal already works from the
/// calendars in iOS Settings, so this is an upgrade, not a gate. It reuses
/// the same `ConnectableCalendarSource.connect()` the Manage Calendars screen
/// calls, so there's one connect path rather than an onboarding copy that
/// drifts.
struct ConnectCalendarsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarAggregator.self) private var aggregator
    @Environment(GoogleCalendarSource.self) private var google
    @Environment(MicrosoftCalendarSource.self) private var microsoft

    let onFinish: () -> Void

    @State private var busyProvider: CalendarProvider?
    @State private var errorMessage: String?

    private var sources: [any ConnectableCalendarSource] {
        [google, microsoft]
    }

    var body: some View {
        ZStack {
            CatCalBackground()

            VStack(spacing: CatCalSpacing.lg) {
                Spacer()

                CatBuddyImage(height: 150)

                VStack(spacing: CatCalSpacing.sm) {
                    Text("Connect your other calendars")
                        .font(CatCalFont.largeTitle(28))
                        .foregroundStyle(CatCalColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("CatCal already reads whatever you've added in iOS Settings. Connect an account directly to pull it in even if you haven't.")
                        .font(CatCalFont.body(16))
                        .foregroundStyle(CatCalColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: CatCalSpacing.sm + 2) {
                    ForEach(sources, id: \.sourceID) { source in
                        ConnectButton(
                            source: source,
                            isBusy: busyProvider == source.provider,
                            action: { connect(source) }
                        )
                    }
                }

                Button("Skip for now", action: onFinish)
                    .font(CatCalFont.body(16))
                    .foregroundStyle(CatCalColor.textSecondary)
                    .padding(.bottom, CatCalSpacing.lg)
            }
            .padding(.horizontal, CatCalSpacing.xl)
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

    private func connect(_ source: any ConnectableCalendarSource) {
        Task {
            busyProvider = source.provider
            defer { busyProvider = nil }

            do {
                let email = try await source.connect()
                aggregator.register(source)
                ConnectedAccountStore.upsert(
                    provider: source.provider,
                    accountEmail: email,
                    context: modelContext
                )
                // One connection is enough to move on; the rest can be added
                // later from Profile.
                onFinish()
            } catch CalendarSourceError.cancelled {
                // Backing out of the sheet leaves them on this step.
            } catch {
                errorMessage = (error as? CalendarSourceError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }
}

private struct ConnectButton: View {
    let source: any ConnectableCalendarSource
    let isBusy: Bool
    let action: () -> Void

    private var tint: Color { source.provider.eventSource.tagColor }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CatCalSpacing.sm) {
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                }

                Text(source.hasConnectedAccount ? "\(source.displayName) connected" : "Connect \(source.displayName)")
                    .font(CatCalFont.headline(17))
            }
            .foregroundStyle(source.hasConnectedAccount ? CatCalColor.sourceSuccess : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .catCalGlassCard(cornerRadius: CatCalRadius.pill)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || source.hasConnectedAccount || !source.isConfigured)
        .opacity(source.isConfigured ? 1 : 0.5)
    }
}

#Preview {
    ConnectCalendarsView(onFinish: {})
        .environment(CalendarAggregator(sources: [EventKitCalendarSource()]))
        .environment(GoogleCalendarSource())
        .environment(MicrosoftCalendarSource())
        .modelContainer(for: [AppTask.self, UserProgress.self, Achievement.self, Cosmetic.self, ConnectedAccount.self], inMemory: true)
}
