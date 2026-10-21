#!/bin/bash
# Compiles the real iOS model, scorer, detector, parser and alert planner with
# scripts/android-export/main.swift and writes what they compute to
# android/app/src/test/resources/sunset-parity.json, which PortParityTest
# compares against the Kotlin port. Rerun whenever those Swift files change.
#
# The command-line Swift on the fleet Macs can be older than the app's
# (switch expressions arrived in 5.9), so a temporary copy of each file gets
# `return` added to single-expression switch arms. The sources in Shared/ are
# never modified.
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
  "$repo/Shared/Services/DemoForecast.swift" \
  "$repo/Shared/Services/NotificationService.swift"

swiftc -D DEBUG -O -o "$work/export" "$work"/*.swift "$repo/scripts/android-export/main.swift"
out="$repo/android/app/src/test/resources/sunset-parity.json"
"$work/export" > "$out"
echo "Wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
