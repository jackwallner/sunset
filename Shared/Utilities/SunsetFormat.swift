import Foundation

enum SunsetFormat {
    static func time(_ date: Date, zone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// "Tonight", "Tomorrow", then the weekday.
    static func dayLabel(_ date: Date, zone: TimeZone = .current, now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) { return "Tonight" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func shortDay(_ date: Date, zone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func monthDay(_ date: Date, zone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func minutes(_ minutes: Int) -> String {
        if minutes % 60 == 0 && minutes >= 60 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(minutes) min"
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = date.timeIntervalSince(now)
        if seconds < 60 { return "now" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds < 3600 ? [.minute] : [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: seconds) ?? ""
    }
}
