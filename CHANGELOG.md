# Changelog

All notable changes to CatCal are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Project bootstrap via XcodeGen: SwiftUI iOS app target `CatCal` (bundle id `com.valkolimark.catcal`, iOS 26.0, Swift 6), `CatCalTests` unit test target, and source layout under `Sources/{App,Models,Services,Views,Resources}`.
- Design system foundation (`Theme.swift`): brand color palette with light/dark variants, calendar source tags (Google/Outlook/iCloud), rounded type scale, spacing and radius tokens.
- App icon and color asset catalog.
- SwiftData models: `AppTask`, `UserProgress`, `Achievement`, `Cosmetic`, each with an `ownerID`.
- `AuthServiceProtocol` + `CurrentUser` mock identity helper, so real auth can drop in later without touching models.
- `ProgressEngine`: flat 150 XP/level curve and a level → cat growth stage lookup (Newborn/Kitten/Teen cat/Adult/Majestic), with unit tests.
- `CalendarService` wrapping EventKit: requests calendar access, merges today's events across every account the user has added in Settings, and best-effort classifies each as Google/Outlook/iCloud.
- `TodayView`: date header, streak pill, event cards with a colored source accent bar and tag, a "tasks left today" teaser card, and a permission-denied empty state with a link to Settings. Now the app's root screen.
- `TasksView`: pending/completed sections with animated checkbox completion, XP tags, and an "Add Task" sheet (title, optional due date, XP defaults to 5 or 10 with a due date). Completing a task awards XP through `ProgressEngine`. Wired up as the destination from Today's tasks teaser card.
- `GamificationCenter`: app-wide coordinator for the level-up celebration overlay (mentions stage changes and unlocked achievements/cosmetics) and a haptic + XP toast on task completion.
- `AchievementEngine` + an 8-achievement catalog (first calendar connected, all three sources connected, first task, 100 tasks, 7-day streak, 30-day streak, Teen stage, Majestic stage), each unlocking a named `Cosmetic`. Trigger/unlock logic is wired into Tasks and Today; the achievements screen itself comes later.
- `ProgressEngine.updateStreak`: daily streak tracking (extend on a consecutive day, reset on a gap), with unit tests.
- `CompanionView`: cat name/stage/level header with a stage-tinted avatar ring, a mood line driven by whether any task is overdue, an XP progress bar to the next level, and a 2-column Collars grid (locked cells dimmed with the achievement name needed). All wired to real `ProgressEngine`/`Achievement`/`Cosmetic` data.
- `UserProgress.catName`, defaulting to "Whiskers" — no cycle had introduced a place to name the cat yet, but Cycle 5's header needs one.
- `RootTabView`: four-tab shell (Today, Tasks, Buddy, Profile). `ProfileView` placeholder with app version and a sign-out stub.
- Three-step onboarding (`OnboardingView`), shown once via `hasCompletedOnboarding` in `UserDefaults`; its final step triggers the calendar-permission request.
- Liquid Glass pass: Today's event cards and Tasks rows use `.glassEffect()` (grouped under `GlassEffectContainer`) on iOS 26, falling back to `.ultraThinMaterial` on earlier versions via the new `catCalGlassCard()` helper. The tab bar gets Liquid Glass automatically from the system on iOS 26.
- `SoundService`: a soft chime + "mew" on task completion, a fanfare + stretch whoosh on level-up, and a loopable purr while the Buddy screen is open — all synthesized placeholder effects (`Sources/Resources/Sounds/`) played via AVFoundation with the `.ambient` session category so they respect the silent switch. Added a "Mute Sounds" toggle in Profile.
- CloudKit sync: SwiftData now persists through the private CloudKit database (`iCloud.com.valkolimark.catcal`) via `ModelConfiguration(cloudKitDatabase:)`, with the iCloud/CloudKit entitlement and a `remote-notification` background mode. Invisible to the user — no new UI. Conflict resolution is CloudKit's default last-write-wins, noted in `Persistence.swift` as a known v1 simplification.
- `Persistence.makeModelContainer()` falls back to a local-only store when the CloudKit container can't be opened (no iCloud account, or a build without the container provisioned), so the app stays usable offline instead of crashing at launch.
- Tests covering the schema: no model may declare a uniqueness constraint (CloudKit rejects them), the schema covers all four models, and models round-trip through a container.
- Sign in with Apple via `AuthenticationServices`, replacing the Cycle 1 mock auth. `SessionController` stores Apple's stable user identifier in the Keychain, re-checks the credential with Apple on launch (signing out if it was revoked), and exposes sign-out.
- `SignInView`: paw logo, "Welcome back" heading, and "Continue with Apple" as the only enabled option; "Continue with Google" and "Continue with email" are visible but disabled with a coming-soon state. The `TabView` is gated behind a successful sign-in.
- First real sign-in migrates any records created beforehand from the mock `ownerID` onto the real Apple identifier, scoped to the mock ID so a second Apple ID on a shared device can never absorb the first user's data. Covered by tests, including that safety property.
- `CalendarSourceProviding`: the seam every calendar backend plugs into (`sourceID`, `displayName`, `isConnected`, `fetchEvents(from:to:)`, `availableCalendars()`), plus the provider-neutral `UnifiedEvent` and `SourceCalendar` types. Adding a provider is now a conformance rather than a fork of the merge logic.
- `CalendarAggregator`: fans a date range out across every connected source concurrently and merges the results into one deduplicated, time-sorted list. A source that throws contributes a `CalendarSourceFailure` and drops out of the merge — one bad source can't blank the day. Covered by tests for merge/sort order, partial failure, reconnect-required errors, and dedup.
- `ConnectedAccount` SwiftData model (+ `ConnectedAccountStore`) recording direct Google/Microsoft OAuth connections: provider, account email, connected date, and which of that account's calendars are enabled. No tokens are stored here — the OAuth SDKs keep their own Keychain caches.
- `HiddenCalendars`: device-local (`UserDefaults`) per-source record of which calendars the user has switched off.
- `CatCalBackground`: the shared sky gradient — pale blue easing to near-white at the horizon, warmed by an off-screen sun — now behind every screen. Glass surfaces need variation underneath to read as glass.
- Shared UI components: `ScreenHeader` (large title, subtitle, trailing glass pill), `StatPill`, `TintedChip`, `CatBuddyImage`, `FloatingTabBar`, `SettingsCard`/`SettingsLabel`.
- `CatBuddy` image set for the cat illustration on Today, Tasks, Buddy, onboarding and sign-in. Empty for now — drop 1x/2x/3x PNGs onto it in Xcode and `CatBuddyImage` picks them up with no code change; until then it falls back to an SF Symbol so layout is already correct.
- Debug-only `-seedSampleData` and `-startTab <tab>` launch arguments (alongside the existing `-skipAuth`) for checking a populated screen against its design in the Simulator. Compiled out of release builds.

- Direct Google Calendar connection: `GoogleCalendarSource` signs in through the GoogleSignIn SDK (added via SPM), requests the read-only calendar scope, and reads `calendarList`/`events` from the Calendar v3 API into `UnifiedEvent`s. Tokens stay in GoogleSignIn's own Keychain cache — none are handled here. Restores the previous sign-in at launch, and reports a 401 as "reconnect" rather than a generic failure.
- `CalendarSourcesView`, reachable from Profile: iPhone Calendars (always on), plus a Google row that connects, shows the signed-in email, lists per-calendar toggles, and disconnects behind a confirmation.
- `ConnectableCalendarSource` protocol so a provider gets a connect/disconnect/toggle UI by conforming, rather than by growing the screen a second branch.
- `OAuthConfig`, which reads the client IDs from `Info.plist` and detects unreplaced placeholders, so an unconfigured build shows "not set up yet" instead of starting a sign-in that can only fail.
- `README.md` with the Google Cloud Console and Azure Portal setup steps, and the debug launch arguments.
- Direct Outlook connection: `MicrosoftCalendarSource` signs in through MSAL (added via SPM) against the `common` authority, so both work/school and personal Microsoft accounts work, and reads `me/calendarView`/`me/calendars` from Microsoft Graph. MSAL owns the Keychain-backed token cache and silent refresh; `acquireTokenSilent` handles later launches. Registered the `msauth.com.valkolimark.catcal` URL scheme and the `msauthv2`/`msauthv3` query schemes so MSAL can hand off to Microsoft Authenticator when it's installed.
- Outlook appears on the Calendar Sources screen through the same `ConnectableCalendarSource` row as Google — one code path, so the two providers stay in step.
- `ProviderDateParsing`, covering the two providers' awkward date formats — Google's all-day dates resolve in the device's zone rather than UTC (so an all-day event doesn't slip a day), and Graph's zone-less local times get recombined with their named zone and their seven fractional digits trimmed. Ten tests over both.

### Changed

- Visual revamp to match the new design comps. The palette moves off coral onto an action blue, with a near-navy text color, green XP chips, and retuned Google/Outlook/iCloud source colors; `XPGold` is now reserved for celebration moments and the Buddy progress bar. Cards gained a hairline highlight and a soft drop shadow so they lift off the sky.
- Every top-level screen now opens with the same large left-aligned title, subtitle, and trailing glass pill, on a shared 20pt gutter.
- The system tab bar is replaced by a custom floating glass `FloatingTabBar` (Today/Tasks/Buddy/Profile), so the cat illustration can sit behind it and the selected tab can carry a solid pill. Still a `TabView` underneath with its own bar hidden, which keeps each tab's view state and navigation stack alive across switches.
- Today's event cards show a full time range and a rounded source accent bar; the tasks teaser is a glass card with a clipboard tile and chevron. Tasks' "Add task" is a full-width row in the list rather than a toolbar button.
- Profile is a stack of glass setting cards instead of a `List`; onboarding and sign-in moved off the coral/indigo gradient onto the shared sky.
- `CalendarService` is now `EventKitCalendarSource`, one `CalendarSourceProviding` implementation among several rather than the only path to calendar data. `TodayView` pulls from `CalendarAggregator` instead of calling EventKit directly.
- Today no longer replaces the whole screen with the permission-denied state when EventKit access is off — it does so only when nothing else is feeding it events, so a directly connected Google/Outlook account still shows a day. Per-source failures surface as inline banners above the event list.

- Today's "tasks left today" teaser card now switches to the Tasks tab instead of pushing a nested `TasksView` onto Today's own navigation stack.
- `TasksView` now renders pending/completed rows as a scrolling stack of glass cards instead of a `List`, to let Liquid Glass apply cleanly.
- All SwiftData model properties now carry default values, as CloudKit requires for non-optional attributes.
- Dropped `@Attribute(.unique)` from `Achievement.id` and `Cosmetic.id` — CloudKit-backed stores don't support uniqueness constraints. `AchievementEngine.seedIfNeeded` already guards duplicates by fetching existing IDs first.
- Profile's sign-out stub is now a real sign-out, behind a confirmation dialog.

### Fixed
