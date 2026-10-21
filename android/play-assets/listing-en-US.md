# Sunset Android: Play listing and policy answers

Prepared 2026-10-20 from the actual Android build (`android/`), not from iOS
assumptions. Text files for upload are in `metadata/android/en-US/`.

## Store listing

- App name: `Sunset & Sunrise Prediction` (27 of 30)
- Short description (76 of 80): `Golden hour forecast: a score for every sunrise and sunset, with free alerts`
- Full description: `metadata/android/en-US/full_description.txt` (2,357 of 4,000).
  No prices, no em dashes, no promise of what the sky will do, Google Play
  billing wording.
- Category: Weather. Tags: weather, photography.
- Contact email: jackwallner@gmail.com. Website: https://jackwallner.github.io/sunset/
- Privacy policy: https://jackwallner.github.io/sunset/privacy-policy.html
  (Android wording added 2026-10-20 in `docs/privacy-policy.html`; publishes
  with the next push of `docs/`).
- Graphics: `graphics/icon-512.png` (from the iOS 1024 icon),
  `graphics/feature-1024x500.png` (`scripts/make-play-graphics.py`).
- Phone screenshots: `metadata/android/en-US/images/phoneScreenshots/`, real
  emulator captures of the debug build on the demo week (free state unless
  noted), 1080 x 2400 raw. Play rejects ratios over 2:1, so composite to
  1080 x 1920 before upload (see `~/mahj/scripts/play_screenshot_compositor.py`
  on the Air).

## App content answers

- Ads: no ads.
- App access: everything works without an account. Sun+ for review: Settings,
  long-press the version line at the bottom, enter the reviewer code
  (`PLAY_REVIEW_CODE` in `~/.sunset_credentials` on jmbp; copy it into the
  App access instructions, never into the repo). The app needs location
  permission (approximate) to load a forecast; an emulator location works.
- Target audience: 13 and over (matches the iOS policy: not directed at
  children). Content rating (IARC): no violence, no user content, no sharing
  of location with other users, digital purchases yes. Expect Everyone / PEGI 3.
- Government app: no. Financial features: none. Health: none (no health or
  mood claims anywhere). News: no.
- Advertising ID: not used. Merged manifest has no `AD_ID` permission.
- Foreground service: none (`FOREGROUND_SERVICE` removed from the merged
  manifest). Exact alarms: none (inexact `setWindow`).
- Permissions: `ACCESS_COARSE_LOCATION` (one approximate fix for the forecast
  region), `POST_NOTIFICATIONS` (alerts, asked on the alerts page or the
  Alerts screen), `RECEIVE_BOOT_COMPLETED` (re-arm alerts), `INTERNET`,
  `ACCESS_NETWORK_STATE`, `BILLING` (RevenueCat), `WAKE_LOCK` (WorkManager).

## Data safety

| Data type | Collected | Shared | Why | Notes |
| --- | --- | --- | --- | --- |
| Approximate location | Yes | No | App functionality | Rounded to about 1 km and sent to Open-Meteo (a service provider) for the forecast; also to the system geocoder for a town name. Stored only on the device. |
| Purchase history | Yes | No | App functionality | RevenueCat validates Google Play purchases (service provider). |
| Device or other IDs | Yes | No | App functionality | RevenueCat's anonymous app user ID. |

- Encrypted in transit: yes (HTTPS to Open-Meteo and RevenueCat).
- Deletion: no account exists. Uninstalling removes everything on the device;
  RevenueCat purchase records can be deleted on request by email.
- Not collected: precise location, personal info, contacts, health, photos,
  messages, app activity, analytics, crash logs.

## Products (unchanged from iOS)

- `com.jackwallner.sunset.monthly`: subscription, base plan `monthly`,
  offer `trial-7d` (7-day free trial, new customers).
- `com.jackwallner.sunset.yearly`: subscription, base plan `yearly`, offer
  `trial-7d`.
- `com.jackwallner.sunset.lifetime`: one-time product.
- iOS US prices: $1.99 / $14.99 / $29.99. The Android US price is Jack's call
  (fleet rule is about 20% under iOS; these are already the low Vitals
  ladder). Review Play's generated local prices against the iOS PPP ladder
  before activating.
