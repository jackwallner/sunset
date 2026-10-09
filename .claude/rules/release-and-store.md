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
- First IAP submission must be attached to the version in the ASC web UI
  (`ios-dev` skill, "Submitting IAPs with a version").
- TestFlight: `./scripts/testflight.sh` bumps the build, archives, uploads,
  and commits the bump.

## History

- 2026-10-08: scaffolded from scratch (Open-Meteo, not WeatherKit, to avoid
  a new capability and match `~/headaches`). Unit tests pin the scorer and
  the Open-Meteo parser.
- 2026-10-09: ASC record, products, and RevenueCat project created. Launch
  no longer fires the location prompt before onboarding's button.
