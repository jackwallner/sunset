import StoreKit
import SwiftUI

struct TonightView: View {
    @EnvironmentObject private var forecastStore: ForecastStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var store: StoreService
    @Environment(\.requestReview) private var requestReview
    @State private var showPaywall = false
    @State private var showAlertSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let forecast = forecastStore.forecast, let day = forecast.upcoming() {
                    content(forecast: forecast, day: day)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Sunset")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if let fix = location.location {
                await forecastStore.load(location: fix)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(source: "tonight_alerts") }
        .sheet(isPresented: $showAlertSetup) { AlertSetupSheet() }
        .onAppear {
            if let score = forecastStore.tonight?.score.total, settings.shouldRequestReview(score: score) {
                requestReview()
            }
        }
    }

    @ViewBuilder
    private func content(forecast: SunsetForecast, day: SunsetDay) -> some View {
        SkyCard(
            day: day,
            zone: forecast.timeZone,
            title: SunsetFormat.dayLabel(day.sunset, zone: forecast.timeZone),
            placeName: forecast.placeName
        )

        Card {
            Text(day.score.summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                stat("Best light", "\(SunsetFormat.time(day.bestWindowStart, zone: forecast.timeZone))–\(SunsetFormat.time(day.bestWindowEnd, zone: forecast.timeZone))")
                Spacer()
                stat("Rain chance", "\(day.score.rainChance)%")
            }
        }

        Card {
            Text("What makes tonight")
                .font(.headline)
            ForEach(day.score.factors) { factor in
                FactorRow(factor: factor, tone: Theme.tone(score: day.score.total))
            }
        }

        alertsCard

        if let message = forecastStore.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }

        Text("Forecast by Open-Meteo, updated \(SunsetFormat.time(forecast.fetched)).")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
    }

    private var alertsCard: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sunset alerts")
                        .font(.headline)
                    Text(alertsSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !store.isPro { PlusCapsule() }
            }
            Button(store.isPro ? (settings.alertsEnabled ? "Change alert" : "Turn on alerts") : "Get alerted") {
                if store.isPro { showAlertSetup = true } else { showPaywall = true }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var alertsSubtitle: String {
        if store.isPro && settings.alertsEnabled {
            return "You'll hear \(SunsetFormat.minutes(settings.leadMinutes)) before any sunset scoring \(settings.threshold) or higher."
        }
        return "A notification before sunset on the evenings worth going out for."
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            if forecastStore.isLoading {
                ProgressView("Reading the sky")
            } else if location.isDenied {
                Text("Location is off")
                    .font(.title3.weight(.semibold))
                Text("Sunset needs your approximate location to fetch the cloud forecast for your horizon. Turn it on in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if let message = forecastStore.errorMessage {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                Button("Try again") {
                    if let fix = location.location { forecastStore.refresh(location: fix, force: true) }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Text("Finding your sky")
                    .font(.title3.weight(.semibold))
                Text("Allow location once and tonight's score appears here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                Button("Use my location") {
                    location.request { fix in ForecastStore.shared.refresh(location: fix) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, 80)
        .padding(.horizontal, 12)
    }
}

/// Threshold and lead time, shown after Sunset+ is on. Also asks for the
/// notification permission, which is the first time the app needs it.
struct AlertSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var forecastStore: ForecastStore
    @State private var denied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sunset alerts", isOn: $settings.alertsEnabled)
                } footer: {
                    Text("Alerts are rebuilt from the latest forecast each time the app refreshes, so a day that clouds over loses its alert.")
                }
                Section("Alert me when the score is at least") {
                    Picker("Score", selection: $settings.threshold) {
                        ForEach(AlertSettings.thresholds, id: \.self) { value in
                            Text("\(value) · \(SunsetScore.Grade(total: value).rawValue)").tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("How far before sunset") {
                    Picker("Lead time", selection: $settings.leadMinutes) {
                        ForEach(AlertSettings.leadOptions, id: \.self) { value in
                            Text(SunsetFormat.minutes(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if denied {
                    Section {
                        Text("Notifications are turned off for Sunset. Enable them in Settings to receive alerts.")
                            .foregroundStyle(Theme.textSecondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: settings.alertsEnabled) { _, enabled in
                guard enabled else { return }
                Task {
                    let granted = await NotificationService.requestAuthorization()
                    denied = !granted
                    await forecastStore.rescheduleAlerts()
                }
            }
            .onChange(of: settings.threshold) { _, _ in Task { await forecastStore.rescheduleAlerts() } }
            .onChange(of: settings.leadMinutes) { _, _ in Task { await forecastStore.rescheduleAlerts() } }
            .task {
                if settings.alertsEnabled {
                    denied = await NotificationService.authorizationStatus() == .denied
                }
            }
        }
    }
}
