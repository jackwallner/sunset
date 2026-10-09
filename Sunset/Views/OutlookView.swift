import SwiftUI

/// The week ahead. Tonight and tomorrow are free; the rest is Sunset+.
struct OutlookView: View {
    @EnvironmentObject private var forecastStore: ForecastStore
    @EnvironmentObject private var store: StoreService
    @State private var showPaywall = false

    private let freeDays = 2

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let forecast = forecastStore.forecast {
                    let days = upcomingDays(forecast)
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        if store.isPro || index < freeDays {
                            NavigationLink {
                                DayDetailView(day: day, zone: forecast.timeZone, placeName: forecast.placeName)
                            } label: {
                                OutlookRow(day: day, zone: forecast.timeZone)
                            }
                            .buttonStyle(.plain)
                        } else {
                            LockedRow(day: day, zone: forecast.timeZone)
                                .onTapGesture { showPaywall = true }
                        }
                    }
                    if !store.isPro, days.count > freeDays {
                        Button("See the whole week") { showPaywall = true }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 6)
                    }
                } else {
                    Text("The outlook appears once tonight's forecast has loaded.")
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

    private func upcomingDays(_ forecast: SunsetForecast) -> [SunsetDay] {
        guard let first = forecast.upcoming(), let index = forecast.days.firstIndex(of: first) else { return [] }
        return Array(forecast.days[index...].prefix(7))
    }
}

private struct OutlookRow: View {
    let day: SunsetDay
    let zone: TimeZone

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.skyGradient(score: day.score.total))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(SunsetFormat.dayLabel(day.sunset, zone: zone))
                    .font(.headline)
                Text("Sunset \(SunsetFormat.time(day.sunset, zone: zone)) · \(day.score.grade.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ScoreChip(score: day.score)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct LockedRow: View {
    let day: SunsetDay
    let zone: TimeZone

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.hairline)
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "lock.fill").foregroundStyle(Theme.textSecondary))
            VStack(alignment: .leading, spacing: 3) {
                Text(SunsetFormat.dayLabel(day.sunset, zone: zone))
                    .font(.headline)
                Text("Sunset \(SunsetFormat.time(day.sunset, zone: zone))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            PlusCapsule()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Unlock with Sunset+")
    }
}

struct DayDetailView: View {
    let day: SunsetDay
    let zone: TimeZone
    let placeName: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SkyCard(day: day, zone: zone, title: SunsetFormat.dayLabel(day.sunset, zone: zone), placeName: placeName)
                Card {
                    Text(day.score.summary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack {
                        detail("Sunrise", SunsetFormat.time(day.sunrise, zone: zone))
                        Spacer()
                        detail("Sunset", SunsetFormat.time(day.sunset, zone: zone))
                        Spacer()
                        detail("Rain", "\(day.score.rainChance)%")
                    }
                }
                Card {
                    ForEach(day.score.factors) { factor in
                        FactorRow(factor: factor, tone: Theme.tone(score: day.score.total))
                    }
                }
                Card {
                    Text("Cloud cover at sunset").font(.headline)
                    cloudRow("High", day.conditions.cloudHigh)
                    cloudRow("Mid", day.conditions.cloudMid)
                    cloudRow("Low", day.conditions.cloudLow)
                    cloudRow("Low, toward the sun", day.conditions.cloudLowWest)
                    Text("Humidity \(Int(day.conditions.humidity))% · Visibility \(visibilityLabel)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(SunsetFormat.monthDay(day.sunset, zone: zone))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var visibilityLabel: String {
        let km = day.conditions.visibility / 1000
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
