import RevenueCat
import SwiftUI

struct PaywallView: View {
    let source: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreService
    @State private var selectedIdentifier: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.skyGradient(score: 92))
                        .frame(height: 110)
                        .overlay(alignment: .bottomLeading) {
                            Text("Sun+")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .padding(16)
                        }
                    Text("See further and catch more. Today, tomorrow and your sunrise and sunset alerts stay free.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textSecondary)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(PlusBenefit.all) { item in
                            benefit(item.symbol, item.text)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(store.packages, id: \.identifier) { package in
                        Button {
                            selectedIdentifier = package.identifier
                        } label: {
                            PlanCard(
                                title: package.displayName,
                                price: package.priceLabel,
                                detail: package.kind == .lifetime ? "One-time purchase" : store.eligibleIntroLabel(for: package),
                                isSelected: selectedIdentifier == package.identifier
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isLoading)
                    }

                    if store.packages.isEmpty {
                        if store.isLoadingProducts || store.errorMessage == nil {
                            ProgressView("Loading plans")
                        } else {
                            Text("Purchase options are unavailable right now.")
                                .font(.callout)
                                .foregroundStyle(Theme.textSecondary)
                            Button("Try again") { store.start(forceRefresh: true) }
                        }
                    }

                    if let error = store.errorMessage {
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.red)
                    }

                    if let package = selectedPackage {
                        VStack(spacing: 4) {
                            Text("BILLED AMOUNT")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Text(ConversionCopy.billedAmount(priceLabel: package.priceLabel))
                                .font(.title2.bold())
                            Text(package.kind == .lifetime
                                 ? "One-time purchase"
                                 : ConversionCopy.billedNote(trialLabel: store.eligibleIntroLabel(for: package)))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Button {
                        guard let package = selectedPackage else { return }
                        Task {
                            if await store.purchase(package) == .purchased { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isLoading { ProgressView().tint(.white) }
                            Text(store.isLoading ? "Processing..." : ConversionCopy.ctaLabel)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedPackage == nil || store.isLoading)

                    Text(disclosure)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textSecondary)

                    Button {
                        Task {
                            isRestoring = true
                            await store.restore()
                            isRestoring = false
                        }
                    } label: {
                        if isRestoring { ProgressView() } else { Text("Restore purchases") }
                    }
                    .disabled(store.isLoading)

                    HStack {
                        Link("Terms", destination: SunsetLinks.standardEULA)
                        Text("·")
                        Link("Privacy", destination: SunsetLinks.privacyPolicy)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                }
                .padding(22)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .onAppear {
            selectDefault()
            store.trackPaywallImpression(id: "sunset_paywall_\(source)")
        }
        .onChange(of: store.packages.map(\.identifier)) { _, _ in selectDefault() }
        .task {
            if store.packages.isEmpty && !store.isLoadingProducts { store.start(forceRefresh: true) }
        }
        .onDisappear { store.clearError() }
    }

    private var selectedPackage: Package? {
        if let selectedIdentifier, let package = store.packages.first(where: { $0.identifier == selectedIdentifier }) {
            return package
        }
        return store.yearlyPackage ?? store.packages.first
    }

    private var disclosure: String {
        guard let package = selectedPackage else { return "Prices are shown before you buy and vary by region." }
        if package.kind == .lifetime {
            return "\(package.priceLabel). One-time purchase with no subscription or automatic renewal."
        }
        return ConversionCopy.disclosure(trialLabel: store.eligibleIntroLabel(for: package), priceLabel: package.priceLabel)
    }

    private func selectDefault() {
        guard let package = store.yearlyPackage ?? store.packages.first else {
            selectedIdentifier = nil
            return
        }
        if let selectedIdentifier, store.packages.contains(where: { $0.identifier == selectedIdentifier }) { return }
        selectedIdentifier = package.identifier
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.ember)
                .frame(width: 24)
            Text(text).font(.subheadline)
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let detail: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Theme.ember : Theme.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(Theme.mint)
                }
            }
            Spacer(minLength: 8)
            Text(price).fontWeight(.semibold)
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Theme.ember : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(price)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

/// What Sun+ adds, in the order the paywall and onboarding list it.
struct PlusBenefit: Identifiable {
    let symbol: String
    let text: String
    var id: String { symbol }

    static let all = [
        PlusBenefit(symbol: "calendar", text: "Every sunrise and sunset score for the week ahead"),
        PlusBenefit(symbol: "cloud.bolt.fill", text: "Alerts before thunderstorms roll in"),
        PlusBenefit(symbol: "rainbow", text: "A heads-up when showers and low sun could make a rainbow"),
        PlusBenefit(symbol: "cloud.fog.fill", text: "Fog alerts for soft, moody light"),
        PlusBenefit(symbol: "slider.horizontal.3", text: "Your own alert score and lead time"),
    ]
}
