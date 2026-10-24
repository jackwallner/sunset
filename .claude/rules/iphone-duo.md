---
paths:
  - "Sunset/App.swift"
  - "Sunset/Views/UnfoldedSplit.swift"
  - "Sunset/Views/TodayView.swift"
  - "Sunset/Views/OutlookView.swift"
  - "Sunset/Views/SettingsView.swift"
  - "Sunset/Views/ScoreComponents.swift"
  - "SunsetTests/UnfoldedSplitTests.swift"
---

# Sunset: iPhone Duo (2026-10-21, bars and pane cut 2026-10-23)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the TabView
  (Today and Settings, tab bar included) on the leading side of the fold and
  the Outlook on the trailing side; the Outlook tab drops out of the tab bar
  while split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division, .includeInactive)`), else an even split.
  Portrait unfolded (669 pt) and every compact width keep the three tabs.
- Same pattern as Vitals (`jackwallner/vitals`, `Shared/Utilities/UnfoldedSplit.swift`).
  Folding only moves frames, so Today and Settings keep scroll and navigation;
  only the Outlook pane and tab are separate instances.
- Each pane gets `horizontalSizeClass = .compact`; the leading one also
  `isLeadingPane`.
- One navigation everywhere: split, each leading tab's NavigationStack
  applies `horizontalBarsInPane` (`toolbarVerticalBehavior(.disabled)`,
  iOS 27.1), and the trailing pane's screens (Outlook, show detail) apply
  `horizontalBarsInTrailingPane()`. Without it the system drew the tab bar
  as a bottom capsule on some screens and a vertical rail beside the fold
  on others, squeezed the column beside the rail, and moved the trailing
  pane's back button to the top right (review rejected that set,
  2026-10-23). Never on the TabView or the trailing NavigationStack
  themselves: that pillarboxed the app between 44 pt black strips.
- Nothing is ever sliced at the leading pane's floating tab bar: Today, the
  show detail, Settings and the Outlook apply `.clearsPaneBottom()`, which
  in the leading pane masks content a 12 pt gap above the bar. The trailing
  pane has no bar and scrolls to the display edge as on a phone (a cut
  there left a 110 pt empty band under the week). Tagged blocks report their frames: `Card` and
  the Outlook's day cards are `paneCard()`, their rows `paneRow()`, Settings
  rows `paneListRow(section)` and headers `paneListPart(section)`.
  `PaneCut` (tested) moves the cut up to 12 pt below the last whole row
  (rows sit 14 pt apart), rounding the card's corners there, or hides a block whole when no row fits. A new
  card or row in these screens needs the tag, or the line slices it. The
  earlier fade was rejected: it sliced the Streaks and Humidity rows.
  Folded the mask is fully open and nothing reports.
- Onboarding and the full-screen paywall use `.leadingPaneColumn()` before
  their sky, so the column sits in the leading pane and the sky still fills
  the display.
- Captures: one `gh-sim all --device 'iPhone Duo' --dark --args
  "-DemoLocation -DemoForecast -DemoPro"` with one `--screen` per surface:
  `-ScreenshotScene today`, `-ScreenshotScene detail` (hero breakdown beside
  the week), `-ScreenshotScene events` (Up next, sky events, alerts) and
  `-ScreenshotTab 2 -ScreenshotScene day` (Settings beside the best day).
  No `--url`: custom-scheme `simctl openurl` raises an "Open in Sunset?"
  alert. `-DuoTour` (with `-DuoTourFirst`/`-DuoTourStep`) walks the scenes
  for a `gh-sim launch --record-seconds 20` recording. Inner 2853x2007
  landscape, outer 1398x2034.
