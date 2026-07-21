# CatCal — Phase 2 build prompts: direct calendar connections

Continues from `PROMPTS.md` (Cycles 0–9, complete). This phase adds the backlog item: real in-app "Connect Google" / "Connect Outlook" OAuth, pulling events directly from the Google Calendar API and Microsoft Graph API — independent of whatever's synced through iOS Settings via EventKit.

Same rules as before: paste **one cycle at a time** into Claude Code, review the diff, then move on. Every cycle still ends with the cycle ritual (build clean → update `CHANGELOG.md` → commit → push).

---

## Before Cycle 10 — console setup (do this yourself, in a browser)

Claude Code can't do these steps — they're tied to your own Google/Microsoft accounts.

### Google Cloud Console
1. Go to console.cloud.google.com → create or select a project.
2. APIs & Services → Library → enable **Google Calendar API**.
3. APIs & Services → OAuth consent screen → fill in app name/support email. Since this is just for your own device, "Testing" publish status is fine — just add your own Google account under Test users (unverified apps in Testing mode also require re-consent roughly every 7 days, worth knowing so it doesn't look broken later).
4. Credentials → Create Credentials → OAuth client ID → type **iOS** → bundle ID `com.valkolimark.catcal`.
5. Note the **Client ID** and the **iOS URL scheme** (reversed client ID, looks like `com.googleusercontent.apps.XXXXX`) shown after creation — Cycle 11 needs both.

### Azure Portal (Entra ID)
1. Go to portal.azure.com → Microsoft Entra ID → App registrations → New registration.
2. Name it (e.g. "CatCal iOS"). Under **Supported account types**, choose "Accounts in any organizational directory and personal Microsoft accounts" — this is what lets both work/school Outlook *and* regular Outlook.com accounts sign in.
3. Add a platform → iOS/macOS → bundle ID `com.valkolimark.catcal`. Azure will generate the redirect URI for you (`msauth.com.valkolimark.catcal://auth`).
4. API permissions → Add a permission → Microsoft Graph → Delegated → **Calendars.Read**. No admin consent needed for personal delegated use.
5. Note the **Application (client) ID** — Cycle 12 needs it. Neither client ID is a secret; both are safe to commit.

---

## Cycle 10 — Calendar source abstraction + aggregator

Refactor before adding new sources, so Google and Microsoft plug into the same seam instead of forking the merge logic.

- Define `protocol CalendarSourceProviding` in `Services/CalendarSourceProviding.swift`: `var sourceID: String`, `var displayName: String`, `var isConnected: Bool`, `func fetchEvents(from: Date, to: Date) async throws -> [UnifiedEvent]`.
- Rename/refactor the existing EventKit logic into `Services/EventKitCalendarSource.swift` conforming to this protocol. No behavior change yet.
- Add `Services/CalendarAggregator.swift`: holds `[CalendarSourceProviding]`, fetches from all connected sources concurrently (`withThrowingTaskGroup`), merges and time-sorts into one list, and surfaces per-source fetch failures without one bad source blanking the whole view.
- Update `TodayView` to pull from `CalendarAggregator` instead of calling EventKit directly.
- Add `ConnectedAccount` SwiftData model: `id`, `ownerID`, `provider` (enum: `.google`/`.microsoft`), `accountEmail`, `connectedDate`, `enabledCalendarIDs: [String]`.
- Unit tests for the aggregator's merge/sort and partial-failure handling.

Follow the cycle ritual.

---

## Cycle 11 — Google Calendar connect

- Add `GoogleSignIn-iOS` via Swift Package Manager: `https://github.com/google/GoogleSignIn-iOS`.
- Info.plist: add `GIDClientID` with the client ID from setup, and add the reversed-client-ID URL scheme to `CFBundleURLTypes`.
- `Services/GoogleCalendarSource.swift` conforming to `CalendarSourceProviding`:
  - `connect()`: `GIDSignIn.sharedInstance.signIn(withPresenting:)`, requesting the `https://www.googleapis.com/auth/calendar.readonly` scope. GoogleSignIn persists and refreshes tokens on its own — no custom Keychain code needed here.
  - On launch, call `restorePreviousSignIn()` so the connection survives app relaunch.
  - `fetchEvents()`: REST calls to `GET /calendar/v3/users/me/calendarList` (to list calendars) and `GET /calendar/v3/calendars/{id}/events` with `timeMin`/`timeMax`, using the access token from `GIDGoogleUser`. Decode into `UnifiedEvent`, tagged Google-blue.
  - `disconnect()`: `GIDSignIn.sharedInstance.signOut()`, delete the `ConnectedAccount` row.
  - Surface a clear "reconnect" state if a call comes back 401 (revoked/expired).
- UI: add a "Calendar Sources" section (new screen or extend Settings) listing iCloud (always active, no action) and a **Connect Google Calendar** row. On success, show the connected email and a per-calendar toggle list sourced from `calendarList`.
- Wire the connected `GoogleCalendarSource` into `CalendarAggregator`.

Follow the cycle ritual.

---

## Cycle 12 — Outlook (Microsoft Graph) connect

Mirrors Cycle 11 — keep the UI pattern identical so the two providers feel like one system, not two bolted-on flows.

- Add `MSAL` via SPM: `https://github.com/AzureAD/microsoft-authentication-library-for-objc`.
- Info.plist: `CFBundleURLTypes` entry for `msauth.com.valkolimark.catcal`, plus `LSApplicationQueriesSchemes` for `msauthv2` and `msauthv3`.
- `Services/MicrosoftCalendarSource.swift` conforming to `CalendarSourceProviding`:
  - `connect()`: build `MSALPublicClientApplication` with the client ID from setup and the `common` authority (supports both work/school and personal accounts), `acquireToken(with:)` requesting `Calendars.Read`. Use `acquireTokenSilent` on subsequent launches — MSAL also handles its own Keychain-backed token cache.
  - `fetchEvents()`: `GET https://graph.microsoft.com/v1.0/me/calendarView?startDateTime=…&endDateTime=…` with the bearer token; `GET /me/calendars` for the per-calendar list. Decode into `UnifiedEvent`, tagged Outlook-indigo.
  - `disconnect()`: remove the account via MSAL's account API, delete the `ConnectedAccount` row.
- Add the matching **Connect Outlook** row next to Google in the Calendar Sources screen, same connected-state/toggle/disconnect pattern.
- Wire into `CalendarAggregator`.

Follow the cycle ritual.

---

## Cycle 13 — Manage Calendars screen + duplicate-source warning

- Build `Views/ManageCalendarsView.swift` with three sections: iCloud/EventKit (list individual calendars via `EKEventStore.calendars(for: .event)`, each with a toggle bound to a stored "hidden calendar IDs" set), Google, and Outlook — the latter two reusing the per-calendar toggle UI from Cycles 11–12.
- Duplicate-source check: if a connected Google/Outlook account's email matches an account EventKit already surfaces (by comparing account type/email), show an inline note — "This account is already syncing through iOS Settings — connecting it directly may cause duplicate events" — with a one-tap option to hide that source's EventKit calendars.
- Add an entry point to this screen from Settings/Profile.
- Extend onboarding: after the Sign in with Apple step, add an optional "Connect your other calendars" screen with Google / Outlook / Skip buttons, reusing the Cycle 11–12 connect flows.

Follow the cycle ritual.

---

## Model recommendation

Sonnet 5 for Cycles 10 and 13 (refactoring and UI work, low ambiguity). **Opus for Cycles 11 and 12** — OAuth SDK config (Info.plist entries, URL schemes, token scopes) is the same kind of fiddly, hard-to-debug-blind territory as Cycle 9's Sign in with Apple, and worth the extra care.
