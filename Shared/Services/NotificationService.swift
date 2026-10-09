import Foundation
import UserNotifications

/// Local alerts for the evenings worth going outside for.
///
/// Every refresh rewrites the whole set from the latest forecast, so a day
/// that drops below the threshold loses its alert and one that improves gains
/// it. Only the alert is scheduled, never a reminder after the fact.
@MainActor
enum NotificationService {
    static let prefix = "sunset.alert."

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) == true
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(forecast: SunsetForecast?, settings: AlertSettings, isPro: Bool, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard isPro, settings.alertsEnabled, let forecast else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        for day in forecast.days where day.score.total >= settings.threshold {
            let fireDate = day.sunset.addingTimeInterval(-Double(settings.leadMinutes) * 60)
            guard fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(day.score.grade.rawValue) sunset tonight: \(day.score.total)"
            content.body = "\(day.score.summary) Sunset at \(SunsetFormat.time(day.sunset, zone: forecast.timeZone)), "
                + "best light from \(SunsetFormat.time(day.bestWindowStart, zone: forecast.timeZone))."
            content.sound = .default
            content.threadIdentifier = "sunset.alerts"

            var calendar = Calendar.current
            calendar.timeZone = forecast.timeZone
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: prefix + identifier(for: day.sunset, zone: forecast.timeZone),
                content: content,
                trigger: trigger
            ))
        }
    }

    static func identifier(for sunset: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: sunset)
    }
}
