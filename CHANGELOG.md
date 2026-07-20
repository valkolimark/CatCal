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

### Changed

- Today's "tasks left today" teaser card now switches to the Tasks tab instead of pushing a nested `TasksView` onto Today's own navigation stack.
- `TasksView` now renders pending/completed rows as a scrolling stack of glass cards instead of a `List`, to let Liquid Glass apply cleanly.
- All SwiftData model properties now carry default values, as CloudKit requires for non-optional attributes.
- Dropped `@Attribute(.unique)` from `Achievement.id` and `Cosmetic.id` — CloudKit-backed stores don't support uniqueness constraints. `AchievementEngine.seedIfNeeded` already guards duplicates by fetching existing IDs first.
- Profile's sign-out stub is now a real sign-out, behind a confirmation dialog.

### Fixed
