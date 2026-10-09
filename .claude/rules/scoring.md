---
paths:
  - "Shared/Utilities/SunsetScorer.swift"
  - "Shared/Services/ForecastService.swift"
  - "SunsetTests/**"
---

# Scoring model

The score is heuristic, built from what sunset forecasters agree on rather
than fitted to data. Keep the shape; tune numbers only with a test that pins
the reason.

- **Color** (weight 0.6): bell curves on high cloud (peak 50%, width 32) and
  mid cloud (peak 35%, width 30), floor 30 so a clear sky still reads as a
  clean gold fade, not a failure.
- **Streaks** (0.2): the high-cloud bell shaded by mid and low cloud that
  would hide cirrus.
- **Clarity** (0.2): visibility 5 to 25 km and humidity 95 to 45% map to 0
  to 1 and average.
- **Horizon** is a gate, not a term: `0.15 + 0.85 * horizon^1.5`, where horizon is
  `1 - (0.35 * lowHere + 0.65 * lowWest)`. Low cloud toward the sun hides the
  show even under open sky overhead.
- **Rain**: precipitation probability 40 to 70% scales by 0.8, above 70% by
  0.55.

The west point sits 80 km toward the sunset at the same latitude, clamped to
3 degrees near the poles. Both points come back in one Open-Meteo request as a
two-element array; a one-element response is rejected so a silent fallback
cannot score the wrong sky.

Sunset-minute conditions are a linear blend of the hourly rows either side of
the daily `sunset` time, in the response's own time zone.

Grades: Dull < 30, Fair < 50, Good < 70, Great < 85, Epic.
