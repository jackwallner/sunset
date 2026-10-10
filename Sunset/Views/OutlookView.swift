import SwiftUI

/// The week ahead. Today and tomorrow are free; the rest is Sun+, shown
/// blurred so the free tier can see what it is missing.
struct OutlookView: View {
    @EnvironmentObject private var forecastStore: ForecastStore
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var store: StoreService
    @State private var showPaywall = false

    static let freeDays = 2

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let forecast = forecastStore.forecast {
                    let days = Array(forecast.upcomingDays().prefix(7))
                    ForEach(days.prefix(store.isPro ? days.count : Self.freeDays)) { day in
                        DayCard(day: day, forecast: forecast, watched: settings.watched)
                    }
                    if !store.isPro, days.count > Self.freeDays {
                        lockedWeek(Array(days.dropFirst(Self.freeDays)), forecast: forecast)
                    }
                } else {
                    Text("The outlook appears once the forecast has loaded.")
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Outlook")
        .sheet(isPresented: $showPaywall) { PaywallView(source: "outlook") }
    }

    /// The real days, blurred past reading, under one unlock card.
    private func lockedWeek(_ days: [SunsetDay], forecast: SunsetForecast) -> some View {
        VStack(spacing: 12) {
            // Three days are enough to show what is behind the lock without a
            // long scroll of blur under the card.
            ForEach(days.prefix(3)) { day in
                DayCard(day: day, forecast: forecast, watched: settings.watched, isLinked: false)
            }
        }
        .blur(radius: 9, opaque: false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .overlay(alignment: .top) {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.ember)
                Text("The rest of the week")
                    .font(.title3.weight(.semibold))
                Text("Every sunrise and sunset score through \(lastDayName(days, forecast: forecast)), plus storm, rainbow and fog alerts.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                Button("Unlock with Sun+") { showPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .padding(.top, 40)
            .padding(.horizontal, 8)
        }
    }

    private func lastDayName(_ days: [SunsetDay], forecast: SunsetForecast) -> String {
        guard let last = days.last else { return "the week" }
        return SunsetFormat.weekday(last.sunset.time, zone: forecast.timeZone)
    }
}

private struct DayCard: View {
    let day: SunsetDay
    let forecast: SunsetForecast
    let watched: Set<SunEvent>
    var isLinked = true

    var body: some View {
        let zone = forecast.timeZone
        let shows = SunEvent.allCases.filter(watched.contains).map(day.show)
        let events = forecast.skyEvents(on: day)
        Card {
            HStack {
                Text(SunsetFormat.dayLabel(day.sunset.time, zone: zone))
                    .font(.headline)
                Spacer()
                Text(SunsetFormat.monthDay(day.sunset.time, zone: zone))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(shows) { show in
                if isLinked {
                    NavigationLink {
                        ShowDetailView(show: show, zone: zone, placeName: forecast.placeName)
                    } label: {
                        ShowRow(show: show, zone: zone)
                    }
                    .buttonStyle(.plain)
                } else {
                    ShowRow(show: show, zone: zone, showsChevron: false)
                }
            }
            if !events.isEmpty {
                HStack(spacing: 14) {
                    ForEach(events) { event in
                        Label("\(event.kind.title) \(SunsetFormat.time(event.start, zone: zone))", systemImage: event.kind.symbol)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }
}

struct ShowDetailView: View {
    let show: SunShow
    let zone: TimeZone
    let placeName: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SkyCard(show: show, zone: zone, title: SunsetFormat.headline(show, zone: zone), placeName: placeName)
                Card {
                    Text(show.score.summary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack {
                        detail("Best light", "\(SunsetFormat.time(show.bestWindowStart, zone: zone))–\(SunsetFormat.time(show.bestWindowEnd, zone: zone))")
                        Spacer()
                        detail("Rain", "\(show.score.rainChance)%")
                    }
                }
                Card {
                    ForEach(show.score.factors) { factor in
                        FactorRow(factor: factor, tone: Theme.tone(score: show.score.total))
                    }
                }
                Card {
                    Text("Cloud cover at \(show.event.title.lowercased())").font(.headline)
                    cloudRow("High", show.conditions.cloudHigh)
                    cloudRow("Mid", show.conditions.cloudMid)
                    cloudRow("Low", show.conditions.cloudLow)
                    cloudRow("Low, \(show.event.direction) toward the sun", show.conditions.cloudLowTowardSun)
                    Text("Humidity \(Int(show.conditions.humidity))% · Visibility \(visibilityLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(SunsetFormat.monthDay(show.time, zone: zone))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var visibilityLabel: String {
        let km = show.conditions.visibility / 1000
        return km >= 10 ? "\(Int(km)) km" : String(format: "%.1f km", km)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private func cloudRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text("\(Int(value))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
