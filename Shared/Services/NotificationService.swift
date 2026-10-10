import Foundation
import UserNotifications

/// Local alerts for the skies worth going outside for.
///
/// Every refresh rewrites the whole set from the latest forecast, so a show
/// that drops below the threshold loses its alert and one that improves gains
/// it. Sunrise and sunset alerts are free; storm, rainbow and fog alerts are
/// Sun+.
@MainActor
enum NotificationService {
    static let prefix = "sunset.alert."
    /// Nothing fires overnight. An alert that would land in these hours moves
    /// to the evening before, or is dropped if that has passed.
    static let quietStartHour = 22
    static let quietEndHour = 7
    static let eveningBeforeHour = 20

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) == true
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    struct Planned: Equatable {
        var identifier: String
        var fireDate: Date
        var title: String
        var body: String
    }

    static func reschedule(forecast: SunsetForecast?, settings: AlertSettings, isPro: Bool, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard settings.alertsEnabled, let forecast else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let planned = plan(
            forecast: forecast,
            watched: settings.watched,
            threshold: settings.effectiveThreshold(isPro: isPro),
            leadMinutes: settings.effectiveLead(isPro: isPro),
            skyEventKinds: isPro ? settings.skyEventKinds : [],
            now: now
        )
        var calendar = Calendar.current
        calendar.timeZone = forecast.timeZone
        for alert in planned {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.threadIdentifier = "sunset.alerts"
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alert.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
        }
    }

    /// Pure: what would be scheduled, in fire order. Pinned by tests.
    static func plan(
        forecast: SunsetForecast,
        watched: Set<SunEvent>,
        threshold: Int,
        leadMinutes: Int,
        skyEventKinds: Set<SkyEvent.Kind>,
        now: Date
    ) -> [Planned] {
        let zone = forecast.timeZone
        var planned: [Planned] = []

        for show in forecast.days.flatMap({ [$0.sunrise, $0.sunset] })
        where watched.contains(show.event) && show.score.total >= threshold {
            // Nobody wants a buzz at 5:40 am, so sunrise alerts land the
            // evening before, early enough to set an alarm.
            let fire = show.event == .sunset
                ? show.time.addingTimeInterval(-Double(leadMinutes) * 60)
                : eveningBefore(show.time, zone: zone)
            guard let fire, fire > now, fire < show.time else { continue }
            let time = SunsetFormat.time(show.time, zone: zone)
            let start = SunsetFormat.time(show.bestWindowStart, zone: zone)
            let title = show.event == .sunset
                ? "\(show.score.grade.rawValue) sunset tonight: \(show.score.total)"
                : "\(show.score.grade.rawValue) sunrise tomorrow: \(show.score.total)"
            let body = "\(show.score.summary) \(show.event.title) at \(time), best light from \(start)."
            planned.append(Planned(
                identifier: prefix + show.event.rawValue + "." + dayKey(show.time, zone: zone),
                fireDate: fire, title: title, body: body
            ))
        }

        for event in forecast.skyEvents where skyEventKinds.contains(event.kind) {
            guard let fire = skyEventFireDate(event, zone: zone), fire > now else { continue }
            let time = SunsetFormat.time(event.start, zone: zone)
            let day = SunsetFormat.relativeDay(event.start, zone: zone, now: fire)
            planned.append(Planned(
                identifier: prefix + event.id,
                fireDate: fire,
                title: skyEventTitle(event.kind, day: day),
                body: skyEventBody(event, time: time, zone: zone)
            ))
        }
        return planned.sorted { $0.fireDate < $1.fireDate }
    }

    /// An hour of warning, pulled out of quiet hours to the evening before.
    static func skyEventFireDate(_ event: SkyEvent, zone: TimeZone) -> Date? {
        let fire = event.start.addingTimeInterval(-3600)
        guard isQuiet(fire, zone: zone) else { return fire }
        guard let evening = eveningBefore(event.start, zone: zone), evening < event.start else { return nil }
        return evening
    }

    static func isQuiet(_ date: Date, zone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: date)
        return hour >= quietStartHour || hour < quietEndHour
    }

    /// 8 pm on the evening before `date`, or the same evening when `date` is
    /// itself late at night.
    static func eveningBefore(_ date: Date, zone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: date)
        let base = hour >= eveningBeforeHour ? date : calendar.date(byAdding: .day, value: -1, to: date)
        return base.flatMap { calendar.date(bySettingHour: eveningBeforeHour, minute: 0, second: 0, of: $0) }
    }

    private static func skyEventTitle(_ kind: SkyEvent.Kind, day: String) -> String {
        switch kind {
        case .thunderstorm: "Thunderstorms \(day)"
        case .rainbow: "Rainbow chance \(day)"
        case .fog: "Fog \(day)"
        }
    }

    private static func skyEventBody(_ event: SkyEvent, time: String, zone: TimeZone) -> String {
        let until = SunsetFormat.time(event.end, zone: zone)
        switch event.kind {
        case .thunderstorm:
            return "Storms are forecast from about \(time) to \(until). Watch the sky from somewhere safe indoors."
        case .rainbow:
            return "Showers with a low sun around \(time). Face away from the sun to look for a bow."
        case .fog:
            return "Fog is forecast from about \(time) to \(until). Soft light for photos, slow going on the roads."
        }
    }

    static func dayKey(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
