# Deep pre-submit review, 1.0.4 (build 13), 2026-11-08

Base: `origin/main` at `fb3fef1` (1.0.4 build 13). Live version: 1.0.3
(`5f8928b`). The 1.0.3 to 1.0.4 app diff was reviewed on
`review/2026-11-07-sunset` (no fixes, three P2s). This pass reads every code
path a user can reach on main, not only the diff: purchase, restore,
onboarding, persistence and decoding of saved data, notifications, the
widget, background refresh, iPhone Duo layouts and localization.

## Findings

| Severity | Where | What happens | Status |
|---|---|---|---|
| P1 | `Sunset/Views/TodayView.swift:224` | Free accounts get today and tomorrow, and the Outlook blurs every later day behind Sun+. Today's "Up next" took the next two watched shows with no limit, so a free user watching only sunsets (or only sunrises) saw the day after tomorrow's score there, and could open its full detail, while the Outlook showed that same day locked. | Fixed: free Up next stops at the last free day's sunset, the same cut the Duo capture uses. Test `PresubmitDeepFixTests.testFreeUpNextStopsAtTheOutlooksFreeDays`. |
| P2 | `Shared/Services/NotificationService.swift:94` | Alert triggers were built from wall-clock components in the forecast's zone but carried no zone, so iOS read them in the device's zone. When the two differ (phone on a manual or other zone, a coordinate near a zone border, or a background refresh for the cached place after travel) the alert fired hours away from the moment `plan` computed, while its text named the right time. | Fixed: the components carry the forecast's zone. Test `PresubmitDeepFixTests.testAlertTriggerFiresAtThePlannedInstantInTheForecastZone` checks `nextTriggerDate()` against a zone that is not the device's. |
| P2 | `Shared/Services/AlertSettings.swift:108` | Carried from the 2026-11-07 review: alerts on with iOS permission `.notDetermined` (device restore) schedules nothing and shows no blocked state. | Not fixed: pre-existing and rare; see that review. |
| P2 | `Sunset/Views/SettingsView.swift:95` | "Update location" installs a `force: true` fix handler that stays for the session, so every later foreground fix refetches the forecast and rebuilds alerts instead of using the 3 hour cache. Extra network calls only; nothing the user sees is wrong. | Not fixed: no user-visible defect. |
| P2 | `Shared/Services/LocationService.swift:82` | When reverse geocoding fails (offline) after a move, the new fix keeps the old town name, so Today and Settings label the new place's forecast with the previous town until the next successful geocode. | Not fixed: needs a copy decision (blank name or "Your location"). |
| P2 | `Shared/Services/BackgroundRefresh.swift:31` | A background launch never calls `StoreService.start()`, so alerts rebuilt there use the cached Sun+ flag. A lapsed subscriber keeps sky event alerts and a custom score until the next foreground launch re-verifies. | Not fixed: bounded by the next app open; verifying in the background would mean configuring RevenueCat there. |
| P2 | `Shared/Utilities/SunsetFormat.swift:59` | The app is English only, but weekday and month formatters follow the device locale, so a German device reads "Montag's sunset" in English copy. Cosmetic. | Not fixed: localization scope decision. |
| P2 | `Sunset/Info.plist` (`NSLocationWhenInUseUsageDescription`) | Says "nothing is stored", while the rounded fix is cached in the App Group for the widget (AGENTS.md allows that). Wording only. | Not fixed: copy change, not a code defect. |

## Checked, no issue

- Crashes: no force unwraps on optional data in app code (the only `!`s are
  constant URLs). `PaneCut.blocks` indexes `parts[0]` of a non-empty
  dictionary group. `DemoForecast` indexing is `#if DEBUG` only. Score,
  humidity and visibility conversions are finite (JSON cannot carry NaN, and
  missing values fall back to defaults).
- Saved data: the forecast snapshot is versioned (`sunset.forecast.v2`) and
  decoded with `try?`, so an old shape is dropped, not fatal. Settings are
  plain `UserDefaults` with defaults for missing keys; no SwiftData or Core
  Data. `OpenMeteoPoint` treats the newer hourly arrays as optional.
- Concurrency: every service is `@MainActor`; CoreLocation and RevenueCat
  delegate callbacks hop to the main actor; the BGAppRefresh handler is
  registered on `.main` (the build 2 crash fix) and its expiration handler
  is `@Sendable`. Superseded forecast loads are discarded by generation.
- Purchase: offering `default` with fallback to current; packages sorted
  lifetime, yearly, monthly. Onboarding buys monthly (yearly fallback), shows
  "See Sun+ plans" after 6 s with no products, and never names a trial the
  account is not eligible for. The paywall closes on purchase, restore or an
  approved Ask to Buy, has Close, Restore, Terms (Apple EULA) and Privacy.
  `isPro` is cleared only by an active-entitlement read, never by an offline
  failure. Debug overrides (`-DemoPro`, `-DemoRestore`, the Settings toggle)
  are compiled out of Release.
- Onboarding: double taps are blocked across page changes, finish is
  idempotent, the location prompt waits for the welcome tap, and the
  notification prompt is the first notification query.
- Notifications: every rebuild clears all `sunset.alert.` requests first and
  rebuilds are serialized, so nothing is scheduled twice; identifiers are per
  show and day. Free accounts always use 70 and 45 minutes.
- Widget: reads the same App Group watch set and Pro flag, fetches itself
  when stale, rolls to the next show 31 minutes after the current one, and
  every app fetch or watch change reloads it.
- iPhone Duo: the Outlook tab leaves the bar while split and selection moves
  off it; a pick in the trailing pane opens on Today; folding only moves
  frames.
- App Review: no prices in copy, no other-platform links, no health claims,
  no debug UI in Release, review prompt is a direct `requestReview()` once.

## Fixes

1. `fix(alerts): schedule triggers in the forecast's time zone`
2. `fix(today): keep free Up next inside the Outlook's free days`

The Android port (`android/`) has its own Up next; it was not changed here.

## Tests

See the run line below.
