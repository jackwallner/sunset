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
- Onboarding and the full-screen paywall use `.leadingPaneColumn()` before
  their sky, so the column sits in the leading pane and the sky still fills
  the display.
- Captures: one `gh-sim all --device 'iPhone Duo'` run with
  `-DemoLocation -DemoForecast -DemoPro -ScreenshotTab 0 -DuoTour` and
  `noop://N` URLs as shutter ticks shoots both displays (`ScreenshotRouter`
  walks the scenes on a timer). Custom-scheme `simctl openurl` raises an
  "Open in Sunset?" alert the job cannot tap, so never drive captures by URL.
  Inner 2853x2007 landscape, outer 1398x2034.
