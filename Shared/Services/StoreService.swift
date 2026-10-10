import Combine
import Foundation
import os
import StoreKit
import WidgetKit
@preconcurrency import RevenueCat

enum RevenueCatConfig {
    /// Public iOS SDK key (RevenueCat project `proj2164a1b0`). Never configured on the simulator.
    static let publicSDKKey = "appl_PWhTgZRZYAmuffZiWmlDPcYCneg"
    static let proEntitlement = "pro"
}

enum SunsetProduct {
    static let monthly = "com.jackwallner.sunset.monthly"
    static let yearly = "com.jackwallner.sunset.yearly"
    static let lifetime = "com.jackwallner.sunset.lifetime"
}

enum PurchaseState {
    case purchased
    case cancelled
    case pending
}

enum PackageKind: Int {
    case lifetime = 0
    case yearly = 1
    case monthly = 2
    case other = 3

    init(package: Package) {
        switch package.packageType {
        case .lifetime: self = .lifetime
        case .annual: self = .yearly
        case .monthly: self = .monthly
        default:
            let id = package.storeProduct.productIdentifier.lowercased()
            if id.contains("lifetime") { self = .lifetime }
            else if id.contains("yearly") || id.contains("annual") { self = .yearly }
            else if id.contains("monthly") { self = .monthly }
            else { self = .other }
        }
    }
}

extension Package {
    var kind: PackageKind { PackageKind(package: self) }

    var displayName: String {
        switch kind {
        case .lifetime: "Lifetime"
        case .yearly: "Yearly"
        case .monthly: "Monthly"
        case .other: storeProduct.localizedTitle
        }
    }

    var priceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        return period.value == 1
            ? "\(storeProduct.localizedPriceString) / \(unit)"
            : "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    var introOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return "\(period.value)-day free trial"
        case .week: return "\(period.value * 7)-day free trial"
        case .month: return period.value == 1 ? "1-month free trial" : "\(period.value)-month free trial"
        case .year: return period.value == 1 ? "1-year free trial" : "\(period.value)-year free trial"
        @unknown default: return nil
        }
    }
}

@MainActor
final class StoreService: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = StoreService()

    @Published private(set) var isPro = false {
        didSet {
            guard oldValue != isPro else { return }
            ForecastCache.isPro = isPro
            WidgetCenter.shared.reloadAllTimelines()
            Task { await ForecastStore.shared.rescheduleAlerts() }
        }
    }
    @Published private(set) var packages: [Package] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var introEligibility: [String: Bool] = [:]
    @Published private(set) var introEligibilityResolved = false

    private let logger = Logger(subsystem: "com.jackwallner.sunset", category: "Store")
    private var isConfigured = false
    private var impressionsThisSession: Set<String> = []

    private override init() {
        super.init()
        isPro = ForecastCache.isPro
    }

    func start(forceRefresh: Bool = false) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DemoPro") {
            isPro = true
            return
        }
        #endif
        configureIfNeeded()
        guard isConfigured else {
            #if targetEnvironment(simulator)
            Task { await loadStoreKitTestingProducts() }
            #endif
            return
        }
        Task {
            await refreshStatus()
            await loadOffering(forceRefresh: forceRefresh)
        }
    }

    var yearlyPackage: Package? { packages.first { $0.kind == .yearly } }
    var monthlyPackage: Package? { packages.first { $0.kind == .monthly } }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.introOfferLabel != nil, introEligibilityResolved else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? false
    }

    func eligibleIntroLabel(for package: Package) -> String? {
        isEligibleForIntroOffer(package) ? package.introOfferLabel : nil
    }

    var canPitchFreeTrial: Bool {
        guard let yearly = yearlyPackage else { return false }
        return isEligibleForIntroOffer(yearly)
    }

    @discardableResult
    func purchase(_ package: Package) async -> PurchaseState? {
        guard isConfigured else { return nil }
        isLoading = true
        defer { isLoading = false }
        let eligible = isEligibleForIntroOffer(package)
        do {
            let result = try await Purchases.shared.purchase(package: package)
            update(customerInfo: result.customerInfo)
            if result.userCancelled {
                errorMessage = ConversionCopy.purchaseCancelledMessage(eligibleForTrial: eligible)
                return .cancelled
            }
            if isPro { return .purchased }
            errorMessage = ConversionCopy.purchasePendingMessage
            return .pending
        } catch {
            if (error as NSError).code == ErrorCode.purchaseCancelledError.rawValue {
                errorMessage = ConversionCopy.purchaseCancelledMessage(eligibleForTrial: eligible)
                return .cancelled
            }
            await refreshIntroEligibility()
            errorMessage = ConversionCopy.purchaseFailedMessage(eligibleForTrial: eligible)
            return nil
        }
    }

    func restore() async {
        guard isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            update(customerInfo: try await Purchases.shared.restorePurchases())
            errorMessage = isPro ? nil : "No active Sun+ purchase was found for this Apple ID."
        } catch {
            errorMessage = "Restore failed. Please try again."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func trackPaywallImpression(id: String) {
        guard isConfigured, !impressionsThisSession.contains(id) else { return }
        impressionsThisSession.insert(id)
        Purchases.shared.trackCustomPaywallImpression(CustomPaywallImpressionParams(paywallId: id))
    }

    #if DEBUG
    func setLocalOverride(isPro: Bool) {
        self.isPro = isPro
        ForecastCache.isPro = isPro
    }
    #endif

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in self.update(customerInfo: customerInfo) }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        #if targetEnvironment(simulator)
        // Agent and simulator runs never touch the production RevenueCat
        // project: a configure call there creates a fake customer in the live
        // charts. StoreKit Testing plus the local override cover the paywall.
        return
        #else
        guard RevenueCatConfig.publicSDKKey.hasPrefix("appl_") else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.publicSDKKey)
        Purchases.shared.delegate = self
        isConfigured = true
        #endif
    }

    private func refreshStatus() async {
        do {
            update(customerInfo: try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent))
        } catch {
            errorMessage = "Could not verify purchases."
        }
    }

    private func loadOffering(forceRefresh: Bool) async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings: Offerings
            if forceRefresh, let refreshed = try await Purchases.shared.syncAttributesAndOfferingsIfNeeded() {
                offerings = refreshed
            } else {
                offerings = try await Purchases.shared.offerings()
            }
            let offering = offerings.offering(identifier: "default") ?? offerings.current
            packages = (offering?.availablePackages ?? []).sorted { $0.kind.rawValue < $1.kind.rawValue }
            errorMessage = nil
            await refreshIntroEligibility()
        } catch {
            logger.error("Product fetch failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Couldn't load purchase options. Check your connection and try again."
        }
    }

    private func refreshIntroEligibility() async {
        let identifiers = packages
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map { $0.storeProduct.productIdentifier }
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            introEligibilityResolved = true
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
        introEligibilityResolved = true
    }

    private func update(customerInfo: CustomerInfo) {
        isPro = customerInfo.entitlements.active[RevenueCatConfig.proEntitlement] != nil
        ForecastCache.isPro = isPro
    }

    #if targetEnvironment(simulator)
    /// Renders the real paywall headlessly. Under `xcodebuild test` or the
    /// Xcode scheme StoreKit Testing serves `Sunset.storekit`; under a plain
    /// `simctl launch` the fixtures below stand in with the same prices.
    private func loadStoreKitTestingProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        if ProcessInfo.processInfo.arguments.contains("-PaywallSnapshot") {
            apply(simulatorProducts: Self.fixtureProducts())
        } else if let live = await Self.storeKitTestingProducts(), !live.isEmpty {
            apply(simulatorProducts: live)
        } else {
            apply(simulatorProducts: Self.fixtureProducts())
        }
        introEligibility = Dictionary(uniqueKeysWithValues: packages.map { ($0.storeProduct.productIdentifier, true) })
        introEligibilityResolved = true
        errorMessage = nil
    }

    private func apply(simulatorProducts products: [StoreProduct]) {
        packages = products
            .map { product in
                Package(
                    identifier: product.productIdentifier,
                    packageType: Self.packageType(for: product.productIdentifier),
                    storeProduct: product,
                    offeringIdentifier: "default",
                    webCheckoutUrl: nil
                )
            }
            .sorted { $0.kind.rawValue < $1.kind.rawValue }
    }

    private static func storeKitTestingProducts() async -> [StoreProduct]? {
        let identifiers: Set<String> = [SunsetProduct.monthly, SunsetProduct.yearly, SunsetProduct.lifetime]
        guard let sk2 = try? await StoreKit.Product.products(for: identifiers) else { return nil }
        return sk2.map { StoreProduct(sk2Product: $0) }
    }

    /// Same prices and trial as `Sunset.storekit`. Keep in sync.
    private static func fixtureProducts() -> [StoreProduct] {
        let locale = Locale(identifier: "en_US")
        func weekTrial() -> TestStoreProductDiscount {
            TestStoreProductDiscount(
                identifier: "free_trial", price: 0, localizedPriceString: "$0.00",
                paymentMode: .freeTrial, subscriptionPeriod: .init(value: 1, unit: .week),
                numberOfPeriods: 1, type: .introductory
            )
        }
        return [
            TestStoreProduct(
                localizedTitle: "Sun+ Monthly", price: 1.99, currencyCode: "USD",
                localizedPriceString: "$1.99", productIdentifier: SunsetProduct.monthly,
                productType: .autoRenewableSubscription, localizedDescription: "Sun+, billed monthly.",
                subscriptionPeriod: .init(value: 1, unit: .month), introductoryDiscount: weekTrial(), locale: locale
            ).toStoreProduct(),
            TestStoreProduct(
                localizedTitle: "Sun+ Yearly", price: 14.99, currencyCode: "USD",
                localizedPriceString: "$14.99", productIdentifier: SunsetProduct.yearly,
                productType: .autoRenewableSubscription, localizedDescription: "Sun+, billed yearly.",
                subscriptionPeriod: .init(value: 1, unit: .year), introductoryDiscount: weekTrial(), locale: locale
            ).toStoreProduct(),
            TestStoreProduct(
                localizedTitle: "Sun+ Lifetime", price: 29.99, currencyCode: "USD",
                localizedPriceString: "$29.99", productIdentifier: SunsetProduct.lifetime,
                productType: .nonConsumable, localizedDescription: "Sun+, one-time purchase.",
                subscriptionPeriod: nil, introductoryDiscount: nil, locale: locale
            ).toStoreProduct(),
        ]
    }

    private static func packageType(for identifier: String) -> PackageType {
        if identifier.contains("lifetime") { return .lifetime }
        if identifier.contains("yearly") { return .annual }
        return .monthly
    }
    #endif
}
