---
paths:
  - "android/**"
  - "scripts/android-*"
  - "scripts/sync-android-*"
---

# Sunset Android rules

## Product

- Native port in `android/`: Kotlin, Compose, Gradle Kotlin DSL, JDK 17,
  minSdk 26, target/compile 36. Package and namespace `com.jackwallner.sunset`
  (permanent once uploaded), launcher label "Sunset", Play title
  "Sunset & Sunrise Prediction". versionName follows iOS `MARKETING_VERSION`
  (1.0.1), versionCode 1 (bump before every upload).
- Screen for screen with iOS: four-page onboarding (welcome, watch, free
  alerts with the notification prompt, Sun+ offer buying monthly with "Get
  Started" as the free exit) > tabs Today / Outlook / Settings; show detail
  pushes from the side, Alerts and the paywall slide up as sheets. Overlays
  are a stack in `AppGraph.Navigator`; Back pops them, then returns to Today.
- Pure model in `model/` is a straight port of `Shared/Models` and
  `Shared/Utilities` (scorer, sky events, solar position, copy helpers,
  `NotificationService.plan` as `AlertPlanner`, `DemoForecast`).
  `scripts/sync-android-parity.sh` compiles the real Swift sources with
  `scripts/android-export/main.swift` into
  `app/src/test/resources/sunset-parity.json`; `PortParityTest` checks 5,760
  scored skies (all 15 summaries), 320 sun elevations, 4,212 sky-event cases,
  six request URLs, two parsed forecasts (incl. a London DST day), 216 alert
  plans (2,743 alerts), the copy helpers and the demo week. Rerun it whenever
  those Swift files change. The command-line Swift on the fleet Macs is 5.7,
  so `android-export/legacy_swift.py` adds `return` to switch-expression arms
  in a temporary copy; `Shared/` is never modified.
- Platform equivalents: CoreLocation reduced accuracy = `ACCESS_COARSE_LOCATION`
  with one `LocationManager.getCurrentLocation` fix; the rounded point goes to
  the system `Geocoder` for the town name. App Group = SharedPreferences
  `sunset` under the iOS keys. UNCalendarNotificationTrigger = inexact
  `AlarmManager.setWindow` (10-minute window, no exact-alarm declaration),
  rebuilt on boot/update/time-zone change. BGAppRefresh = WorkManager periodic
  work every 3 hours. WidgetKit = a RemoteViews `AppWidgetProvider`
  (`widget/SunsetWidget.kt`), refreshed every 30 minutes by the system and on
  every fetch; a stale snapshot asks the worker to fetch.
- Intentional differences from iOS: Play In-App Review on the third open with
  a score of 60 or more, once, with no question first (Play policy); Settings
  "Rate Sunset" opens the Play listing; purchase copy names Google Play;
  Terms link to the site's terms.html instead of Apple's EULA; a Back button
  on the detail screen; the 12/24-hour clock follows the Android setting.
  Locked outlook days blur on API 31+ and fade to 12% below it (no blur API).
- Paid boundary = iOS: free gets today and tomorrow in Outlook, the factors,
  the widget, sunrise/sunset alerts at 70 and 45 min. Sun+ (`pro`
  entitlement) gets the full week, storm/rainbow/fog alerts, custom score and
  lead. Free alerts always use the defaults even if a lapsed subscriber
  picked others (`AlertSettings.effective*`).
- Billing: RevenueCat project `proj2164a1b0` (shared with iOS), entitlement
  `pro`, offering `default` with `$rc_annual`, `$rc_monthly`, `$rc_lifetime`.
  Products `com.jackwallner.sunset.monthly` / `.yearly` (Play subscriptions,
  base plans `monthly` / `yearly`, 7-day free-trial offer `trial-7d`) and
  `.lifetime` (one-time product). Debug builds use `REVENUECAT_TEST_KEY`,
  release needs `REVENUECAT_PLAY_KEY` (`goog_`); neither runs in the other.
  As of 2026-10-20 neither key exists: no Test Store or Play app in the
  RevenueCat project. Debug runs use `previewStore` (the `Sunset.storekit`
  prices) until a Test Store key is added.
- Reviewer access: Settings > long-press the version line, code
  `PLAY_REVIEW_CODE` in jmbp `~/.sunset_credentials` (created 2026-10-20);
  only `PLAY_REVIEW_CODE_SHA256` goes in the ignored `local.properties`.
- Debug launch extras (`src/debug/.../DebugLaunchOptions.kt`, absent from
  release and QA): `demoLocation`, `demoForecast`, `demoPro`, `previewStore`,
  `previewTrialUsed`, `onboardingStep <n>`, `tab outlook|settings`,
  `screen detail|events|alerts|paywall`, `uiTest`, `resetAll`, `opens <n>`.

## Build and test (fleet Pro, jmbp)

- `fm-gradle clean assembleDebug assembleDebugAndroidTest assembleQa lintDebug testDebugUnitTest`
  from `android/` (runs on jmbp; never `./gradlew` on the Air).
- Connected tests: boot a leased AVD headless (`emulator -avd agent-emu-1
  -port 5556 -no-window -no-audio -no-boot-anim -no-metrics -gpu host -cores 3
  -no-snapshot-save`), then `ANDROID_SERIAL=emulator-5556
  scripts/android-connected-tests.sh [--no-build]`. One UI Automator test per
  process with `pm clear` between, reviewer code passed as an instrumentation
  argument, JUnit XML at
  `android/app/build/outputs/androidTest-results/connected/TEST-sunset-smoke.xml`.
  The live-forecast test needs network (Open-Meteo). Stop the AVD with
  `adb -s emulator-5556 emu kill`. Never touch `small_phone` or another
  agent's device.
- Store screenshots: `ANDROID_SERIAL=emulator-5556 scripts/android-capture-screens.sh`
  (demo week, free state, status bar demo mode) into
  `android/play-assets/metadata/android/en-US/images/phoneScreenshots/`.
  Play art: `scripts/make-play-graphics.py` (needs Pillow).
- jmbp is an Intel i7-5557U: emulator motion records at about 12 fps, so
  native 60 fps cannot be proven there. Motion review belongs on the Air.

## Release state (2026-10-21)

- Engineering acceptance done on jmbp (run shift-android-sunset-1-1792547912):
  46 JVM tests (full iOS parity), 12 device tests on agent-emu-1 (API 36 Play
  image), build and lint clean (0 errors), QA (R8) build ignores debug hooks
  and runs onboarding to a live forecast.
- Done 2026-10-21: RevenueCat Test Store and Play apps in `proj2164a1b0`,
  upload keystore `~/.android/keystores/sunset-upload.p12` (password in
  `~/.sunset_credentials`), `REVENUECAT_TEST_KEY`, `REVENUECAT_PLAY_KEY`,
  `PLAY_UPLOAD_*` and the review code hash in `local.properties` on the Air,
  rc-clean registered on the Air and MBP, listing graphics and screenshots made.
- Remaining, in order (Air release worker / Console):
  1. Jack: the Android US price (keep iOS $1.99 / $14.99 / $29.99, or the
     fleet's about 20% lower ladder).
  2. Play app record (E3 Apps). Play hit its weekly new-app limit on 2026-10-21;
     retry the next week. The name matches the App Store name.
  3. The three products with `trial-7d` offers, attached to the `default`
     offering packages and the `pro` entitlement without touching the iOS
     ones; grant the RevenueCat service account on the new app.
  4. Build and verify the signed AAB/APK (package, versionCode 1, targetSdk 36,
     16 KB alignment of every native library). Listing, graphics, screenshots
     (composite to 1080 x 1920) and App content answers from
     `android/play-assets/listing-en-US.md`. Publish the updated
     `docs/privacy-policy.html` and `docs/terms.html` first.
  5. Internal track upload, licensed-tester purchase and restore, pre-launch
     report, then a production draft. The production send waits for its
     pacing slot (`~/docs/android/fleet-rollout-2026-10-15.md`).
