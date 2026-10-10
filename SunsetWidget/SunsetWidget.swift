import SwiftUI
import WidgetKit

/// The next watched sunrise or sunset on the Home Screen. Reads the App Group cache the app
/// writes; when that is stale and a location is cached it fetches on its own,
/// so the widget stays right even if the app has not been opened for days.
struct SunsetEntry: TimelineEntry {
    let date: Date
    let show: SunShow?
    let zone: TimeZone
    let placeName: String?
}

struct SunsetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunsetEntry {
        SunsetEntry(date: .now, show: Self.sample, zone: .current, placeName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SunsetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(Self.entry(from: ForecastCache.forecast))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunsetEntry>) -> Void) {
        let finish = SendableBox(completion)
        Task {
            var forecast = ForecastCache.forecast
            if forecast?.isStale() ?? true, let location = ForecastCache.location,
               var fresh = try? await ForecastService.fetch(latitude: location.latitude, longitude: location.longitude) {
                fresh.placeName = location.placeName
                ForecastCache.forecast = fresh
                forecast = fresh
            }
            let entry = Self.entry(from: forecast)
            // Roll to the next show half an hour after this one, or retry in 3h.
            let next = entry.show.map { $0.time.addingTimeInterval(31 * 60) }
                .map { max($0, Date(timeIntervalSinceNow: 15 * 60)) }
                ?? Date(timeIntervalSinceNow: 3 * 3600)
            finish.value(Timeline(entries: [entry], policy: .after(min(next, Date(timeIntervalSinceNow: 3 * 3600)))))
        }
    }

    static func entry(from forecast: SunsetForecast?) -> SunsetEntry {
        SunsetEntry(
            date: .now,
            show: forecast?.upcomingShows(ForecastCache.watchedEvents).first,
            zone: forecast?.timeZone ?? .current,
            placeName: forecast?.placeName
        )
    }

    static let sample = SunShow(
        event: .sunset,
        time: Calendar.current.date(bySettingHour: 18, minute: 31, second: 0, of: .now) ?? .now,
        conditions: .clear,
        score: SunsetScorer.score(SkyConditions(
            cloudLow: 5, cloudMid: 25, cloudHigh: 50, cloudLowTowardSun: 8,
            humidity: 45, visibility: 30_000, precipitationChance: 5
        ))
    )
}

/// WidgetKit's completion closures are not Sendable; nothing here touches
/// shared state after handing them to the task.
private struct SendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

struct SunsetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunsetEntry

    var body: some View {
        if let show = entry.show {
            content(show)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: Theme.sky(score: show.score.total, event: show.event), startPoint: .top, endPoint: .bottom)
                }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "sun.horizon.fill").font(.title2)
                Text("Open Sunset to load today's score")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .containerBackground(for: .widget) {
                LinearGradient(colors: Theme.sky(score: 55), startPoint: .top, endPoint: .bottom)
            }
        }
    }

    @ViewBuilder
    private func content(_ show: SunShow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SunsetFormat.headline(show, zone: entry.zone, now: entry.date))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(show.score.total)")
                    .font(.system(size: family == .systemSmall ? 44 : 52, weight: .bold, design: .rounded))
                Text(show.score.grade.rawValue)
                    .font(.headline)
                    .padding(.bottom, 6)
            }
            .foregroundStyle(.white)
            Text("\(show.event.title) \(SunsetFormat.time(show.time, zone: entry.zone))")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
            if family != .systemSmall {
                Text(show.score.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@main
struct SunsetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SunsetTonight", provider: SunsetProvider()) { entry in
            SunsetWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Sunrise or Sunset")
        .description("The score and time for the next sunrise or sunset you watch.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
