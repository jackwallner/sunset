---
paths:
  - "Sunset/Views/ColumnWidth.swift"
  - "Sunset/Views/TodayView.swift"
  - "Sunset/Views/OutlookView.swift"
  - "Sunset/Views/SettingsView.swift"
  - "Sunset/Views/OnboardingView.swift"
  - "Sunset/Views/PaywallView.swift"
  - "Sunset/Views/UnfoldedSplit.swift"
  - "Shared/Services/LocationService.swift"
  - "project.yml"
  - "Sunset/Info.plist"
---

# Sunset: iPad layout (2026-11-12)

Native iPad support: `TARGETED_DEVICE_FAMILY "1,2"` on the app and the widget,
all four orientations (`UISupportedInterfaceOrientations~ipad`), so Split View
and Slide Over work. Once a version ships with iPad it cannot be removed.

- The iPhone Duo split (`UnfoldedSplit`) never applies on iPad
  (`isPad: true` in `MainTabView` and `LeadingPaneColumn`): an iPad is one wide
  screen, not two phone panes. It keeps the system tab bar (top on iPad).
  Every width rule below reads the container's own width (`trackWidth`), not
  the device, so Split View and the Duo panes fall out of the same code.
- `ColumnWidth` holds the numbers. Scroll content is centred with
  `contentMargins(.horizontal, ...)` (the sky and the scroll indicator keep
  the full width): 640 for a reading column (Settings, a single-column Today
  or show), 1240 for two columns and the Outlook grid.
- Today and the show detail go to two columns at 900 pt and wider
  (13-inch portrait and landscape, 11-inch landscape, a wide Split View):
  Today left = hero, summary, Up next; right = score factors, sky events,
  alerts. Below 900 it is the phone column at 640 max. The hero is capped at
  460 pt (420 on the show detail) so a tall iPad does not stretch it.
- Outlook: `DayGrid` lays the day cards in 1, 2 or 3 columns
  (`ColumnWidth.outlookColumns`: 720 and 1100 pt). One column is the plain
  phone stack; more use `Grid` so a row's cards share a height. The unlock
  card over the blurred week is capped at 440 pt.
- Onboarding and the full-screen paywall cap their column at 560 pt, centred;
  the sky still fills the display. Sheets (paywall, alert settings) take the
  system form size.
- Location: the fix is already reduced accuracy, which is what a Wi-Fi-only
  iPad can give. `LocationService` retries a "location unknown" failure three
  times, 3 s apart, before showing the "Use my location" empty state.
- Captures: `gh-sim all --device "iPad Pro 13-inch (M5)" --dark` with the usual
  `-DemoLocation -DemoForecast` args per `--screen`; `-Landscape` (DEBUG)
  turns the app to landscape at launch. App Store size is 2064x2752.
