---
paths:
  - "Shared/Utilities/SunsetScorer.swift"
  - "Shared/Services/ForecastService.swift"
  - "Shared/Utilities/SkyEventDetector.swift"
  - "SunsetTests/**"
---

# Scoring model

The score is heuristic, built from what sunset forecasters agree on rather
than fitted to data. Keep the shape; tune numbers only with a test that pins
the reason.

- **Color** (weight 0.6): each layer earns credit across a band, not at one
  ideal number. High cloud: 0 at clear, full from 20% to 70%, down to 0.25 at
  100%. Mid cloud: full from 15% to 50%, gone at 90%. Either layer alone can
  make the show (`1 - (1 - high) * (1 - 0.9 * mid)`), and the floor is 40 so a
  clear sky still reads as a clean gold fade, not a failure.
  Until 1.0.3 these were narrow bells (high peak 50% width 32, mid 35% width
  30) added 65/35, floor 30. Real skies rarely stack both layers at their
  peak, so only 2.7% of shows reached the default alert score of 70 (Open-Meteo,
  92 days to 2026-11-03, 24 cities, 4,415 shows): about one sunset alert a
  month. The band model gives 9.1% at 70+ and 4.3% at 85+ on the same data,
  about 3.3 sunset alerts a month, with clear sky still about 40 and overcast
  about 8. Thresholds and grades did not change. On the recorded 51-city live
  week, shows at 70+ went from 25 to 86 of 816.
- **Streaks** (0.2): the high-cloud band shaded by mid and low cloud that
  would hide cirrus.
- **Clarity** (0.2): visibility 5 to 25 km and humidity 95 to 45% map to 0
  to 1 and average.
- **Horizon** is a gate, not a term: `0.15 + 0.85 * horizon^1.5`, where horizon is
  `1 - (0.35 * lowHere + 0.65 * lowTowardSun)`. Low cloud toward the sun hides the
  show even under open sky overhead.
- **Rain**: precipitation probability 40 to 70% scales by 0.8, above 70% by
  0.55.

Sunrise and sunset use the same model; only the sunward point and the copy
differ. The west point sits 80 km toward the sunset and the east point 80 km
toward the sunrise, same latitude, clamped to 3 degrees near the poles. All
three points come back in one Open-Meteo request as a three-element array;
anything shorter is rejected so a silent fallback cannot score the wrong sky.

Conditions at the minute are a linear blend of the hourly rows either side of
the daily `sunrise`/`sunset` time.

Open-Meteo writes every time label of a point (hourly and daily) on one fixed
clock, its `utc_offset_seconds`: the offset in force when the request was made,
kept for the whole window, with 24 labels a day even across a daylight saving
change (checked 2026-10-31: Sydney's 2026-10-04 spring-forward day still has a
`02:00` row). Read the labels with `TimeZone(secondsFromGMT:)`, never with the
named zone: the named zone refuses the gap hour (the whole forecast failed for
the week before a spring-forward) and puts every day after a fall-back an hour
late. The named zone is for display only, and for responses that carry no
offset. `timezone=auto` also gives each of the three points its own clock (an
ocean point is `Etc/GMT+8` beside Los Angeles at UTC-7), so the sunward rows are
matched to the user's hours by moment, never by row index. The Android parity
fixtures that drop the London gap hour are synthetic; the live API does not.

Sky events (`SkyEventDetector`), per hour at the user's point, merged into
runs: thunderstorm = WMO code 95 to 99; fog = code 45/48 or visibility under
1 km; rainbow chance = drizzle/rain/shower code with at least 0.1 mm and 35%
chance, total cloud 20 to 75%, and the sun 2 to 42 degrees up.

Grades: Dull < 30, Fair < 50, Good < 70, Great < 85, Epic.
