# Pre-submit review, 1.0.4 (build 12), 2026-11-07

Live version: 1.0.3 (builds 10 and 11, App Store Connect "ready for
distribution"). Base: `5f8928b` (build 11, last commit at 1.0.3). Head:
`7c68174` (1.0.4 build 12). App sources only, not docs, fastlane or tests.

Changed files: `Shared/Services/AlertSettings.swift`, `ForecastStore.swift`,
`NotificationService.swift`, `StoreService.swift`, `Sunset/App.swift`,
`Sunset/Views/OnboardingView.swift`, `PaywallView.swift`, `SettingsView.swift`,
`TodayView.swift`, `project.yml` (version and build only). Every app change is
one of the eight fixes from the 2026-11-06 state machine audit.

## Findings

| Severity | Where | What happens | Status |
|---|---|---|---|
| P2 | `Shared/Services/AlertSettings.swift:108` | The new permission sync only treats `.denied` as blocked. If alerts are on in the App Group but iOS reports `.notDetermined` (for example after a device restore where the App Group defaults come back but the permission does not), the rebuild bails at `NotificationService.swift:70`, no alert is scheduled, the Today card still says "You'll hear before...", and nothing asks again. Same behaviour as 1.0.3, not introduced by this diff. | Not fixed: pre-existing, rare, and whether iOS restores the permission is not confirmed. Fix would be to treat `.notDetermined` with alerts on as a prompt-on-open case. |
| P2 | `Shared/Services/ForecastStore.swift:66` | If a superseded load finished before the load that replaced it had started, its `defer` would see a matching generation and clear `inFlight` for the newer task. Main-actor FIFO ordering makes this practically unreachable, and the only cost would be one extra fetch for the same place. | Not fixed: not reachable in practice, no user-visible effect. |
| P2 | `Shared/Services/NotificationService.swift:145` | A sunset whose lead lands in quiet hours (sunset after about 10:45 pm, far north in summer) now fires at 8 pm. A first rebuild after 8 pm that day drops it instead of firing late. Matches the documented rule ("moved to the evening before, or dropped if that has passed"). | Not fixed: by design. |

## Checked, no issue

- Crashes and concurrency: no new force unwraps or indexing. `NotificationService`
  is `@MainActor`, so `lastRebuild` is isolated; `serialized` cannot deadlock
  because `rebuild` never calls `reschedule`. `syncNotificationPermission` and
  `ForecastStore` are main-actor. No persistence schema change; the new state
  (`notificationsDenied`, `alertsPlannedFrom`) is in-memory only.
- Widget target: it compiles only `ForecastService` and `ForecastCache` from
  `Shared/Services`, so the new `AlertSettings` to `ForecastStore` call does not
  reach it. Build 12 uploaded as valid.
- Purchase paths: `PaywallView` now dismisses on `isPro` turning true
  (`PaywallView.swift:134`); after a purchase the existing `dismiss()` runs a
  second time on a view no longer presented, which is a no-op. Onboarding still
  finishes on `isPro` and on the plans sheet's dismiss. Restore unchanged in
  Release; `-DemoRestore` and `-DemoNotificationPrompt` are `#if DEBUG` only.
- Onboarding: `isAdvancing` blocks double taps across the page change and is
  cleared by the animation completion; the alerts page advances as soon as the
  prompt is answered and the rebuild runs after.
- Notifications: rebuilds are serialized in call order, each clears every
  `sunset.alert.` request before adding, and identifiers are per show and day,
  so nothing is scheduled twice. A permission granted in iOS Settings
  reschedules on the next foreground; a fresh widget-fetched snapshot
  reschedules on cold launch.
- App Review: no new debug UI reachable in Release, no prices in copy, no
  other-platform links, no health claims. Paywall and onboarding offer keep
  Terms, Privacy and Restore.

## Fixes

None. Nothing in the 1.0.3 to 1.0.4 app diff is definitely broken.

## Tests

`gh-sim test --scheme Sunset` on HEAD: see the commit that adds this report
for the run id and result.
