#!/bin/bash
# Captures the Play phone screenshots from the debug build on a booted
# emulator: the fixed demo week (Vancouver, WA), free state, preview prices,
# status bar in demo mode. Writes raw 1080 x 2400 PNGs.
#
#   ANDROID_SERIAL=emulator-5556 scripts/android-capture-screens.sh [out-dir]
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
serial="${ANDROID_SERIAL:?set ANDROID_SERIAL to the leased emulator}"
out="${1:-$repo/android/play-assets/metadata/android/en-US/images/phoneScreenshots}"
adb=("$HOME/Library/Android/sdk/platform-tools/adb" -s "$serial")
pkg="com.jackwallner.sunset"
mkdir -p "$out"

"${adb[@]}" shell settings put global sysui_demo_allowed 1
demo() { "${adb[@]}" shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo enter
demo clock -e hhmm 0941
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile hide
demo battery -e level 100 -e plugged false
demo notifications -e visible false

shot() {
  local name="$1"; shift
  "${adb[@]}" shell pm clear "$pkg" >/dev/null
  "${adb[@]}" shell am start -n "$pkg/.MainActivity" "$@" >/dev/null
  sleep 9
  "${adb[@]}" exec-out screencap -p > "$out/$name.png"
  echo "$out/$name.png"
}

base=(--ez demoLocation true --ez demoForecast true --ez previewStore true)
shot 01-today "${base[@]}" --es screen today
shot 02-detail "${base[@]}" --es screen detail
shot 03-outlook "${base[@]}" --es tab outlook
shot 04-events "${base[@]}" --es screen events
shot 05-alerts "${base[@]}" --es screen alerts
shot 06-onboarding --ez previewStore true --ei onboardingStep 0
shot 07-offer --ez previewStore true --ei onboardingStep 3
shot 08-paywall "${base[@]}" --es screen paywall
shot 09-settings "${base[@]}" --es tab settings
"${adb[@]}" shell pm clear "$pkg" >/dev/null
demo exit
