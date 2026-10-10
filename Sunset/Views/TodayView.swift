import StoreKit
import SwiftUI

struct TodayView: View {
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
                if let forecast = forecastStore.forecast,
                   let hero = forecast.upcomingShows(settings.watched).first {
                    content(forecast: forecast, hero: hero)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            if let fix = location.location {
                await forecastStore.load(location: fix)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(source: "today_sky_events") }
        .sheet(isPresented: $showAlertSetup) { AlertSetupSheet() }
        .onAppear {
            if let score = forecastStore.nextShow?.score.total, settings.shouldRequestReview(score: score) {
                requestReview()
            }
        }
    }

    @ViewBuilder
    private func content(forecast: SunsetForecast, hero: SunShow) -> some View {
        let zone = forecast.timeZone
        SkyCard(
            show: hero,
            zone: zone,
            title: SunsetFormat.headline(hero, zone: zone),
            placeName: forecast.placeName
        )

        Card {
            Text(hero.score.summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                stat("Best light", "\(SunsetFormat.time(hero.bestWindowStart, zone: zone))–\(SunsetFormat.time(hero.bestWindowEnd, zone: zone))")
                Spacer()
                stat("Rain chance", "\(hero.score.rainChance)%")
            }
        }

        Card {
            Text("What makes the score")
                .font(.headline)
            ForEach(hero.score.factors) { factor in
                FactorRow(factor: factor, tone: Theme.tone(score: hero.score.total))
            }
        }

        let next = Array(forecast.upcomingShows(settings.watched).dropFirst().prefix(2))
        if !next.isEmpty {
            Card {
                Text("Up next").font(.headline)
                ForEach(next) { show in
                    NavigationLink {
                        ShowDetailView(show: show, zone: zone, placeName: forecast.placeName)
                    } label: {
                        ShowRow(show: show, zone: zone, title: SunsetFormat.headline(show, zone: zone))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        skyEventsCard(forecast: forecast)
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

    private func skyEventsCard(forecast: SunsetForecast) -> some View {
        let events = forecast.upcomingSkyEvents(within: 48 * 3600)
        return Card {
            HStack {
                Text("Sky events").font(.headline)
                Spacer()
                if !store.isPro { PlusCapsule() }
            }
            if events.isEmpty {
                Text("No storms, rainbow chances or fog in the next two days.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(events) { event in
                    SkyEventRow(event: event, zone: forecast.timeZone)
                }
            }
            if !store.isPro {
                Button("Get alerted before them") { showPaywall = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ember)
            }
        }
    }

    private var alertsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Alerts")
                    .font(.headline)
                Text(alertsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Button(settings.alertsEnabled ? "Change alerts" : "Turn on alerts") {
                showAlertSetup = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var alertsSubtitle: String {
        let threshold = settings.effectiveThreshold(isPro: store.isPro)
        if settings.alertsEnabled {
            return "You'll hear before any \(SunsetFormat.watchedNoun(settings.watched)) scoring \(threshold) or higher."
        }
        return "A heads-up before the \(SunsetFormat.watchedNoun(settings.watched, plural: true)) worth going out for. Free."
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
            if forecastStore.isLoading || location.status == .waiting {
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
                Text("Allow location once and today's scores appear here.")
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

/// Alert settings. Sunrise and sunset alerts are free at the default
/// threshold; Sun+ unlocks the threshold, the lead time and sky events. Also
/// asks for the notification permission the first time alerts go on.
struct AlertSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var forecastStore: ForecastStore
    @EnvironmentObject private var store: StoreService
    @State private var denied = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Alerts", isOn: $settings.alertsEnabled)
                } footer: {
                    Text("Alerts are rebuilt from the latest forecast each time the app refreshes, so a sky that clouds over loses its alert. Sunrise alerts arrive the evening before.")
                }

                Section {
                    if store.isPro {
                        Picker("Score", selection: $settings.threshold) {
                            ForEach(AlertSettings.thresholds, id: \.self) { value in
                                Text("\(value) · \(SunsetScore.Grade(total: value).rawValue)").tag(value)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } else {
                        lockedRow("Score", value: "\(AlertSettings.defaultThreshold) · Great")
                    }
                } header: {
                    Text("Alert me when the score is at least")
                }

                Section("How far before sunset") {
                    if store.isPro {
                        Picker("Lead time", selection: $settings.leadMinutes) {
                            ForEach(AlertSettings.leadOptions, id: \.self) { value in
                                Text(SunsetFormat.minutes(value)).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        lockedRow("Lead time", value: SunsetFormat.minutes(AlertSettings.defaultLead))
                    }
                }

                Section {
                    ForEach(SkyEvent.Kind.allCases, id: \.self) { kind in
                        if store.isPro {
                            Toggle(isOn: skyEventBinding(kind)) {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                        } else {
                            Button { showPaywall = true } label: {
                                HStack {
                                    Label(kind.title, systemImage: kind.symbol)
                                    Spacer()
                                    PlusCapsule()
                                }
                            }
                            .foregroundStyle(Theme.textPrimary)
                        }
                    }
                } header: {
                    Text("Sky events")
                } footer: {
                    Text("An hour's warning before storms, rainbow chances and fog, moved to the evening before when they fall overnight.")
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
            .sheet(isPresented: $showPaywall) { PaywallView(source: "alert_settings") }
            .onChange(of: settings.alertsEnabled) { _, enabled in
                guard enabled else { Task { await forecastStore.rescheduleAlerts() }; return }
                Task {
                    let granted = await NotificationService.requestAuthorization()
                    denied = !granted
                    await forecastStore.rescheduleAlerts()
                }
            }
            .onChange(of: settings.threshold) { _, _ in Task { await forecastStore.rescheduleAlerts() } }
            .onChange(of: settings.leadMinutes) { _, _ in Task { await forecastStore.rescheduleAlerts() } }
            .onChange(of: settings.skyEventKinds) { _, _ in Task { await forecastStore.rescheduleAlerts() } }
            .task {
                if settings.alertsEnabled {
                    denied = await NotificationService.authorizationStatus() == .denied
                }
            }
        }
    }

    private func skyEventBinding(_ kind: SkyEvent.Kind) -> Binding<Bool> {
        Binding(
            get: { settings.skyEventKinds.contains(kind) },
            set: { on in
                if on { settings.skyEventKinds.insert(kind) } else { settings.skyEventKinds.remove(kind) }
                if on && !settings.alertsEnabled { settings.alertsEnabled = true }
            }
        )
    }

    private func lockedRow(_ label: String, value: String) -> some View {
        Button { showPaywall = true } label: {
            HStack {
                Text(label)
                Spacer()
                Text(value).foregroundStyle(Theme.textSecondary)
                PlusCapsule()
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }
}
