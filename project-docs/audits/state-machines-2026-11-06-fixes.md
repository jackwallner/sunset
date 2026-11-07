# Fixes for the Sunset state machine audit, 2026-11-06

Fixes for every claim `state-machines-2026-11-06-review.md` marked CONFIRMED or CONFIRMED-MINOR, in the review's ranked order, on top of `c9613ab`. B8 (NOT A BUG) and the product calls are left alone.

**Summary: 8 claims in scope. 8 fixed, 0 held for Jack, 0 skipped. Final suites: 73 of 73 unit, 7 of 7 UI.** The review left no claim UNVERIFIED and found no other bug, so nothing needed a settling test first. The review's extra B5 routes (double tap on "Not now", the watch page raising the prompt) are covered by the B5 fix and its UI tests.

## Claims

| ID | Rank | Status | Commit subject | Regression test | What changed |
|---|---|---|---|---|---|
| B1 | 1 | Fixed | `fix: reconcile alerts with the iOS notification permission` | `StateMachineFixTests.testNotificationPermissionIsReconciledWithAlertsToggle` | `AlertSettings.syncNotificationPermission` reads the iOS permission on launch, foreground and when the Alerts sheet opens or its toggle turns on. A denial never clears the user's toggle; `alertsBlocked` makes the Today card ("Notifications are turned off for Sunset."), the Settings row ("Notifications off") and the sheet tell the truth. The sheet's "Open Settings" banner moves under the toggle so it is never below the fold. |
| B3 | 2 | Fixed | `fix: rebuild alerts from a widget-fetched snapshot on cold launch` | `StateMachineFixTests.testFreshSnapshotNoAlertWasBuiltFromIsRescheduledOnRefresh` | `ForecastStore` remembers which forecast (`fetched`) its alerts were built from, and the fresh, same-place early return in `refresh` rebuilds alerts when the snapshot is a different one, such as one the widget fetched. |
| B2 | 3 | Fixed | `fix: reconcile alerts with the iOS notification permission` (shares B1's cause) | `StateMachineFixTests.testNotificationPermissionIsReconciledWithAlertsToggle` | A permission change seen on foreground rebuilds the alerts at once, and the banner follows the live `notificationsDenied` instead of a one-shot `@State`. |
| B5 | 4 | Fixed | `fix: ignore onboarding taps while a page change is under way`; `fix: leave the onboarding alerts page as soon as the prompt is answered` | `OnboardingDoubleTapUITests` (3 tests, scheme `SunsetUITests`), from the review's `ReviewOnboardingDoubleTapUITests` | `isAdvancing` blocks the bottom bar from the tap until the page animation completes, and on the alerts page until the permission prompt is answered. Covers all three routes: watch "Continue", "Not now" (second tap was "Get Started") and "Turn on alerts". Follow-up: the alerts page now moves on once the prompt is answered and rebuilds alerts after, because waiting on the rebuild (which now also queues behind earlier ones, B7) left the answered page sitting still for over nine seconds in one simulator run. |
| B4 | 5 | Fixed | `fix: close the paywall once Sun+ is restored` | `PaywallRestoreUITests.testRestoreOnPaywallClosesItForAMember` (scheme `SunsetUITests`) | The paywall dismisses whenever `isPro` turns on (Restore, or Ask to Buy approved while it is open), the way it already did after a purchase. DEBUG `-DemoRestore` lets the UI test drive Restore, since RevenueCat is never configured on the simulator. Membership logic is untouched. |
| B6 | 6 | Fixed | `fix: let a new location fix replace a load still running` | `StateMachineFixTests.testFixArrivingDuringLoadIsNotDropped` (the audit's repro test, which the review called faithful), control `testFixWithNothingInFlightLoadsThatPlace` | A fix for a different place starts its own load instead of being dropped; the same place still waits. A load generation counter makes a superseded load leave no forecast, error or loading state. |
| B9 | 7 | Fixed | `fix: keep sunset alerts out of quiet hours far north` | `StateMachineFixTests.testSunsetAlertNeverFiresInQuietHours` (the repro's Helsinki and Reykjavik cases plus Oslo at the Sun+ 30 min lead), control `testSunsetAlertOutsideQuietHoursKeepsItsLead` | The code now follows the documented rule: a sunset alert that would land 22:00 to 07:00 moves to 20:00 that evening, like sunrise and sky event alerts. Its title ("... sunset tonight") stays true. |
| B7 | 8 | Fixed | `fix: run alert rebuilds one at a time` | `StateMachineFixTests.testRebuildsRunOneAtATimeInCallOrder` | `NotificationService.reschedule` queues each rebuild behind the previous one, so the newest plan is always the one left pending. |

Supporting commit: `test: stand in for the notification prompt in onboarding UI tests` adds DEBUG `-DemoNotificationPrompt`, which answers the notification prompt with Allow after a second, because GitHub's simulators do not always show it.

B1 and B2 share one fix (both come from the app never reading the iOS permission after the first prompt). Not changed: the review's residual B8 edge (device zone differs from forecast zone without travel) is not counted by the review, and its proposed fix would break quiet hours.

## Held for Jack

None.

## Skipped

None.

## Test results

Every run below is `gh-sim` on GitHub's Macs (Xcode 27.1, iPhone 17, iOS 27.2). The audit's repro suite was never added to the test target; its sound tests live on in `StateMachineFixTests`, and the B8 replica was dropped (NOT A BUG).

Final, on the finished branch:

| Scheme | Run | GitHub run id | Result |
|---|---|---|---|
| `Sunset` (unit, full) | `sunset@20261107-020448-47bb-claude-imac1b8a-1107-054542-5804` | 42378434021 | 73 passed, 0 failed |
| `SunsetUITests` (full) | `sunset@20261107-020448-47bb-claude-imac1b8a-1107-055839-4513` | 42379398078 | 7 passed, 0 failed |

No test newly failed, and none needed a rerun on `c9613ab`.

Regression tests fail without their fixes (a scratch copy of the branch with only the fix lines reverted, test seams kept, B1's permission read stubbed to report no change):

| What | GitHub run id | Result |
|---|---|---|
| `StateMachineFixTests` | 42369684656 | 5 failed, as claimed (B1/B2 "a revoke rebuilds the alerts", B3 "alerts were not rebuilt from the widget's snapshot", B6 "store shows lat 45.63 ... the second fix was ignored", B7 order `older start, newer, older end`, B9 "Europe/Helsinki fires at ... inside quiet hours"); both controls passed |
| `OnboardingDoubleTapUITests`, `PaywallRestoreUITests` | 42371678253 | "Not now", "Turn on alerts" (B5) and Restore (B4) failed. The watch page test passed with a 3 s check, so it was tightened |
| `testDoubleTapOnWatchLandsOnAlerts`, tightened | 42373918025 | failed: "double tap landed on the Sun+ offer" |

With the fixes: `OnboardingDoubleTapUITests` at 3 iterations, run 42377246362, 9 of 9 passed. An earlier single run with the first B5 fix (42375568126) caught the alerts page sitting still for over nine seconds after the answered prompt, which the follow-up B5 commit fixes.
