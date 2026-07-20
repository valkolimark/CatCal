# CatCal — Claude Code build prompts

How to use this: open Claude Code in an empty local folder, paste in **one cycle at a time**, let it finish, review the diff, then move to the next. Don't paste multiple cycles at once — small, reviewable steps are what makes agentic coding actually work.

Before Cycle 0, make sure git on your machine can already push to `https://github.com/valkolimark/CatCal` (SSH key added to GitHub, or run `gh auth login`). Claude Code will use your local credentials — it can't authenticate on its own.

## The cycle ritual

Every prompt below ends with "follow the cycle ritual." That means:

1. Build the project and fix any errors or warnings before calling the cycle done.
2. Update `CHANGELOG.md` under `## [Unreleased]`, in the right Added/Changed/Fixed subsection, with a one-line description of what this cycle added.
3. `git add -A && git commit` with a Conventional Commits message (`feat: ...`, `fix: ...`, `chore: ...`).
4. `git push`.

Copy the `CHANGELOG.md` file (provided alongside this one) into the project root before Cycle 0 — use it as-is rather than generating a new one.

---

## Cycle 0 — Repo and project bootstrap

We're starting a new iOS app called CatCal from scratch. Set up the project:

- Check for Xcode command line tools and XcodeGen (`xcodegen --version`). If XcodeGen isn't installed, install it via Homebrew (`brew install xcodegen`) — we're using it so the project structure stays in a diffable `project.yml` instead of a binary `.xcodeproj`.
- Create `project.yml` describing a SwiftUI iOS app target named CatCal, bundle id `com.valkolimark.catcal` (ask me if this should be different), deployment target iOS 26.0, Swift 6. Add `NSCalendarsUsageDescription` to Info.plist explaining we read the user's calendars to build a unified view.
- Run `xcodegen generate` and confirm it builds: `xcodebuild -scheme CatCal -destination 'generic/platform=iOS Simulator' build`.
- Create the source layout: `Sources/App/`, `Sources/Models/`, `Sources/Services/`, `Sources/Views/`, `Sources/Resources/`.
- `git init`, add a `.gitignore` for Xcode/Swift (`.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`, `.swiftpm/`), add remote `origin` → `https://github.com/valkolimark/CatCal.git`, commit, push to `main`.

Follow the cycle ritual.

## Cycle 1 — Data layer and mock identity

Add the core SwiftData models. Every model gets an `ownerID: String` field even though auth is mocked for now — use a hardcoded UUID stored via a small `CurrentUser` helper behind an `AuthServiceProtocol` (with `currentUserID: String`), so we can swap in real Sign in with Apple later without touching the models.

Models:
- `AppTask`: title, notes, dueDate (optional), isCompleted, xpValue, ownerID
- `UserProgress`: ownerID, totalXP, currentLevel, currentStreak, lastActiveDate
- `Achievement`: id, title, description, isUnlocked, unlockedDate, ownerID
- `Cosmetic`: id, name, category (e.g. "collar"), isUnlocked, ownerID

Add `Services/ProgressEngine.swift` with an XP → level curve (pick something sensible, e.g. level N needs N × 150 cumulative XP) and a stage lookup mapping level to one of five cat growth stages: Newborn (1–4), Kitten (5–9), Teen cat (10–16), Adult (17–25), Majestic (26+).

Write unit tests for the XP/level math.

Follow the cycle ritual.

## Cycle 2 — Unified calendar (EventKit) + Today screen

- `Services/CalendarService.swift` wrapping EventKit: request calendar access, fetch today's events across every calendar the user has added in iOS Settings (Google/Outlook/iCloud all surface there automatically once added as system accounts), return a merged, time-sorted list.
- Categorize each event as Google / Outlook / iCloud based on the underlying account type where detectable, defaulting to iCloud styling otherwise.
- Build `Views/TodayView.swift`: date header, a streak pill (flame icon + streak count) top-right, a stacked list of event cards with a colored left accent bar and small source tag (Google = accent/blue, Outlook = pro/purple, iCloud = success/green), and a "X tasks left today" teaser card at the bottom linking to Tasks.
- Handle the permission-denied state with a clear empty state and a button that opens Settings.

Follow the cycle ritual.

## Cycle 3 — Tasks

Build `Views/TasksView.swift` backed by `AppTask`:

- Pending tasks: circular checkbox, title, small "+N XP" tag.
- A "Completed" section below: filled checkmark circle, strikethrough title, muted XP tag.
- Completing a task awards XP via `ProgressEngine`, animates the checkbox, and moves the row into Completed.
- An "Add task" button opens a simple sheet (title, optional due date, XP defaulting to 5, or 10 if a due date is set).

Follow the cycle ritual.

## Cycle 4 — Gamification feedback layer

- When `ProgressEngine` reports a level-up, show a celebratory moment (lightweight full-screen overlay or sheet) — mention it if a new cat stage or cosmetic unlocked too.
- Add a haptic + small XP toast whenever a task is completed.
- Seed a first pass of ~8 achievements (e.g. "Connect your first calendar," "7-day streak," "100 tasks completed," "Connect all three calendar sources") that unlock a named `Cosmetic` on trigger. Just wire the trigger/unlock logic for now — the full achievements screen comes later.

Follow the cycle ritual.

## Cycle 5 — Cat companion

Build `Views/CompanionView.swift`:

- Header: cat's name, current stage name (e.g. "Kitten stage"), level pill.
- Center: a circular avatar area for the cat (placeholder shape/icon is fine — real art comes later) and a mood line driven by today's state (no overdue tasks → "Feeling great today"; overdue tasks → something gentler, e.g. "Ready when you are").
- XP progress bar toward the next level.
- A 2-column "Collars" cosmetics grid: unlocked items shown normally, locked ones dimmed with a lock icon and the achievement name needed.
- Wire all of it to the real `ProgressEngine`/`Achievement`/`Cosmetic` data — no placeholder numbers.

Follow the cycle ritual.

## Cycle 6 — Onboarding + navigation shell

- Root `TabView` with four tabs: Today, Tasks, Buddy, Profile (Profile can be a minimal placeholder for now — app version + a sign-out stub).
- Three-step onboarding shown on first launch only: meet your companion → connect your calendars → level up together. Store `hasCompletedOnboarding` in UserDefaults.
- Onboarding's final step triggers the Cycle 2 calendar-permission request.

Follow the cycle ritual.

## Cycle 7 — Liquid Glass pass + sound/haptics

- Apply `.glassEffect()` to the Today event cards, Tasks rows, and tab bar area, using `GlassEffectContainer` where multiple glass elements sit together (iOS 26 Liquid Glass API). Gate with `#available(iOS 26, *)`, falling back to `.ultraThinMaterial` on earlier versions.
- Add sound via AVFoundation: a soft chime + short "mew" on task completion, a fanfare + stretch sound on level-up, a gentle loopable purr (muteable) while the Buddy screen is open. Respect the silent switch; add a mute toggle in Profile.

Follow the cycle ritual.

## Cycle 8 — CloudKit sync

- Enable the CloudKit capability and configure the SwiftData models to sync via a CloudKit container (`ModelConfiguration(cloudKitDatabase:)`).
- No new UI needed — this should be invisible to the user. Last-write-wins conflict resolution is fine for v1 (leave a code comment noting this as a known simplification).
- Verify by confirming progress survives a delete/reinstall in the simulator under the same iCloud account.

Follow the cycle ritual.

## Cycle 9 — Sign in with Apple

Replace the Cycle 1 mock `AuthServiceProtocol` implementation with a real one:

- Implement Sign in with Apple via `AuthenticationServices` (`ASAuthorizationAppleIDProvider`), store the stable user identifier in the Keychain, and use it as `ownerID` going forward — migrate any existing mock-user data to the real ID on first real sign-in.
- Build the sign-in screen matching our earlier mockup: paw logo, "Welcome back" heading, "Continue with Apple" as the primary and only enabled button for now. Leave "Continue with Google" and "Continue with email" visible but disabled with a "coming soon" state.
- Gate the TabView behind successful sign-in.

Follow the cycle ritual.

---

## Backlog (not cycles yet — pull from here later)

- Google Sign-In SDK
- Email/password auth (needs a backend — Firebase Auth is the fastest path)
- Full achievements screen
- Streak freeze tokens
- Home screen + lock screen widgets, Live Activity for "next meeting in"
- Real cat artwork/animation to replace the placeholder icon
