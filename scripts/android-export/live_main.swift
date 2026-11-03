// Parses the recorded live Open-Meteo responses in android/app/src/test/resources/live
// with the real iOS sources and writes live-expected.json and live-plan-expected.json
// for LiveResponseParityTest and LivePlanParityTest. Built by
// scripts/sync-android-live.sh. Each place's request point comes from places.json.
import Foundation

let resources = URL(fileURLWithPath: CommandLine.arguments[1])
let fetched = Date(timeIntervalSince1970: 1_793_440_000)
let planKeys: [(now: Double, threshold: Int, lead: Int)] = [
    (1_793_440_000, 0, 120), (1_793_440_000, 0, 45), (1_793_461_600, 70, 45),
    (1_793_501_200, 0, 45), (1_793_701_660, 0, 45),
]

func epoch(_ date: Date) -> Int { Int(date.timeIntervalSince1970) }

let placesData = try Data(contentsOf: resources.appendingPathComponent("live/places.json"))
let places = try JSONSerialization.jsonObject(with: placesData) as! [String: [String: Double]]

var expected: [String: Any] = [:]
var planExpected: [String: Any] = [:]
for (city, point) in places {
    let lat = point["lat"]!, lon = point["lon"]!
    let json = try Data(contentsOf: resources.appendingPathComponent("live/\(city).json"))
    let forecast = try ForecastService.parse(json, latitude: lat, longitude: lon, now: fetched)
    let shows: [[String: Any]] = forecast.days.flatMap { [$0.sunrise, $0.sunset] }.map { show in
        let c = show.conditions, s = show.score
        return ["event": show.event.rawValue, "t": epoch(show.time),
                "low": c.cloudLow, "mid": c.cloudMid, "high": c.cloudHigh, "toward": c.cloudLowTowardSun,
                "hum": c.humidity, "vis": c.visibility, "pop": c.precipitationChance,
                "score": s.total, "color": s.color, "streaks": s.streaks, "horizon": s.horizon,
                "clarity": s.clarity, "rain": s.rainChance, "summary": s.summary]
    }
    let events: [[String: Any]] = forecast.skyEvents.map {
        ["start": epoch($0.start), "kind": $0.kind.rawValue, "end": epoch($0.end)]
    }
    expected[city] = ["lat": lat, "lon": lon, "tz": forecast.timeZoneID, "shows": shows, "events": events]

    var plans: [String: Any] = [:]
    for key in planKeys {
        let planned = NotificationService.plan(
            forecast: forecast, watched: Set(SunEvent.allCases), threshold: key.threshold,
            leadMinutes: key.lead, skyEventKinds: Set(SkyEvent.Kind.allCases),
            now: Date(timeIntervalSince1970: key.now)
        )
        plans["\(Int(key.now))|\(key.threshold)|\(key.lead)"] = planned.map {
            [$0.identifier, epoch($0.fireDate), $0.title, $0.body] as [Any]
        }
    }
    planExpected[city] = ["lat": lat, "lon": lon, "plans": plans]
}

for (name, object) in [("live-expected.json", expected), ("live-plan-expected.json", planExpected)] {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try data.write(to: resources.appendingPathComponent(name))
}
print("Wrote \(places.count) places")
