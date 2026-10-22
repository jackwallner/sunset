---
paths:
  - "Sunset/App.swift"
  - "Sunset/Views/UnfoldedSplit.swift"
  - "Sunset/Views/TodayView.swift"
  - "Sunset/Views/OutlookView.swift"
---

# Sunset: iPhone Duo (2026-10-21)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the TabView
  (Today and Settings, tab bar included) on the leading side of the fold and
  the Outlook on the trailing side; the Outlook tab drops out of the tab bar
  while split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division, .includeInactive)`), else an even split.
  Portrait unfolded (669 pt) and every compact width keep the three tabs.
- Same pattern as Vitals (`jackwallner/vitals`, `Shared/Utilities/UnfoldedSplit.swift`).
  Folding only moves frames, so Today and Settings keep scroll and navigation;
  only the Outlook pane and tab are separate instances.
- Each pane gets `horizontalSizeClass = .compact`, which also keeps the
  system tab bar at the bottom as on a phone.
- The floating tab bar never sits over content: in the leading pane
  (`paneHasFloatingTabBar`), Today, the show detail and Settings apply
  `.clearsFloatingTabBar()`, which masks scroll content to fade out just
  above the bar's safe-area edge. Folded, the mask is fully opaque and the
  phone look is unchanged. A shots review (2026-10-22) rejected captures
  with the capsule over factor rows.
- Onboarding and the full-screen paywall use `.leadingPaneColumn()` before
  their sky, so the column sits in the leading pane and the sky still fills
  the display.
- Captures: gh-sim takes one shot per display after `--wait`, and no
  `--url` (custom-scheme `simctl openurl` raises an "Open in Sunset?" alert
  the job cannot tap; never pass fake URLs as shutter ticks). So each inner
  surface is its own `gh-sim launch --device 'iPhone Duo'` with
  `-DemoLocation -DemoForecast -DemoPro` plus `-ScreenshotScene <scene>`
  (`detail`, `events`) or `-ScreenshotTab 2 -ScreenshotScene day` (Settings
  beside the best day). The `all` run adds `-DuoTour` with
  `--record-seconds 25 --wait 26`: the tour walks detail, day, events and
  Settings once for the recording, then settles on Today before the shot.
  Inner 2853x2007 landscape, outer 1398x2034.
