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
                    Label("Sunset+ is on", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.mint)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sunset+").font(.headline)
                                Text("Alerts and the full week ahead")
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

            Section("Alerts") {
                Button {
                    if store.isPro { showAlertSetup = true } else { showPaywall = true }
                } label: {
                    HStack {
                        Text("Sunset alerts")
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
                Toggle("Sunset+ override", isOn: Binding(
                    get: { store.isPro },
                    set: { store.setLocalOverride(isPro: $0) }
                ))
            }
            #endif

            Section {
                Text("Scores are a forecast of cloud, humidity and visibility at sunset, not a promise. Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
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
        guard store.isPro else { return "Sunset+" }
        return settings.alertsEnabled ? "\(settings.threshold)+ · \(SunsetFormat.minutes(settings.leadMinutes)) before" : "Off"
    }
}
