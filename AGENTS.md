# Sunset, Project Guide

A score for tonight's sunset and an alert before the good ones. XcodeGen
project/scheme: `Sunset`, sim lease owner `sunset`.

## Product

Every evening gets a 0 to 100 score from the forecast sky at sunset: high and
mid cloud that can light up (Color), thin cirrus (Streaks), an open horizon
toward the sun (Horizon), and dry clean air (Clarity), with a rain penalty.
Low cloud about 80 km toward the sunset counts more than low cloud overhead,
because that is where the last light comes from.

Three tabs: Tonight (hero score, summary, factors, alerts card), Outlook (the
week), Settings. A Home Screen widget shows tonight's score.

Free: tonight and tomorrow, the factor breakdown, the widget.
Sunset+: alerts (threshold and lead time), the full week.

Store name: `Sunset Forecast & Alerts`. Display name: `Sunset`.

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

- `Shared/Models/SunsetForecast.swift`: `SkyConditions`, `SunsetScore`,
  `SunsetDay`, `SunsetForecast`. Pure, Codable, widget-safe.
- `Shared/Utilities/SunsetScorer.swift`: the scoring model and the one-line
  summary. Pure and pinned by `SunsetTests/SunsetScorerTests.swift`.
- `Shared/Services/ForecastService.swift`: Open-Meteo request (two points in
  one call: here and 80 km west), parse, interpolate to the sunset minute.
- `Shared/Services/ForecastCache.swift`: App Group snapshot, cached location,
  cached Pro flag. The widget reads this and fetches itself when stale.
- `Shared/Services/ForecastStore.swift`: the observable the UI reads. Every
  successful fetch rewrites alerts and reloads widgets.
- `Shared/Services/NotificationService.swift`: rebuilds every pending alert
  from the forecast. Pro and `alertsEnabled` gate it.
- `Shared/Services/BackgroundRefresh.swift`: BGAppRefresh every ~3h.
- `Shared/Services/StoreService.swift`: RevenueCat. Simulator never
  configures the SDK; StoreKit Testing or fixtures render the paywall.

## Rules that hold everywhere

- Scores are forecasts. Copy never promises a sunset, and nothing claims
  health or mood benefits.
- Only rounded coordinates go to Open-Meteo. No account, no analytics, no
  location stored anywhere but the App Group.
- Review prompt: `requestReview()` directly on the third open with a score of
  60 or more, once. No custom "Enjoying it?" gate (5.6.1).
- Launch arguments (DEBUG): `-DemoLocation` (Vancouver, WA, skips
  onboarding), `-DemoPro`, `-PaywallSnapshot`, `-ScreenshotTab <n>`.

## Deep notes (load on demand)

| File | Covers | Read when |
|---|---|---|
| `.claude/rules/scoring.md` | Why the weights are what they are | Touching `SunsetScorer` |
| `.claude/rules/release-and-store.md` | ASC, RevenueCat, TestFlight history | Releasing |

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
the global agent rules + the `ios-dev` skill.
