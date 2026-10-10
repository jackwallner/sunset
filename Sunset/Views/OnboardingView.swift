import RevenueCat
import SwiftUI

/// Four short pages on a forecast sky: what the app does, which shows to
/// watch, free alerts, then the Sun+ offer with "Get Started" as the free way
/// in. The offer buys the monthly plan, like the fleet's best converters
/// (StatScout, Mahj, Cribbage): someone who has not used the app yet reacts to
/// the recurring number, and the monthly one is the small one.
///
/// The bottom bar is laid out identically on every page: a fixed slot above
/// the button, the button, and a fixed slot below it. Each slot reserves its
/// height whether or not the page fills it, so the primary button sits at the
/// same y from the first tap to the trial and never jumps as pages change.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome
        case watch
        case alerts
        case plus
    }

    @EnvironmentObject private var settings: AlertSettings
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var forecastStore: ForecastStore

    @State private var step = Step(rawValue: LaunchArguments.onboardingStep ?? 0) ?? .welcome
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var ctaWaitExpired = false
    @State private var showPlans = false

    /// How long the trial button shows a spinner before it gives up on
    /// StoreKit and offers the full plan picker instead.
    private static let ctaWaitLimit = Duration.seconds(6)

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 12)
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            bottomBar
        }
        .background {
            SkyBackdrop(score: step == .plus ? 92 : Self.preview.score.total, horizon: step == .alerts ? 0.56 : 0.4)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPlans, onDismiss: { if store.isPro { finish() } }) {
            PaywallView(source: "onboarding_plans")
        }
        .onChange(of: store.isPro) { _, isPro in if isPro { finish() } }
        .task(id: step) {
            guard step == .plus else { return }
            store.trackPaywallImpression(id: "sunset_onboarding")
            try? await Task.sleep(for: Self.ctaWaitLimit)
            ctaWaitExpired = true
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome: welcomePage
        case .watch: watchPage
        case .alerts: alertsPage
        case .plus: plusPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 0) {
            SkyHero(show: Self.preview, zone: .current, title: "Example", placeName: nil)
                .containerRelativeFrame(.vertical) { length, _ in length * 0.42 }
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                Text("Know before you go")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Every sunrise and sunset gets a score from the cloud, humidity and visibility forecast. Catch the great ones instead of hearing about them later.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 28)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var watchPage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            pageHeader(
                "What do you want to catch?",
                "Pick one or both. You can change this in Settings."
            )
            VStack(spacing: 12) {
                ForEach(SunEvent.allCases, id: \.self) { event in
                    WatchChoice(event: event, isOn: settings.watched.contains(event)) {
                        settings.toggle(event)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var alertsPage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 54))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.gold, .white)
            pageHeader(
                "Get a heads-up, free",
                alertsPitch
            )
            AlertPreview(watched: settings.watched)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
    }

    private var plusPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Sun+")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("The whole week, and the rest of the sky")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(PlusBenefit.all) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .foregroundStyle(Theme.gold)
                                .frame(width: 24)
                            Text(item.text).font(.subheadline)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glass()
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func pageHeader(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.86))
        }
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }

    private var alertsPitch: String {
        let shows = SunsetFormat.watchedNoun(settings.watched, plural: true)
        return "A notification before the \(shows) scoring 70 or more, so you only step outside for the good ones."
    }

    // MARK: Bottom bar

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.hairline))
                    .frame(width: item == step ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            aboveButton
                .frame(height: 104, alignment: .bottom)
            primaryButton
            belowButton
                .frame(height: 22)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var aboveButton: some View {
        switch step {
        case .welcome:
            Label("One approximate location fix. No account.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        case .watch:
            Color.clear
        case .alerts:
            secondaryButton("Not now") { advance() }
        case .plus:
            // Fleet trial-page order: the free way in, then the billed amount
            // as the largest pricing element on the page (App Review
            // 3.1.2(c)), then one line of terms. Plain type, no box.
            VStack(spacing: 4) {
                secondaryButton("Get Started") { finish() }
                Text(package?.priceLabel ?? " ")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                Group {
                    if let purchaseError {
                        Text(purchaseError).foregroundStyle(Theme.gold)
                    } else {
                        Text(disclosure).foregroundStyle(Theme.textSecondary)
                    }
                }
                .font(.caption2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var belowButton: some View {
        if step == .plus {
            HStack(spacing: 8) {
                Button("Restore") {
                    Task {
                        await store.restore()
                        // Success flips isPro, which finishes onboarding.
                        if !store.isPro { purchaseError = store.errorMessage }
                        store.clearError()
                    }
                }
                Text("·")
                Link("Terms", destination: SunsetLinks.standardEULA)
                Text("·")
                Link("Privacy", destination: SunsetLinks.privacyPolicy)
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        } else {
            Color.clear
        }
    }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            ZStack {
                Text(primaryLabel).opacity(showsSpinner ? 0 : 1)
                if showsSpinner { ProgressView().tint(.white) }
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(showsSpinner)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
    }

    private var primaryLabel: String {
        switch step {
        case .welcome, .watch: "Continue"
        case .alerts: "Turn on alerts"
        case .plus:
            if package == nil { "See Sun+ plans" }
            else if let trialLabel { "Start \(trialLabel)" }
            else { ConversionCopy.ctaLabel }
        }
    }

    /// On the offer page the button waits for StoreKit to name the price and
    /// trial, then gives up after a few seconds so it is never a dead end.
    private var showsSpinner: Bool {
        guard step == .plus else { return false }
        return isPurchasing || (!ctaReady && !ctaWaitExpired)
    }

    // MARK: Store

    private var package: Package? { store.monthlyPackage ?? store.yearlyPackage }

    private var ctaReady: Bool {
        guard let package else { return false }
        return package.introOfferLabel == nil || store.introEligibilityResolved
    }

    private var trialLabel: String? { package.flatMap { store.eligibleIntroLabel(for: $0) } }

    private var disclosure: String {
        guard let package else { return "Prices are shown before you buy and vary by region." }
        return ConversionCopy.compactDisclosure(trialLabel: trialLabel, priceLabel: package.priceLabel)
    }

    // MARK: Actions

    private func primaryAction() {
        switch step {
        case .welcome:
            // The location prompt goes up on the way out of the welcome page,
            // so it lands over the next page instead of covering the pitch.
            location.request { fix in ForecastStore.shared.refresh(location: fix) }
            advance()
        case .watch:
            advance()
        case .alerts:
            Task {
                settings.alertsEnabled = await NotificationService.requestAuthorization()
                await forecastStore.rescheduleAlerts()
                advance()
            }
        case .plus:
            purchase()
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return finish() }
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func purchase() {
        guard let package else {
            showPlans = true
            return
        }
        purchaseError = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            switch await store.purchase(package) {
            case .purchased: finish()
            case .cancelled, .pending, nil: purchaseError = store.errorMessage
            }
            store.clearError()
        }
    }

    private func finish() {
        guard !settings.hasOnboarded else { return }
        withAnimation(.easeInOut(duration: 0.3)) { settings.hasOnboarded = true }
    }

    private static let preview = SunShow(
        event: .sunset,
        time: Calendar.current.date(bySettingHour: 18, minute: 31, second: 0, of: .now) ?? .now,
        conditions: .clear,
        score: SunsetScorer.score(SkyConditions(
            cloudLow: 5, cloudMid: 25, cloudHigh: 50, cloudLowTowardSun: 8,
            humidity: 45, visibility: 30_000, precipitationChance: 5
        ))
    )
}

private struct WatchChoice: View {
    let event: SunEvent
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.skyGradient(score: 80, event: event))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: event.symbol).font(.title3).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.headline)
                    Text(event == .sunrise ? "Scored against the eastern horizon" : "Scored against the western horizon")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Theme.gold : Theme.textSecondary)
            }
            .padding(16)
            .glass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(isOn ? Theme.gold : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A sample of the notification the alerts page is asking for.
private struct AlertPreview: View {
    let watched: Set<SunEvent>

    var body: some View {
        let event: SunEvent = watched.contains(.sunset) ? .sunset : .sunrise
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 9)
                .fill(Theme.skyGradient(score: 85, event: event))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: event.symbol).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("SUNSET").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(event == .sunset ? "45m before" : "8:00 PM")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(event == .sunset ? "Epic sunset tonight: 88" : "Great sunrise tomorrow: 78")
                    .font(.subheadline.weight(.semibold))
                Text("High and mid clouds over an open horizon, which is the recipe for a colorful sky.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .glass(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example alert")
    }
}
