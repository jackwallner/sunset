#!/bin/bash
# Rewrites android/app/src/test/resources/live-expected.json and
# live-plan-expected.json from the recorded live responses in
# android/app/src/test/resources/live, using the real iOS sources. Rerun
# whenever the scorer, parser, detector or alert planner changes, alongside
# scripts/sync-android-parity.sh.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python3 "$repo/scripts/android-export/legacy_swift.py" "$work" \
  "$repo/Shared/Models/SunsetForecast.swift" \
  "$repo/Shared/Utilities/SunsetScorer.swift" \
  "$repo/Shared/Utilities/SkyEventDetector.swift" \
  "$repo/Shared/Utilities/SunsetFormat.swift" \
  "$repo/Shared/Services/ForecastService.swift" \
  "$repo/Shared/Services/NotificationService.swift"

cp "$repo/scripts/android-export/live_main.swift" "$work/main.swift"
swiftc -D DEBUG -O -o "$work/export" "$work"/*.swift
"$work/export" "$repo/android/app/src/test/resources"
