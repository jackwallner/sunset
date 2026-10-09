import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var location: LocationService

    private let preview = SunsetDay(
        sunrise: .now,
        sunset: Calendar.current.date(bySettingHour: 18, minute: 31, second: 0, of: .now) ?? .now,
        conditions: .clear,
        score: SunsetScorer.score(SkyConditions(
            cloudLow: 5, cloudMid: 25, cloudHigh: 50, cloudLowWest: 8,
            humidity: 45, visibility: 30_000, precipitationChance: 5
        ))
    )

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            SkyCard(day: preview, zone: .current, title: "Tonight", placeName: nil, height: 240)
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text("Know before you go")
                    .font(.largeTitle.bold())
                Text("Every evening gets a score from the cloud, humidity and visibility forecast at sunset. Catch the great ones instead of hearing about them tomorrow.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 8)
            Spacer()
            VStack(spacing: 12) {
                Button("Use my location") {
                    location.request { fix in
                        ForecastStore.shared.refresh(location: fix)
                    }
                    settings.hasOnboarded = true
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("One approximate fix, used only to fetch the forecast for your horizon.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(22)
        .background(Theme.background)
    }
}
