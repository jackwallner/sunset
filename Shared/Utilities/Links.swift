import Foundation
import StoreKit

enum SunsetLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/sunset/privacy-policy.html")!
    static let support = URL(string: "https://jackwallner.github.io/sunset/support.html")!
    static let terms = URL(string: "https://jackwallner.github.io/sunset/terms.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let openMeteo = URL(string: "https://open-meteo.com")!

    /// App Store Connect app record.
    static let appStoreID = "6821025282"

    static var writeReviewURL: URL {
        if let region = Locale.current.region?.identifier.lowercased(), region.count == 2 {
            return URL(string: "https://apps.apple.com/\(region)/app/id\(appStoreID)?action=write-review")!
        }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
