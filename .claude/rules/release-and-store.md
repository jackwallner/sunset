---
paths:
  - "scripts/**"
  - "fastlane/**"
  - "project.yml"
  - "Shared/Services/StoreService.swift"
  - "Sunset.storekit"
---

# Release and store

- Bundle IDs and capabilities: `scripts/asc-register-identifiers.py` (App
  Groups + In-App Purchase on the app, App Groups on the widget).
- App Store Connect app `6821025282` (SKU `sunset`), created in the web UI.
- App Store products: `scripts/asc-setup-subscriptions.py` (group `Sunset
  Plus`, yearly level 1, monthly level 2, 1-week trials in every territory,
  PPP tiers, equalized prices elsewhere), `scripts/asc-setup-lifetime-iap.py`,
  then `scripts/asc-finish-products.py --screenshot <paywall png>`. All
  idempotent.
- RevenueCat project `proj2164a1b0`, App Store app `appe9464d150c` (fleet IAP
  key K968FW2N5M, ASC key 27M3333KDW), entitlement `pro`, offering `default`
  with `$rc_annual`, `$rc_monthly`, `$rc_lifetime`. Built with the `rc` CLI;
  `scripts/rc-setup.py` repairs it if a product goes missing. The public
  `appl_` key is in `RevenueCatConfig.publicSDKKey`; configure is always
  skipped on the simulator.
- Pricing: Vitals structure. Monthly $1.99 and yearly $14.99 both carry a
  1-week free trial; lifetime $29.99. Apply the PPP ladder with
  `~/ios/pricing/` once the products exist.
- Listing fields fastlane does not set (age rating, categories Weather +
  Photo & Video, copyright, content rights, review contact and notes):
  `ASC_REVIEW_PHONE=... scripts/asc-complete-listing.py`. Customer-facing
  product names and review notes: `scripts/asc-rebrand-sun-plus.py`.
- First IAP submission must be attached to the version in the ASC web UI
  (`ios-dev` skill, "Submitting IAPs with a version"). The group reference name
  stays `Sunset Plus` (immutable); every localized name says Sun+.
- TestFlight: `./scripts/testflight.sh` bumps the build, archives, uploads,
  and commits the bump.

## History

- 2026-10-08: scaffolded from scratch (Open-Meteo, not WeatherKit, to avoid
  a new capability and match `~/headaches`). Unit tests pin the scorer and
  the Open-Meteo parser.
- 2026-10-09: ASC record, products, and RevenueCat project created. Launch
  no longer fires the location prompt before onboarding's button.
- 2026-10-09: sunrise scoring, sky events (storms, rainbow chances, fog),
  free alerts, four-page onboarding with the Sun+ offer, Sunset+ renamed Sun+
  (app and ASC localizations). Store name `Sunset & Sunrise Forecast`,
  subtitle `Scores, storm & rainbow alerts`.
- 2026-10-10: build 3 attached to 1.0; age rating, categories, free price,
  review contact and listing text set; six 6.9" screenshots from
  `~/ios/appstore-screenshots/configs/sunset.json` (capture flows use
  `-DemoForecast` and `-ScreenshotScene`) synced with `asc-sync-screenshots`.
  IAP review screenshots replaced with the Sun+ paywall. Draft review
  submission `c4b759f2-13a3-4000-ba7f-25dbead13d73` holds the group, both
  subscriptions and lifetime. The version itself cannot join until App Privacy
  answers are published in the web UI (APP_DATA_USAGES_REQUIRED).
- 2026-10-10: TestFlight crash on build 2 and 3: the BGAppRefresh handler
  inherited main-actor isolation and ran on a background queue, tripping the
  Swift 6 isolation check. Register with `using: .main`. ASO: name `Sunset &
  Sunrise Prediction` ("sunset prediction" pop 16, diff 21 in Astro, app 136),
  subtitle `Golden Hour Forecast & Alerts` ("golden hour app" 13/17).
