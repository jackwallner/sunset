import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var forecastStore: ForecastStore
    @State private var showPaywall = false
    @State private var showAlertSetup = false
    @State private var restoreMessage: String?

    var body: some View {
        List {
            Section {
                if store.isPro {
                    Label {
                        Text("Sun+ is on")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.gold)
                    }
                    .paneListRow("plus")
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
                    .paneListRow("plus")
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
                    .paneListRow("watch")
                }
            } header: {
                Text("Watch").paneListPart("watch")
            } footer: {
                Text("Today, the outlook, the widget and alerts follow what you watch.")
                    .paneListPart("watch")
            }

            Section {
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
                .paneListRow("alerts")
            } header: {
                Text("Alerts").paneListPart("alerts")
            }

            Section {
                HStack {
                    Text("Forecast for")
                    Spacer()
                    Text(location.location?.placeName ?? "Not set")
                        .foregroundStyle(Theme.textSecondary)
                }
                .paneListRow("location")
                Button("Update location") {
                    location.request { fix in ForecastStore.shared.refresh(location: fix, force: true) }
                }
                .paneListRow("location")
            } header: {
                Text("Location").paneListPart("location")
            }

            Section {
                Link("Rate Sunset", destination: SunsetLinks.writeReviewURL)
                    .paneListRow("about")
                Link("Support", destination: SunsetLinks.support)
                    .paneListRow("about")
                Link("Privacy Policy", destination: SunsetLinks.privacyPolicy)
                    .paneListRow("about")
                Link("Terms of Use", destination: SunsetLinks.terms)
                    .paneListRow("about")
                Button("Restore purchases") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Sun+ is restored." : (store.errorMessage ?? "No active Sun+ purchase was found for this Apple ID.")
                        store.clearError()
                    }
                }
                .paneListRow("about")
                Link("Weather data by Open-Meteo", destination: SunsetLinks.openMeteo)
                    .paneListRow("about")
            } header: {
                Text("About").paneListPart("about")
            }

            #if DEBUG
            Section {
                Toggle("Sun+ override", isOn: Binding(
                    get: { store.isPro },
                    set: { store.setLocalOverride(isPro: $0) }
                ))
                .paneListRow("developer")
            } header: {
                Text("Developer").paneListPart("developer")
            }
            #endif

            Section {
                Text("Scores are a forecast of cloud, humidity and visibility at sunrise and sunset, not a promise. Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .paneListRow("version")
            }
        }
        .scrollContentBackground(.hidden)
        .clearsPaneBottom()
        .background {
            SkyBackdrop(score: forecastStore.nextShow?.score.total ?? 70, event: forecastStore.nextShow?.event ?? .sunset, horizon: 0.14)
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) { PaywallView(source: "settings") }
        .sheet(isPresented: $showAlertSetup) { AlertSetupSheet() }
        // Only a restore the user asked for answers with an alert; background
        // purchase checks that fail offline stay quiet.
        .alert("Restore purchases", isPresented: Binding(
            get: { restoreMessage != nil },
            set: { if !$0 { restoreMessage = nil } }
        )) {
            Button("OK") { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .keepsPaneEdgeInsets()
    }

    private var alertsStatus: String {
        guard settings.alertsEnabled else { return "Off" }
        return "\(settings.effectiveThreshold(isPro: store.isPro))+ · \(SunsetFormat.minutes(settings.effectiveLead(isPro: store.isPro))) before"
    }
}
