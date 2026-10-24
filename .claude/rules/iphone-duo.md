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

# Sunset: iPhone Duo (2026-10-21, bars, pane cut, status column and pane detail 2026-10-23)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the TabView
  (Today and Settings, tab bar included) on the leading side of the fold and
  the Outlook on the trailing side; the Outlook tab drops out of the tab bar
  while split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division, .includeInactive)`), else an even split.
  Portrait unfolded (669 pt) and every compact width keep the three tabs.
- The trailing pane never pushes (`PaneDetail`, tested): a show tapped in
  the Outlook there opens on Today in the leading pane, whichever leading
  tab was up, and its row stays lit. Review rejected a pushed day detail in
  the trailing pane (back button beside the fold, bar crowding the top
  edge), 2026-10-23. Folded, the Outlook pushes as on a phone.
  The detail there sizes its hero like Today (`PaneFill`), so the summary
  ends on the bar line instead of above an empty band where the too-tall
  factors card was hidden. Both measure the viewport as the scroll view's
  `size.height`: that size already sits inside the nav and tab bars while
  the proxy still reports their insets, and subtracting them counted the
  bars twice (logged: size 504, insets 82 and 83), pinning both heroes to
  their minimum.
- Same pattern as Vitals (`jackwallner/vitals`, `Shared/Utilities/UnfoldedSplit.swift`).
  Folding only moves frames, so Today and Settings keep scroll and navigation;
  only the Outlook pane and tab are separate instances.
- Each pane gets `horizontalSizeClass = .compact`; the leading one also
  `isLeadingPane`.
- One navigation everywhere: split, each leading tab's NavigationStack
  applies `horizontalBarsInPane` (`toolbarVerticalBehavior(.disabled)`,
  iOS 27.1), so the tab bar is always the bottom capsule. Without it the
  system drew a bottom capsule on some runtimes and a vertical rail beside
  the fold on others, squeezing the column (review rejected that set,
  2026-10-23). Never set it in the trailing pane: on its stack or on its
  screens, SwiftUI laid the whole root out 42 pt in from both display edges
  with zero side safe area (logged 2026-10-23: window 951 wide, root at
  x 42, width 867), so black strips framed the app. The trailing pane keeps
  the system's vertical status column.
- No pane ever shows half a row: Today, the show detail, Settings and the
  Outlook apply `.clearsPaneBottom()`. In the leading pane the line is a
  12 pt gap above the floating tab bar; in the trailing pane (no bar) it is
  the display edge, as on a phone. Tagged blocks report their frames:
  `Card` and the Outlook's day cards are `paneCard()`, their rows
  `paneRow()`, Settings rows `paneListRow(section)` and headers
  `paneListPart(section)`. `PaneCut` (tested) moves the cut up to 12 pt
  below the last whole row (rows sit 14 pt apart), rounding the card's
  corners there, or hides a block whole when no row fits. A new card or
  row in these screens needs the tag, or the line slices it. The earlier
  fade was rejected: it sliced the Streaks and Humidity rows. Settings
  uses compact section spacing in the leading pane so its Location rows
  fit above the bar instead of leaving a 100 pt gap.
- Today's column ends with 80 pt of bottom padding in the leading pane (24
  folded), so the `events` scene can scroll Up next to the top instead of
  stopping under a sliver of the factors card.
- Today in the leading pane opens on whole cards: the factors show as a
  2x2 `FactorGrid` (no detail lines) and the hero takes the height the
  summary and factor cards leave above the bar line (`PaneFill`, tested).
  The full rows were cut to "Color" alone, which review read as a clipped
  breakdown (2026-10-23). `SkyHero` fills the height its caller proposes;
  its old fixed 300 pt overflowed the shorter frames and hid the title
  row under the detail header.
- The trailing pane's trailing safe area (~85 pt, full height) is iOS
  27.1's vertical status column: clock over the connectivity ring, with
  its backing ending 112 pt down. `fillsTrailingPane()` lays the Outlook
  out under it so both margins are 16 pt.
  `clearsStatusClock()` (Outlook) pads the week 36 pt so the first card
  starts below the clock (`StatusColumn`); a top content margin computed
  from the measured content top never applied, so the padding is fixed.
  To keep the last day card whole, trailing day cards space rows 10 pt
  (cut style `tightCard`, 8 pt) and cards 8 pt. Review rejected the
  earlier set for the ~100 pt dead column (2026-10-23).
  Folded the mask is fully open and nothing reports.
- Onboarding and the full-screen paywall use `.leadingPaneColumn()` before
  their sky, so the column sits in the leading pane and the sky still fills
  the display.
- Captures: one `gh-sim all --device 'iPhone Duo' --dark --args
  "-DemoLocation -DemoForecast -DemoPro"` with one `--screen` per surface:
  `-ScreenshotScene today`, `-ScreenshotScene detail` (hero breakdown beside
  the week), `-ScreenshotScene events` (Up next, sky events, alerts),
  `-ScreenshotScene day` (the best free show after the next, opened from
  the Outlook: its detail on the left, its row lit on the right) and
  `-ScreenshotTab 2` (Settings beside the Outlook).
  No `--url`: custom-scheme `simctl openurl` raises an "Open in Sunset?"
  alert. The router opens the launch scene 0.6 s after the UI appears:
  pushed in the first frame, the folded detail raced the tab rail's setup
  and a UIKit assert storm left that capture blank (2026-10-23). `-DuoTour` (with `-DuoTourFirst`/`-DuoTourStep`) walks the scenes
  for a `gh-sim launch --record-seconds 20` recording. Inner 2853x2007
  landscape, outer 1398x2034.
