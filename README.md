# CatCal

One unified view of your day across Google, Outlook, and iCloud — with a cat
who levels up as you get things done.

iOS 26, SwiftUI, SwiftData + CloudKit. The Xcode project is generated from
`project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen), so the
project structure stays diffable.

## Building

```sh
brew install xcodegen      # once
xcodegen generate
xcodebuild -scheme CatCal -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Direct calendar connections — setup required

CatCal reads every calendar you've added in iOS Settings automatically. It can
*also* connect to Google and Outlook directly over OAuth, which needs a client
ID from each provider's console. **`project.yml` currently ships placeholders**
(`YOUR_GOOGLE_CLIENT_ID`, `YOUR_MICROSOFT_CLIENT_ID`), so those rows on the
Calendar Sources screen show as not configured until you replace them.

Neither client ID is a secret — public OAuth client IDs are designed to ship
inside the app binary. Both are safe to commit.

### Google

1. [console.cloud.google.com](https://console.cloud.google.com) → create or
   select a project.
2. APIs & Services → Library → enable **Google Calendar API**.
3. APIs & Services → OAuth consent screen → fill in app name and support
   email. "Testing" publish status is fine for personal use; add your own
   Google account under Test users. (Unverified apps in Testing mode make you
   re-consent roughly every 7 days — worth knowing so it doesn't look broken
   later.)
4. Credentials → Create Credentials → OAuth client ID → type **iOS** → bundle
   ID `com.valkolimark.catcal`.
5. Copy the two values into `project.yml` under the CatCal target's
   `info.properties`:
   - **Client ID** → `GIDClientID`
   - **iOS URL scheme** (the reversed client ID,
     `com.googleusercontent.apps.…`) → the `CFBundleURLSchemes` entry
6. `xcodegen generate` and rebuild.

### Microsoft / Outlook

1. [portal.azure.com](https://portal.azure.com) → Microsoft Entra ID → App
   registrations → New registration.
2. Under **Supported account types**, choose "Accounts in any organizational
   directory and personal Microsoft accounts" — this is what lets both
   work/school Outlook *and* regular Outlook.com accounts sign in.
3. Add a platform → iOS/macOS → bundle ID `com.valkolimark.catcal`. Azure
   generates the redirect URI (`msauth.com.valkolimark.catcal://auth`), which
   `project.yml` already registers.
4. API permissions → Add a permission → Microsoft Graph → Delegated →
   **Calendars.Read**. No admin consent needed for personal delegated use.
5. Copy the **Application (client) ID** into `project.yml` as `MSALClientID`.
6. `xcodegen generate` and rebuild.

## Cat artwork

`Sources/Resources/Assets.xcassets/CatBuddy.imageset` is empty. Drop 1x/2x/3x
PNGs onto it in Xcode and every screen picks them up — `CatBuddyImage` falls
back to an SF Symbol until then, so layout is already correct either way.

## Simulator affordances (DEBUG only)

Sign in with Apple is unreliable in the Simulator and there's no real calendar
account there, so debug builds accept these launch arguments:

| Argument | Effect |
| --- | --- |
| `-skipAuth` | Drop straight into the tab shell as the mock user |
| `-seedSampleData` | Seed sample tasks and a stub calendar source; skips onboarding |
| `-startTab <today\|tasks\|buddy\|profile>` | Open on a given tab |
| `-openCalendarSources` | Push Profile straight to Calendar Sources |

```sh
xcrun simctl launch booted com.valkolimark.catcal -skipAuth -seedSampleData -startTab tasks
```

All of it is compiled out of release builds.
