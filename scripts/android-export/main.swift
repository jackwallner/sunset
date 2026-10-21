// Writes what the real iOS sources compute, as JSON on stdout, for the
// Android PortParityTest. Built by scripts/sync-android-parity.sh.
import Foundation

let la = TimeZone(identifier: "America/Los_Angeles")!

func epoch(_ date: Date) -> Double { date.timeIntervalSince1970 }

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0, zone: TimeZone = la) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

var summaries: [String] = []
func summaryIndex(_ text: String) -> Int {
    if let i = summaries.firstIndex(of: text) { return i }
    summaries.append(text)
    return summaries.count - 1
}

// 1. Scorer over a grid of skies, both events.
var scores: [[Double]] = []
for low in [0.0, 30, 60, 90] {
    for mid in [0.0, 20, 45, 80] {
        for high in [0.0, 25, 50, 75, 100] {
            for toward in [0.0, 40, 85] {
                for humidity in [40.0, 95] {
                    for visibility in [4_000.0, 30_000] {
                        for rain in [0.0, 50, 80] {
                            for (eventIndex, event) in [SunEvent.sunrise, .sunset].enumerated() {
                                let sky = SkyConditions(cloudLow: low, cloudMid: mid, cloudHigh: high, cloudLowTowardSun: toward,
                                                        humidity: humidity, visibility: visibility, precipitationChance: rain)
                                let s = SunsetScorer.score(sky, event: event)
                                scores.append([low, mid, high, toward, humidity, visibility, rain, Double(eventIndex),
                                               Double(s.total), Double(s.color), Double(s.streaks), Double(s.horizon),
                                               Double(s.clarity), Double(s.rainChance), Double(summaryIndex(s.summary))])
                            }
                        }
                    }
                }
            }
        }
    }
}

// 2. Sun elevation every 3 hours for ten days at four places.
let places: [(Double, Double)] = [(45.63, -122.52), (-33.9, 151.2), (64.1, -21.9), (0, 0)]
var solar: [[Double]] = []
let solarStart = date(2026, 3, 15, 0, zone: TimeZone(identifier: "UTC")!)
for step in 0 ..< 80 {
    let time = solarStart.addingTimeInterval(Double(step) * 3 * 3600)
    for place in places {
        solar.append([epoch(time), place.0, place.1, SolarPosition.elevation(at: time, latitude: place.0, longitude: place.1)])
    }
}

// 3. Sky event kinds over a grid of hours (-1 stands for a missing value).
let kindOrder: [SkyEvent.Kind] = [.thunderstorm, .rainbow, .fog]
var kinds: [[Double]] = []
for code in [-1, 0, 3, 45, 48, 51, 61, 63, 65, 80, 82, 95, 99] {
    for cover in [-1.0, 10, 50, 90] {
        for precipitation in [-1.0, 0, 0.5] {
            for chance in [-1.0, 20, 60] {
                for visibility in [-1.0, 500, 20_000] {
                    for elevation in [-5.0, 10, 50] {
                        let hour = SkyEventDetector.Hour(
                            time: Date(timeIntervalSince1970: 0),
                            weatherCode: code < 0 ? nil : code,
                            cloudCover: cover < 0 ? nil : cover,
                            precipitation: precipitation < 0 ? nil : precipitation,
                            precipitationChance: chance < 0 ? nil : chance,
                            visibility: visibility < 0 ? nil : visibility
                        )
                        let found = SkyEventDetector.kinds(for: hour, sunElevation: elevation)
                        let mask = kindOrder.enumerated().reduce(0) { $0 + (found.contains($1.element) ? 1 << $1.offset : 0) }
                        kinds.append([Double(code), cover, precipitation, chance, visibility, elevation, Double(mask)])
                    }
                }
            }
        }
    }
}

// 4. Request URLs and sunward points.
var urls: [[String: Any]] = []
for place in [(45.63412, -122.52199), (51.5072, -0.1276), (-33.8688, 151.2093), (0.0, -179.9), (89.0, 0.0), (-45.005, 170.005)] {
    let url = try ForecastService.url(latitude: place.0, longitude: place.1, days: 8)
    let west = ForecastService.westPoint(latitude: place.0, longitude: place.1)
    let east = ForecastService.eastPoint(latitude: place.0, longitude: place.1)
    urls.append(["latitude": place.0, "longitude": place.1, "url": url.absoluteString,
                 "west": [west.latitude, west.longitude], "east": [east.latitude, east.longitude]])
}

// 5. A synthetic three-day, three-point Open-Meteo response, parsed.
var seed: UInt64 = 20_261_020
func next() -> Double {
    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(seed >> 33) / Double(1 << 31)
}
func series(_ count: Int, _ scale: Double, nulls: Bool = true) -> String {
    (0 ..< count).map { _ -> String in
        let v = next()
        if nulls && v < 0.04 { return "null" }
        return String(format: "%.1f", v * scale)
    }.joined(separator: ",")
}
func codes(_ count: Int) -> String {
    let pool = [0, 1, 2, 3, 45, 48, 51, 61, 80, 81, 82, 95, 96, 99]
    return (0 ..< count).map { _ in String(pool[Int(next() * Double(pool.count)) % pool.count]) }.joined(separator: ",")
}
/// Local hours as Open-Meteo returns them: a spring-forward day has no 01:00 (London) row.
func point(_ zone: String, _ days: [String], rises: [String], sets: [String], skip: String? = nil) -> String {
    let times = days.flatMap { day in (0 ..< 24).map { "\(day)T\(String(format: "%02d", $0)):00" } }
        .filter { (time: String) -> Bool in time != (skip ?? "") }
        .map { "\"\($0)\"" }
    let n = times.count
    return """
    {"timezone":"\(zone)","hourly":{"time":[\(times.joined(separator: ","))],
    "cloud_cover_low":[\(series(n, 100))],"cloud_cover_mid":[\(series(n, 100))],"cloud_cover_high":[\(series(n, 100))],
    "relative_humidity_2m":[\(series(n, 100))],"visibility":[\(series(n, 40_000))],"precipitation_probability":[\(series(n, 100))],
    "precipitation":[\(series(n, 2))],"cloud_cover":[\(series(n, 100))],"weather_code":[\(codes(n))]},
    "daily":{"sunrise":[\(rises.map { "\"\($0)\"" }.joined(separator: ","))],"sunset":[\(sets.map { "\"\($0)\"" }.joined(separator: ","))]}}
    """
}
let days = ["2026-10-08", "2026-10-09", "2026-10-10"]
let laJSON = "[" + (0 ..< 3).map { _ in
    point("America/Los_Angeles", days,
          rises: ["2026-10-08T07:18", "2026-10-09T07:19", "2026-10-10T07:21"],
          sets: ["2026-10-08T18:30", "2026-10-09T18:28", "2026-10-10T18:26"])
}.joined(separator: ",") + "]"
let londonJSON = "[" + (0 ..< 3).map { _ in
    point("Europe/London", ["2026-03-28", "2026-03-29", "2026-03-30"],
          rises: ["2026-03-28T05:50", "2026-03-29T06:47", "2026-03-30T06:45"],
          sets: ["2026-03-28T18:32", "2026-03-29T19:34", "2026-03-30T19:36"], skip: "2026-03-29T01:00")
}.joined(separator: ",") + "]"
let parseNow = date(2026, 10, 8, 9)

func showJSON(_ show: SunShow) -> [String: Any] {
    let c = show.conditions
    return ["event": show.event.rawValue, "time": epoch(show.time),
            "conditions": [c.cloudLow, c.cloudMid, c.cloudHigh, c.cloudLowTowardSun, c.humidity, c.visibility, c.precipitationChance],
            "score": [show.score.total, show.score.color, show.score.streaks, show.score.horizon, show.score.clarity, show.score.rainChance],
            "summary": show.score.summary]
}
func forecastJSON(_ forecast: SunsetForecast) -> [String: Any] {
    ["timeZoneID": forecast.timeZoneID,
     "days": forecast.days.map { ["sunrise": showJSON($0.sunrise), "sunset": showJSON($0.sunset)] },
     "skyEvents": forecast.skyEvents.map { ["kind": $0.kind.rawValue, "start": epoch($0.start), "end": epoch($0.end)] }]
}
let laForecast = try ForecastService.parse(Data(laJSON.utf8), latitude: 45.63, longitude: -122.52, now: parseNow)
let londonForecast = try ForecastService.parse(Data(londonJSON.utf8), latitude: 51.5, longitude: -0.13, now: parseNow)

// 6. Alert plans for the parsed week under several settings.
var plans: [[String: Any]] = []
let watchedSets: [[SunEvent]] = [[.sunrise, .sunset], [.sunset], [.sunrise]]
for (forecastName, forecast) in [("la", laForecast), ("london", londonForecast)] {
    for watched in watchedSets {
        for threshold in [0, 50, 70] {
            for lead in [30, 45, 120] {
                for skyKinds in [[], SkyEvent.Kind.allCases] {
                    for now in [forecast.days[0].sunrise.time.addingTimeInterval(-6 * 3600), forecast.days[0].sunset.time.addingTimeInterval(-50 * 60)] {
                        let planned = NotificationService.plan(forecast: forecast, watched: Set(watched), threshold: threshold,
                                                               leadMinutes: lead, skyEventKinds: Set(skyKinds), now: now)
                        plans.append(["forecast": forecastName, "watched": watched.map(\.rawValue), "threshold": threshold,
                                      "lead": lead, "skyKinds": skyKinds.map(\.rawValue), "now": epoch(now),
                                      "planned": planned.map { ["id": $0.identifier, "fire": epoch($0.fireDate), "title": $0.title, "body": $0.body] }])
                    }
                }
            }
        }
    }
}

// 7. Copy helpers relative to a fixed now.
let formatNow = date(2026, 10, 8, 9)
var format: [[String: Any]] = []
for hours in [-2.0, 3, 9, 11, 14, 20, 22.5, 26, 33, 38, 50, 75, 100] {
    let instant = formatNow.addingTimeInterval(hours * 3600)
    for event in SunEvent.allCases {
        let show = SunShow(event: event, time: instant, conditions: .clear, score: SunsetScorer.score(.clear, event: event))
        format.append(["time": epoch(instant), "event": event.rawValue,
                       "headline": SunsetFormat.headline(show, zone: la, now: formatNow),
                       "relativeDay": SunsetFormat.relativeDay(instant, zone: la, now: formatNow),
                       "dayLabel": SunsetFormat.dayLabel(instant, zone: la, now: formatNow),
                       "clock": SunsetFormat.time(instant, zone: la)])
    }
}
let minutes = [30, 45, 60, 90, 120, 180].map { ["value": $0, "label": SunsetFormat.minutes($0)] as [String: Any] }
let nouns: [[String: Any]] = watchedSets.flatMap { watched in
    [false, true].map { plural in
        ["watched": watched.map(\.rawValue), "plural": plural, "noun": SunsetFormat.watchedNoun(Set(watched), plural: plural)] as [String: Any]
    }
}

// 8. The demo week, as the screenshots show it.
let demo = DemoForecast.make(now: date(2026, 10, 8, 9), zone: la)

let output: [String: Any] = [
    "summaries": summaries,
    "scores": scores,
    "solar": solar,
    "kinds": kinds,
    "urls": urls,
    "parse": [["json": laJSON, "latitude": 45.63, "longitude": -122.52, "now": epoch(parseNow), "forecast": forecastJSON(laForecast)],
              ["json": londonJSON, "latitude": 51.5, "longitude": -0.13, "now": epoch(parseNow), "forecast": forecastJSON(londonForecast)]],
    "plans": plans,
    "format": format,
    "minutes": minutes,
    "nouns": nouns,
    "demo": ["now": epoch(date(2026, 10, 8, 9)), "forecast": forecastJSON(demo)],
]
let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
