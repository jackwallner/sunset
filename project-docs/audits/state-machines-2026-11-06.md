# Sunset state machine audit, 2026-11-06

Audited commit `ddffa2e` (clean tree, branch `fleet/20261106-114513-5225-claude`). iOS app, shared code and widget; there is no watch target and no backend in the repo (entitlements are RevenueCat only, read from `StoreService`). Android out of scope. Nothing was fixed.

**Summary: 9 bugs. 2 proved by a failing test (B6 mechanism, B9), 7 code path only (B1, B2, B3, B4, B5, B7, B8). 8 product calls, not counted.**

Repro suite: `state-machines-2026-11-06-repro.swift` (class `StateMachineAuditRepro`). Run with `gh-sim test --scheme Sunset --only SunsetTests/StateMachineAuditRepro`. Recorded runs: `sunset@20261106-114513-5225-claude-imac41dd-1106-124804-26043` (4 passed, 5 failed: B6 and both B9 tests failed as claimed; the two zone replica tests failed because my first fixture date was in the past, a setup error, not a claim), then `sunset@20261106-114513-5225-claude-imac41dd-1106-132347-9574` for the replica with a future date (control passed, claim test failed, see B8).

## Test seams that exist

| Seam | Where | Used for |
|---|---|---|
| `NotificationService.plan(... now:)` pure | `NotificationService.swift:67` | B9 |
| `isQuiet`, `eveningBefore`, `skyEventFireDate` pure | `NotificationService.swift:113-135` | B9 |
| `ForecastService.parse(_:latitude:longitude:now:)` | `ForecastService.swift:67` | not needed |
| `AlertSettings.shared` on the App Group suite, `reviewEligible` pure | `AlertSettings.swift` | controls |
| `ForecastCache.forecast/location/isPro` on App Group defaults | `ForecastCache.swift` | set up state |
| `ForecastStore.shared.refresh/load` (real Open-Meteo network from the runner) | `ForecastStore.swift` | B6 |
| `NSTimeZone.default` | Foundation | B8 replica |

Seams that do not exist: `UNUserNotificationCenter` is called directly in `reschedule` (`NotificationService.swift:36-62`), `requestAuthorization` and `authorizationStatus` (`:19-26`), so no test can see what is pending, set permission, or interleave two reschedules without changing app code. `StoreService` calls `Purchases.shared` directly and `CustomerInfo` has no public initializer, so entitlement transitions cannot be driven. Views hold their logic in private computed properties and `@State`, with no inspection seam. Every bug that depends on those stays "Code path" below, with what would settle it.

## Bugs, ranked by impact

Impact = users reached times cost. "Population" is my estimate, not measured.

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| B1 | `alertsEnabled` is never reconciled with the iOS permission. The toggle stays on after a denial or later revocation. | Today "Alerts" card says "You'll hear before any sunrise or sunset scoring 70 or higher.", Settings says "Alerts: 70+ · 45 min before", the card button says "Change alerts". Nothing is ever delivered. | `TodayView.swift:293-294` "You'll hear before any ... scoring N or higher."; `NotificationService.swift:6-9` "Every refresh rewrites the whole set ... Sunrise and sunset alerts are free" | Onboarding page 3 "Turn on alerts" > Don't Allow (alerts off). Today > "Turn on alerts" card > toggle "Alerts" on. iOS shows no prompt (already denied), `requestAuthorization` returns false, the sheet shows a banner, `alertsEnabled` stays true. Tap Done. Card and Settings now claim alerts. Second route: grant, then turn Notifications off in iOS Settings; card never changes. | Everyone who declines the system prompt (commonly a third or more of installs) and then tries again, plus everyone who revokes. Cost: the headline feature is dead while the app says it is on, so a user misses every show. Hit the first time they decline and retry. | Code path | `TodayView.swift:452-458` (sets `denied`, never resets `alertsEnabled`), `:291-297`, `SettingsView.swift:158-160`, `NotificationService.swift:40-42` (silent return) |
| B2 | Permission granted later is not picked up. The banner goes stale and nothing is scheduled until the next fetch. | After enabling Notifications in iOS Settings and returning, the sheet still says "Notifications are turned off for Sunset". No alert exists for tonight. | `TodayView.swift:373` "Alerts are rebuilt from the latest forecast each time the app refreshes"; the sheet's own "Open Settings" button invites this route (`:432-436`) | From B1's state: Alerts sheet > "Open Settings" > iOS Settings > Sunset > Notifications > Allow > back to Sunset. The banner remains (`.task` at `:463-467` runs once). Foreground does `forecastStore.refresh`, which returns early while the forecast is under 3 hours old and in the same place, with no reschedule. Pending alerts stay empty until a stale fetch or a BGAppRefresh (earliest 3 h, iOS discretionary). Workaround: toggle off and on. | Subset of B1 users who fix it (maybe a quarter to a half of them). Cost: the first day or more of alerts lost, and the user is told it is still off. Every time they take that route. | Code path | `TodayView.swift:463-467`, `App.swift:49-54`, `ForecastStore.swift:34-41`, `BackgroundRefresh.swift:24` |
| B3 | A widget fetch refreshes the shared snapshot but not the alerts, and the app then treats that snapshot as fresh. | Today and the widget show tonight at 58. A pending alert planned earlier will still fire "Great sunset tonight: 78". | `NotificationService.swift:6-8` "Every refresh rewrites the whole set from the latest forecast, so a show that drops below the threshold loses its alert"; `docs/index.html:137` "rebuilds it as the forecast changes, so a sky that clouds over loses its alert" | Add the Home Screen widget, alerts on. Widget timeline refresh fetches (stale after 3 h) and writes `ForecastCache.forecast`. App was terminated. Open the app within 3 h of the widget's fetch: `ForecastStore.init` loads that snapshot, `refresh` takes the "not stale" early return, no reschedule. | Widget users with alerts on who cold-start the app between BG runs. Cost: one alert for a sky that no longer qualifies, or a missing alert for one that now does. BGAppRefresh (`load` always reschedules) repairs it within hours when iOS runs it, so impact is bounded. | Code path | `SunsetWidget.swift:27-35`, `ForecastStore.swift:21,34-41,46-60` |
| B4 | The paywall does not react to `isPro` after Restore or a pending purchase resolving. The buy button stays live for a subscriber. | Paywall still shows plans and "Continue with Sun+" after a successful restore; no confirmation. Settings behind it already says "Sun+ is on". | Button "Restore purchases" (`PaywallView.swift:100-109`). Sibling flows confirm: Settings "Sun+ is restored." (`SettingsView.swift:106`), onboarding finishes on `isPro` (`OnboardingView.swift:61`, comment `:251`) | Today > Sky events card > "Get alerted before them" (only shown when not Pro, `TodayView.swift:266-268`) > Paywall > "Restore purchases". Same for an Ask to Buy purchase approved while the paywall is open. Only `.purchased` calls `dismiss()` (`:82`), and the CTA is disabled only by `selectedPackage == nil || store.isLoading` (`:91`). | Reinstallers and new-device users who restore from the paywall, and Ask to Buy families. Cost: no feedback and a live purchase button, with possible duplicate spend (lifetime on top of a subscription; Apple blocks same-product repeats). | Code path | `PaywallView.swift:79-91,100-109`, `StoreService.swift:179-189` |
| B5 | Onboarding advances on every tap with no guard during the 0.3 s transition, and the CTA sits at a fixed y, so a double tap skips a page. | Double tap Continue on "What do you want to catch?" lands on the Sun+ offer without ever seeing "Get a heads-up, free" (no notification prompt). Double tap "Turn on alerts" skips the Sun+ offer and drops into the app. | `OnboardingView.swift:4-5` "Four short pages ... what the app does, which shows to watch, free alerts, then the Sun+ offer"; AGENTS.md "four pages, CTA at a fixed y" | Fresh install > welcome "Continue" > watch page "Continue" tapped twice quickly. `advance()` reads `step` at tap time (`:343-346`), the second tap sees the already advanced step. On the alerts page both tasks await `requestAuthorization` then each call `advance()`; the second falls off the end into `finish()` (`:344`). | Every new install, a few percent double tap. Cost: a missed permission prompt or offer page; recoverable via Today's alert card and Settings. Low. | Code path | `OnboardingView.swift:268-277,323-346` |
| B6 | A new location fix that arrives while a load is running is dropped. | After moving more than about 5 km since last use, the app can show the old town's forecast, alerts and widget place name until the next foreground. | `ForecastStore.swift:32-33` "Refreshes when the cache is older than three hours or the location moved." | Cold launch (`App.swift:42-47`): `location.request` is issued and, at once, `forecastStore.refresh(cachedFix)` starts a load for the old cached place. The real fix lands (`LocationService.swift:81-90`, `store` then `onFix`) while that load is running; `refresh` hits `if let inFlight, !force { return }` (`ForecastStore.swift:42`). Next foreground self heals (`App.swift:53`, place differs so a new load runs). Timing: needs the fix plus geocode to beat the Open-Meteo call. | Travellers and movers, a minority of launches, and only when the race lands. Cost: wrong city for one session. | **Test** `testFixArrivingDuringLoadIsNotDropped` fails: "store shows lat 45.63 place Vancouver, WA; the second fix was ignored" (expected 35.68). Control `testForecastStoreControl_FixWithNothingInFlightLoads` passes. Timing of the race in the field is code path. | `ForecastStore.swift:34-44,50-51` |
| B7 | `reschedule` is not serialised, so an older plan can land after a newer one and survive it. | Alerts still arrive after the user turned them off, or Sun+ only alerts survive a lapse. | `NotificationService.swift:6-8`; `AlertSettings.swift:95` "free accounts always get the defaults, whatever was picked during a lapsed subscription" | Alert plan A is mid add-loop (an app open or BG fetch, `ForecastStore.swift:59-61`) while the user, in the Alerts sheet, turns Alerts off (`TodayView.swift:453` reschedules and removes all, then returns). A keeps adding after that removal. Lapse variant: `isPro` is captured as an argument before A's awaits (`ForecastStore.swift:60`), `isPro` flips false (`StoreService.swift:96`), the newer plan has fewer requests but cannot remove A's later adds. | Very narrow window (milliseconds of `add` awaits, `NotificationService.swift:62`), so rare per user. Cost when hit: an unwanted alert or one Pro only alert. | Code path. What would settle it: a fake behind `UNUserNotificationCenter` (none exists) that suspends `add`, then calls `reschedule` twice. | `NotificationService.swift:35-64`, `ForecastStore.swift:59,70-72`, `StoreService.swift:92-97` |
| B8 | The notification trigger is a calendar trigger with no time zone on its components, so it fires by the device zone at delivery, not the forecast zone it was planned in. | After flying east or west and before reopening the app, the alert fires hours off. | `AlertSettings.swift:51` "Minutes before sunset to send the alert"; `TodayView.swift:392` section "How far before sunset": the alert should land at that lead before that sunset | Plan alerts in Los Angeles, fly to New York, do not open Sunset. `reschedule` built the components in `forecast.timeZone` (`:52-60`) but `UNCalendarNotificationTrigger` reads bare components in the current zone. BG refresh reloads the old cached location (`BackgroundRefresh.swift:31`), so it does not fix it. Opening the app fixes it (new fix, new place, reschedule). | Travellers across zones with alerts on, once per trip. Cost: one or two mistimed alerts, at the old city's sunset anyway. | Code path. Replica test (replays `reschedule`'s trigger lines with `NSTimeZone.default` set to New York, forecast zone Los Angeles; it does not call `reschedule`, so it supports the Foundation behaviour only): `testTriggerFiresAtPlannedInstant_DeviceZoneDiffersFromForecastZone` fails, "trigger fires at 2031-10-08 21:45:00 +0000, planned 2031-10-09 00:45:00 +0000" (3 hours early); control `testTriggerControl_SameZone` passes. What would settle the real path: a fake behind `UNUserNotificationCenter` capturing the request `reschedule` adds. | `NotificationService.swift:52-62` |
| B9 | Sunset alerts ignore the quiet hours that sunrise and sky events obey. | At high latitude in summer, "Epic sunset tonight" arrives at 23:13 or 22:05. | `NotificationService.swift:13-14` "Nothing fires overnight. An alert that would land in these hours moves to the evening before, or is dropped"; AGENTS.md "nothing fires 10 pm to 7 am" | Alerts on, location Reykjavik, Helsinki, Anchorage or similar, late June to early July, a sunset at 70 or more: Today shows it, the alert is planned at sunset minus lead. Default lead (45 min) is enough. | Users above about 59 N, a few weeks a year, only on good shows. Cost: one overnight buzz. Low users, but a documented rule broken. | **Test** `testSunsetAlertNeverFiresInQuietHours_Reykjavik` fails: "sunset alert planned for 2026-06-21 23:13:00 +0000 (23:13 local), inside 22:00-07:00 quiet hours". `..._Helsinki` fails: "fire 22:05 local". Control `testQuietHoursControl` passes (LA sunset 20:35, fire outside quiet hours). | `NotificationService.swift:82-85` (no `isQuiet` check on the sunset branch, compare `:99-100`, `:113-118`) |

## Product calls (not counted)

No promise text found that the code breaks.

1. Free users get alerts for every one of the 8 forecast days, including days the Outlook locks for them (`NotificationService.swift:78`, `OutlookView.swift:21-25`). AGENTS.md says free is "today and tomorrow ... sunrise and sunset alerts at the default score". Both read as true; the alert text leaks a locked day's score.
2. No `UNUserNotificationCenterDelegate`, so a notification that fires while the app is open shows no banner. Nothing in copy promises one.
3. AGENTS.md says the review prompt runs "on the third open"; code also needs two days since first open and onboarding done (`AlertSettings.swift:107-128`). Doc drift, not user visible.
4. `isPro` stays true from the cache when `customerInfo(.fetchCurrent)` fails offline (`StoreService.swift:112,230-235`). Sensible grace, but an expired subscriber stays Pro until a fetch succeeds.
5. Alerts quote the forecast as of the last fetch with no "as of" (`NotificationService.swift:89-91`); if BGAppRefresh never runs they can be days old.
6. "Update location" installs its force-refresh closure as `onFix` for the rest of the process (`LocationService.swift:52-53`, `SettingsView.swift:86`), so every later foreground fix bypasses the 3 hour cache and refetches. Cost is data and battery, not state.
7. Turning a sky event toggle on silently turns the master Alerts switch on and asks for permission (`TodayView.swift:476`).
8. Outlook free days are the first two upcoming days, so after sunset the free window rolls forward and day three becomes readable in the evening (`SunsetForecast.swift:203` `upcomingDays`, `OutlookView.swift:20-21`).

## Related fixes, in order

1. B1 and B2 together: one reconcile step that reads `authorizationStatus` on foreground and on sheet open, reschedules on a change, and makes the card, the Settings row and the sheet show a "notifications off" state instead of "on". B1 and B2 are the same missing state: `alertsEnabled` is one boolean standing in for four (wanted, permitted, scheduled, pro).
2. B7 and B3: one serialised scheduler (an actor or a chained task) that every caller goes through, and have the app reschedule on launch whenever the cached forecast is newer than the last plan.
3. B6: cancel and replace the in-flight load when a new location arrives (and stop pull to refresh from calling `load` beside it).
4. B9 and B8: apply the quiet-hour rule to sunset alerts, and set `timeZone` on the trigger components.
5. B4: dismiss or switch the paywall to a "restored" state on `isPro`.
6. B5: ignore taps while the page transition runs.

## State machines

Notation: invariants are `I<machine>.<n>`. "Breaks" in a transition table names the invariant that transition violates and the bug.

### M1 Onboarding gate (`hasOnboarded`, `OnboardingView.Step`, purchase)

States: `step` in welcome, watch, alerts, plus; `hasOnboarded` false then true (one way); `isPurchasing`, `purchaseError`, `ctaWaitExpired`, `showPlans`. Persisted: `sunset.onboarded` in the App Group.

Invariants:
- I1.1 `hasOnboarded` only moves false to true.
- I1.2 Each page is shown once, in order.
- I1.3 Location is requested only after the welcome CTA (not at launch before onboarding, `App.swift:40-44`).
- I1.4 Alerts are enabled only when the OS says yes (`OnboardingView.swift:334`).

| From | Event | To | Notes |
|---|---|---|---|
| welcome | CTA | watch + location prompt | double tap skips watch (breaks I1.2, B5) |
| watch | CTA | alerts | double tap skips alerts, no prompt (I1.2, B5) |
| alerts | "Turn on alerts" | prompt, then plus | `alertsEnabled` = granted; double tap lands in `finish()` (I1.2, B5) |
| alerts | "Not now" | plus | `alertsEnabled` unchanged |
| plus | "Get Started" | hasOnboarded | |
| plus | CTA, no package | showPlans sheet | on dismiss with `isPro`, finish |
| plus | CTA, purchase `.purchased` | hasOnboarded | |
| plus | cancelled, pending or failed | plus + error text | pending later flips `isPro`, `onChange` finishes (`:61`) |
| plus | Restore with Sun+ | hasOnboarded via `isPro` | |
| plus | Restore without | plus + message | |

### M2 Alerts: wanted x permitted x pro x pending

State is the tuple (`alertsEnabled`, OS status, `isPro`, `watched`, `threshold`, `lead`, `skyEventKinds`, forecast, pending requests). Persisted: `sunset.alerts.*` in the App Group; pending lives in iOS.

Invariants:
- I2.1 Pending requests with prefix `sunset.alert.` equal `plan(latest forecast, effective settings, isPro)` whenever `alertsEnabled` and the OS allows; empty otherwise (`NotificationService.swift:6-9`).
- I2.2 What the UI says about alerts matches I2.1.
- I2.3 Free accounts get the default threshold and lead and no sky events (`:46-49`).
- I2.4 Nothing fires 22:00 to 07:00 (`:13-14`).
- I2.5 `watched` is never empty.

| From | Event | To | Notes |
|---|---|---|---|
| off | sheet toggle on, OS undetermined | on, prompt, reschedule | |
| off | sheet toggle on, OS denied | on, banner, nothing scheduled | breaks I2.2 (B1) |
| on, denied | user allows in iOS Settings | on, nothing scheduled | breaks I2.1 until next fetch (B2) |
| on, allowed | user revokes in iOS Settings | on, nothing deliverable | breaks I2.2 (B1) |
| on | toggle off | off, pending removed | racing add-loop survives (I2.1, B7) |
| on | threshold, lead, kinds, watched edit | reschedule | edits in a lapsed account stored but ignored (I2.3 holds) |
| on | `isPro` flips | reschedule | captured `isPro` in a concurrent load (I2.3, B7) |
| on | fetch by app or BG | reschedule | |
| on | fetch by widget | none | breaks I2.1 (B3) |
| on | forecast zone differs from device zone at fire time | fires off time | B8 |
| on | high latitude sunset | planned in quiet hours | breaks I2.4 (B9) |
| any | `watched` set to empty | reverted (`AlertSettings.swift:32`) | I2.5 holds (control test passes) |

### M3 Entitlement (Sun+)

States: cached `isPro` (App Group `sunset.isPro`), RevenueCat `entitlements.active["pro"]`, `isConfigured` (never on the simulator), `packages`, `introEligibility(Resolved)`, `isLoading`, `errorMessage`.

Invariants:
- I3.1 `ForecastCache.isPro == StoreService.isPro` after every update (`StoreService.swift:92-97,272-275`).
- I3.2 Pro features gate on `isPro` only: week (`OutlookView.swift:21`), sky event alerts and custom threshold and lead (`NotificationService.swift:46-49`, `AlertSettings.swift:96-97`), alert sheet controls.
- I3.3 Trial wording only when eligibility is resolved and eligible (`:138-145`).
- I3.4 A paywall is not offered to a Pro user (Settings row hides at `SettingsView.swift:16`, Today button hides at `TodayView.swift:266`).

| From | Event | To | Notes |
|---|---|---|---|
| free | purchase `.purchased` | pro | paywall and onboarding dismiss |
| free | purchase cancelled | free + message | |
| free | purchase pending (Ask to Buy) | free + message | later delegate update flips to pro |
| free | restore with Sun+ | pro | Settings and onboarding confirm; paywall does not (I3.4 in the open paywall, B4) |
| pro | entitlement expires | free | pending alerts rebuilt via `isPro` didSet |
| pro | fetch fails offline | pro (cache) | product call 4 |
| pro | cold start | pro from cache, then verified | |

No bug found in the Pro to free alert settings path itself: effective values fall back, stored picks are kept and return on resubscribe (`AlertSettings.swift:95-97`).

### M4 Forecast store

States: `forecast` (nil or snapshot with `fetched`, location, zone), `isLoading`, `errorMessage`, `inFlight`. Persisted snapshot `sunset.forecast.v2`; the widget also writes it.

Invariants:
- I4.1 The shown forecast is for the current location (`isSameLocation`, 0.05 degrees) or a load for it is pending.
- I4.2 After a successful fetch, widgets reload and alerts are rewritten (`:55-60`).
- I4.3 At most one load is in flight unless forced.
- I4.4 `isLoading` is true while any load runs.

| From | Event | To | Notes |
|---|---|---|---|
| any | foreground, fresh and same place | none | no reschedule even if the snapshot came from the widget (I4.2, B3) |
| any | fix while a load runs, not forced | dropped | breaks I4.1 (B6) |
| any | forced refresh or pull to refresh while a load runs | second load, no cancel | last response wins, first finisher clears `isLoading` and `inFlight` (breaks I4.3, I4.4); minor, unproved |
| any | fetch fails | keeps forecast, message | |
| any | BG task | `load(cached location)` | uses last known fix, not the current one |

### M5 Location

`LocationService.Status`: unknown, waiting, denied, located. Persisted fix in the App Group. Invariants: I5.1 a cached fix is never lost on failure (`LocationService.swift:108`); I5.2 only reduced accuracy. Denial flips `status` but `location` still returns the cache, so the forecast keeps working for the old place with no hint (not a bug, noted). `onFix` is replaced by each `request(onFix:)` and never cleared (product call 6).

### M6 Background refresh and widget timeline

BGAppRefresh: scheduled on background and at the start of each run, earliest 3 h; runs `load` unconditionally. Widget: one entry, reload after the next show plus 31 minutes, capped at 3 h, fetches when stale and writes the snapshot but not alerts (B3). Show rollover uses `isOver` = time plus 30 minutes in both app and widget, so they agree.

### M7 Navigation and panes (`MainTabView`)

State: `selection`, `pickedShow`, `paneGeometry` (split or not). Invariants: I7.1 no `selection == 1` while split (`App.swift:199-201`); I7.2 a pick lands on Today (`PaneDetail.tab`, unit tested). Folding with a pick open leaves the detail pushed on Today, which is consistent. Two sheets from sibling views (Today, Settings, trailing Outlook) cannot be requested together because a sheet covers the others. No bug found.

### M8 Review prompt

`reviewAsked`, `openCount`, `firstOpen`. `shouldRequestReview` sets `reviewAsked` before `requestReview()` runs, so a system decision not to show it still spends the one ask (`AlertSettings.swift:107-115`); documented as once. The `Task.sleep` guard re-checks the sheets and pushed detail. No bug found.

### M9 Day and time zone changes

Hero, up next, headline and Today labels derive from `.now` at render. Zone for display comes from `forecast.timeZone`, device zone only for `fetched` and the notification trigger (B8). Day rollover re-renders on the next publish (location status or fetch on foreground); with location off no republish happens, so a left open Today can show last night's hero until something publishes (minor, unproved, not counted). Quiet hours, evening before and day keys use the forecast zone (`NotificationService.swift:120-135,157-163`); DST days checked by reading, no defect found.
