import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var forecastStore: ForecastStore
    @State private var showPaywall = false
    @State private var showAlertSetup = false

    var body: some View {
        List {
            Section {
                if store.isPro {
                    Label("Sun+ is on", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.mint)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sun+").font(.headline)
                                Text("The full week, storm, rainbow and fog alerts")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            PlusCapsule()
                        }
                    }
                    .foregroundStyle(Theme.textPrimary)
                }
            }

            Section {
                ForEach(SunEvent.allCases, id: \.self) { event in
                    Toggle(isOn: Binding(
                        get: { settings.watched.contains(event) },
                        set: { _ in settings.toggle(event) }
                    )) {
                        Label(event.title, systemImage: event.symbol)
                    }
                    .disabled(settings.watched == [event])
                }
            } header: {
                Text("Watch")
            } footer: {
                Text("Today, the outlook, the widget and alerts follow what you watch.")
            }

            Section("Alerts") {
                Button {
                    showAlertSetup = true
                } label: {
                    HStack {
                        Text("Alerts")
                        Spacer()
                        Text(alertsStatus)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .foregroundStyle(Theme.textPrimary)
            }

            Section("Location") {
                HStack {
                    Text("Forecast for")
                    Spacer()
                    Text(location.location?.placeName ?? "Not set")
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Update location") {
                    location.request { fix in ForecastStore.shared.refresh(location: fix, force: true) }
                }
            }

            Section("About") {
                Link("Rate Sunset", destination: SunsetLinks.writeReviewURL)
                Link("Support", destination: SunsetLinks.support)
                Link("Privacy Policy", destination: SunsetLinks.privacyPolicy)
                Link("Terms of Use", destination: SunsetLinks.terms)
                Button("Restore purchases") { Task { await store.restore() } }
                Link("Weather data by Open-Meteo", destination: SunsetLinks.openMeteo)
            }

            #if DEBUG
            Section("Developer") {
                Toggle("Sun+ override", isOn: Binding(
                    get: { store.isPro },
                    set: { store.setLocalOverride(isPro: $0) }
                ))
            }
            #endif

            Section {
                Text("Scores are a forecast of cloud, humidity and visibility at sunrise and sunset, not a promise. Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) { PaywallView(source: "settings") }
        .sheet(isPresented: $showAlertSetup) { AlertSetupSheet() }
        .alert("Purchases", isPresented: Binding(
            get: { store.errorMessage != nil && !showPaywall },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var alertsStatus: String {
        guard settings.alertsEnabled else { return "Off" }
        return "\(settings.effectiveThreshold(isPro: store.isPro))+ · \(SunsetFormat.minutes(settings.effectiveLead(isPro: store.isPro))) before"
    }
}
