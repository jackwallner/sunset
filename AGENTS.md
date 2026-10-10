# Sunset, Project Guide

A score for every sunrise and sunset, and an alert before the good ones. XcodeGen
project/scheme: `Sunset`, sim lease owner `sunset`.

## Product

Every sunrise and sunset gets a 0 to 100 score from the forecast sky at that
moment: high and mid cloud that can light up (Color), thin cirrus (Streaks),
an open horizon toward the sun (Horizon), and dry clean air (Clarity), with a
rain penalty. Low cloud about 80 km toward the sun (west at sunset, east at
sunrise) counts more than low cloud overhead, because that is where the light
comes from. The hourly forecast also yields sky events: thunderstorms,
rainbow chances and fog.

Onboarding (four pages, CTA at a fixed y): welcome, pick sunrise and/or
sunset, free alerts (notification prompt), Sun+ offer. The offer follows the
fleet trial page: "Get Started" free exit above, the monthly billed amount as
the largest pricing element (no box, 3.1.2(c)), one terms line, then "Start
7-day free trial" buying monthly (the fleet's best converters all do).

Look: no light or dark theme. Every screen sits on a forecast sky
(`SkyBackdrop`): the score's own colours down to a glowing horizon, the sky
reflected in water below it, frosted glass cards on top, light text, white
primary buttons. Today uses the hero show, each Outlook day card its own sky.
The app forces `.dark` so system chrome matches.

Three tabs: Today (next watched show as the hero, summary, factors, up next,
sky events, alerts card), Outlook (the week), Settings (watch toggles,
alerts). A Home Screen widget shows the next watched show.

Free: today and tomorrow, the factor breakdown, the widget, sunrise and
sunset alerts at the default score (70) and lead time (45 min).
Sun+ (was "Sunset+"): the full week (blurred for free users), storm,
rainbow and fog alerts, custom alert score and lead time.

Store name: `Sunset & Sunrise Prediction` (subtitle `Golden Hour Forecast & Alerts`). Display name: `Sunset`.

## Tech stack and identifiers

- Swift 6, SwiftUI, CoreLocation (one reduced-accuracy fix), WidgetKit,
  BackgroundTasks, UserNotifications
- iOS 17+
- App: `com.jackwallner.sunset`
- Widget: `com.jackwallner.sunset.widget`
- Tests: `com.jackwallner.sunset.tests`
- App Group: `group.com.jackwallner.sunset`
- Background refresh task: `com.jackwallner.sunset.refresh`
- Weather: Open-Meteo forecast API, no key. Same choice as `~/headaches`.
- RevenueCat entitlement `pro`; products `com.jackwallner.sunset.monthly`,
  `.yearly`, `.lifetime` (Vitals structure: $1.99, $14.99 with 1-week trials,
  $29.99 lifetime)
- App Store Connect app: `6821025282`

## Architecture

- `Shared/Models/SunsetForecast.swift`: `SunEvent`, `SkyConditions`,
  `SunsetScore`, `SunShow` (one sunrise or sunset), `SkyEvent`, `SunsetDay`,
  `SunsetForecast`. Pure, Codable, widget-safe.
- `Shared/Utilities/SunsetScorer.swift`: the scoring model and the one-line
  summary. Pure and pinned by `SunsetTests/SunsetScorerTests.swift`.
- `Shared/Utilities/SkyEventDetector.swift`: hourly storms, rainbow chances,
  fog, plus `SolarPosition`. Pure and pinned by tests.
- `Shared/Services/ForecastService.swift`: Open-Meteo request (three points
  in one call: here, 80 km west, 80 km east), parse, interpolate to the
  sunrise and sunset minute.
- `Shared/Services/ForecastCache.swift`: App Group snapshot, cached location,
  cached Pro flag. The widget reads this and fetches itself when stale.
- `Shared/Services/ForecastStore.swift`: the observable the UI reads. Every
  successful fetch rewrites alerts and reloads widgets.
- `Shared/Services/NotificationService.swift`: rebuilds every pending alert
  from the forecast. `alertsEnabled` gates it; Pro adds sky events and the
  custom threshold and lead. Sunrise alerts and overnight sky events fire at
  8 pm the evening before; nothing fires 10 pm to 7 am. `plan` is pure.
- `Shared/Services/BackgroundRefresh.swift`: BGAppRefresh every ~3h.
- `Shared/Services/StoreService.swift`: RevenueCat. Simulator never
  configures the SDK; StoreKit Testing or fixtures render the paywall.

## Rules that hold everywhere

- Scores are forecasts. Copy never promises a sunrise or sunset, and nothing claims
  health or mood benefits.
- Only rounded coordinates go to Open-Meteo. No account, no analytics, no
  location stored anywhere but the App Group.
- Review prompt: `requestReview()` directly on the third open with a score of
  60 or more, once. No custom "Enjoying it?" gate (5.6.1).
- Launch arguments (DEBUG): `-DemoLocation` (Vancouver, WA, skips
  onboarding), `-DemoPro`, `-PaywallSnapshot`, `-ScreenshotTab <n>`,
  `-OnboardingStep <n>`, `-DemoForecast` (fixed week with sky events),
  `-ScreenshotScene detail|events|alerts` (Today tab).

## Deep notes (load on demand)

| File | Covers | Read when |
|---|---|---|
| `.claude/rules/scoring.md` | Why the weights are what they are | Touching `SunsetScorer` |
| `.claude/rules/release-and-store.md` | ASC, RevenueCat, TestFlight history | Releasing |

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
the global agent rules + the `ios-dev` skill.
