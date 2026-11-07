VERDICT: PASS

# Verification of the Sunset state machine fixes, 2026-11-06

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the whole change `git diff c9613ab..de72eb6` (10 commits; the last, `de72eb6`, is an empty fleet snapshot). Every claim was re-read in the code at HEAD, the full unit and UI suites were rerun, and all eight fixes were reverted on a throwaway branch (tests kept) to prove their tests fail without them. No app code or test was changed.

**Summary: 8 of 8 fixes work on the review's route. No regression found, no scope violation, no newly failing test. Full suites on HEAD: 73 of 73 unit, 7 of 7 UI. With the fixes reverted, all 9 claim tests (5 unit, 4 UI) fail and both controls pass.**

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| B1 | Yes | Clean | Route: onboarding Don't Allow, then Today > "Turn on alerts" > toggle on. The sheet's `onChange` asks iOS (no prompt), then `syncNotificationPermission()` reads `.denied` and sets `notificationsDenied` (`AlertSettings.swift:103-111`, `TodayView.swift:455-460`); the toggle stays on. `alertsBlocked` (`AlertSettings.swift:68`) now drives the card ("Notifications are turned off for Sunset.", `TodayView.swift:293-295`), the Settings row ("Notifications off", `SettingsView.swift:160`) and the banner, moved directly under the toggle (`TodayView.swift:378-388`) so it is above the locked rows. Revokers: launch (`App.swift:50`) and every foreground (`App.swift:57`) read the permission. Nothing ever writes `alertsEnabled` from the read, so no stored setting is cleared on an inferred state. Test asserts behaviour of the state (blocked, toggle kept, rebuild on change) with an injected status. |
| B2 | Yes | Clean | Route: sheet > "Open Settings" > allow > back. Foreground runs `syncNotificationPermission()` (`App.swift:57`); the status changed from `.denied`, so it rebuilds alerts at once (`AlertSettings.swift:109-110`) and `notificationsDenied` (published) clears the banner live; the old one-shot `@State denied` is gone. Same test as B1 (grant half). |
| B3 | Yes | Clean | Route: widget refetches the snapshot, cold launch reads it, `refresh` takes the fresh same-place early return. That return now rebuilds alerts when `alertsPlannedFrom` (set at the top of `rescheduleAlerts`, `ForecastStore.swift:86-87`) differs from the snapshot's `fetched` (`ForecastStore.swift:48`). On a cold launch it is nil, so it always rebuilds once; warm foregrounds with the app's own forecast do not repeat it. Test asserts the hook value, see device checks. |
| B5 | Yes | Clean | `isAdvancing` guards `primaryAction` (`OnboardingView.swift:327`), `advance` (`:351`) and "Get Started" (`:229`), and clears in the `withAnimation` completion (`:353-354`). On the alerts page it is held while the prompt is up and released before advancing (`:337-343`). All three review routes (watch "Continue", "Not now" then "Get Started", "Turn on alerts" twice) are covered by UI tests that drive the real view with `doubleTap()`. Page order, the offer and its plan are unchanged; only the rebuild after the prompt moved behind `advance()`, which does not change what is scheduled. `ReleaseJourneysUITests.test1OnboardingToOfferAndToday` (Not now, then Get Started) passed, so the guard releases after a single tap. |
| B4 | Yes | Clean | `PaywallView.swift:134` dismisses when `isPro` turns on, as `.purchased` already did (`:82`). Every sheet presenter (Today `:94`, alert sheet `:453`, Outlook `:43`, Settings `:144`, onboarding `:62`) handles a plain dismiss; onboarding's own `isPro` handler and `onDismiss` both call the idempotent `finish()`. A failed restore still shows `store.errorMessage` (`PaywallView.swift:56-61`). Membership logic is untouched; `-DemoRestore` is DEBUG only (`StoreService.swift:121-122`, `:182-187`). |
| B6 | Yes | Clean | A fix for a different place starts its own load (`ForecastStore.swift:53-55`); `loadGeneration` makes the superseded load write no forecast, error or loading state (`:62-80`). Callers checked: pull to refresh (`TodayView.swift:91`) and BG refresh (`BackgroundRefresh.swift:32`) call `load` directly; either one superseding or being superseded ends with the newest load clearing `isLoading`/`inFlight` in its `defer`. Behaviour before for those overlaps was two concurrent writes, so nothing regresses. Test uses the real network and asserts the shown place. |
| B9 | Yes | Clean | `sunsetFireDate` (`NotificationService.swift:142-146`) moves a quiet sunset fire to 20:00 via `eveningBefore`, which for a sunset after 20:00 is the same evening (title "sunset tonight" stays true) and for a sunset after midnight is the evening before it. Consequence (documented rule, `NotificationService.swift:13-14`): opening the app between 20:00 and a late sunset in a quiet-hours case now drops that night's alert instead of firing at 22:05. Test asserts the pure plan. |
| B7 | Yes | Clean | `reschedule` runs every rebuild through `serialized` (`NotificationService.swift:46-60`), a chain of main-actor tasks each awaiting the previous one, so the newest plan is the last applied. No rebuild calls `reschedule`, so the chain cannot deadlock. Test exercises `serialized` itself, see device checks. |

## Disputed

The fixes doc has no "Disputed" section and lists nothing as disputed, held or skipped. Nothing to rule on. Its note on B8 (NOT A BUG in the review, left alone) is correct: `plan` and the triggers are unchanged for it.

## Scope

- Every in-scope review claim (B1 to B7, B9) is in the fixes table and marked Fixed with a test. The review left nothing UNVERIFIED.
- No change to onboarding order, steps, the offer or its plan, prices, paywall offers, membership judgement, or when a paywall appears. The paywall closing on `isPro` is the B4 fix.
- No new persisted key and no stored format change (`notificationStatus` and `notificationsDenied` are in memory), so upgrades keep every user's data. No backend, App Store Connect or RevenueCat change.
- Extra pieces are test seams or parts of a listed fix: `ForecastStore.init(forecast:)` (was private), `alertsPlannedFrom`, DEBUG `-DemoRestore` and `-DemoNotificationPrompt`, the AGENTS.md launch-argument lines, and the moved banner (B1's "below the fold" cost).

## Regression sweep (diff only)

- Widgets: the widget target compiles only `Shared/Models`, `Shared/Utilities`, `ForecastService.swift` and `ForecastCache.swift` (`project.yml`), none changed. The cached snapshot and Pro flag are written as before.
- Notifications: identifiers, titles, bodies and triggers unchanged except B9's fire time. A rebuild still clears first and still checks the live permission (`NotificationService.swift:65-70`).
- Entitlements and trials: untouched outside DEBUG.
- Day and time zone: B9 uses the forecast zone like the sunrise and sky-event paths.
- Localized text: the app has no string catalog; the two new strings are English like the rest.
- iPhone Duo: no layout code changed; the Today card's blocked subtitle is shorter than the enabled one, and the alert sheet is a sheet in both layouts.
- Watch: the app has none.

## Test results

All runs are `gh-sim` on GitHub's Macs (Xcode 27.1, iPhone 17, iOS 27.2).

| What | Branch | GitHub run id | Result |
|---|---|---|---|
| `Sunset` full unit suite, plus screenshots | HEAD `de72eb6` | 42381456597 | 73 passed, 0 failed (matches the fixes doc) |
| `SunsetUITests` full UI suite | HEAD `de72eb6` | 42382735726 | 7 passed, 0 failed (matches the fixes doc) |
| Fail without fix, unit: B1/B2, B3, B6, B7, B9 claim tests and both controls | `scratch-revert` (fix lines reverted, tests kept; B1's read stubbed to return no change) | 42383902324 | 5 failed with the expected messages ("a revoke rebuilds the alerts", "alerts were not rebuilt from the widget's snapshot", "store shows lat 45.63 ... the second fix was ignored", order `older start, newer, older end`, Helsinki/Reykjavik/Oslo "inside quiet hours"); both controls passed |
| Fail without fix, UI: B5 three tests, B4 | `scratch-revert` | 42384677306 | 4 failed, each on the review's route: watch double tap "double tap skipped the alerts page" (the second tap ran "Turn on alerts" and moved on to the offer), "Not now" double tap and "Turn on alerts" double tap both left onboarding without the offer, Restore "the paywall stayed open with a live buy button" |

Every test the change added passes on HEAD: the 7 in `StateMachineFixTests`, 3 in `OnboardingDoubleTapUITests`, 1 in `PaywallRestoreUITests`. No failure appeared, so no `c9613ab` comparison was needed. The scratch branch was deleted; this branch holds only this doc's commit on top of `de72eb6`.

## Must change

Nothing blocking.

## Device checks the tests leave open

- B1/B2: the test injects the status. Not covered: that launch, foreground and the sheet really read iOS, the three copies on screen, and the banner's new position. On a device: decline in onboarding, toggle Alerts on from Today, see the banner under the toggle, the card and the Settings row; then allow in iOS Settings, return, and see the banner go and an alert pending.
- B3: the test asserts `alertsPlannedFrom`, which is set when the rebuild starts. Not covered: that pending requests exist after a cold launch on a widget-fetched snapshot (needs a real permission and the widget).
- B7: the test drives `serialized` with closures. That `reschedule` uses it is from the code (`NotificationService.swift:47`); the real interleaving with `UNUserNotificationCenter` has no fake to test against.
- B4: Restore is driven by DEBUG `-DemoRestore`. A real RevenueCat restore (and Ask to Buy approval while open) needs a device.
- B5: the system prompt is replaced by `-DemoNotificationPrompt`. A double tap on "Turn on alerts" with the real prompt needs a device.

## Notes

- Screens (run 42381456597): the alert sheet (`-ScreenshotScene alerts`), Settings (`-ScreenshotTab 2`) and the onboarding alerts page (`-OnboardingStep 2`) render normally with no layout change. The blocked state (banner under the toggle, "Notifications off", the card copy) needs a denied permission, which a fresh simulator cannot reach, so it was not seen on screen.
- Follow-up outside this change: the Android `AlertPlanner.kt:36-37` still subtracts the lead with no quiet-hour check, so the port no longer matches iOS for summer sunsets far north. The parity fixtures (LA and London, and the recorded live week) contain no sunset whose fire lands after 22:00, so `PortParityTest` will not catch it; port `sunsetFireDate` and add a case.
- The fixes doc's B1 fail-without-fix and this one both stub the read (the pre-fix app had no such function), so the B1 test proves the state logic, not the system read.
