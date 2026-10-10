import Foundation

enum SunsetFormat {
    static func time(_ date: Date, zone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    /// "Today", "Tomorrow", then the weekday.
    static func dayLabel(_ date: Date, zone: TimeZone = .current, now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return weekday(date, zone: zone)
    }

    /// "Tonight's sunset", "Tomorrow's sunrise", "Friday's sunset".
    static func headline(_ show: SunShow, zone: TimeZone = .current, now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let event = show.event.title.lowercased()
        if calendar.isDate(show.time, inSameDayAs: now) {
            return show.event == .sunset ? "Tonight's \(event)" : "This morning's \(event)"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(show.time, inSameDayAs: tomorrow) {
            return "Tomorrow's \(event)"
        }
        return "\(weekday(show.time, zone: zone))'s \(event)"
    }

    /// "today", "tonight", "tomorrow", "on Friday", for alert titles.
    static func relativeDay(_ date: Date, zone: TimeZone = .current, now: Date = .now) -> String {
        var calendar = Calendar.current
        calendar.timeZone = zone
        if calendar.isDate(date, inSameDayAs: now) {
            return calendar.component(.hour, from: date) >= 17 ? "tonight" : "today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return calendar.component(.hour, from: date) < 12 ? "tomorrow morning" : "tomorrow"
        }
        return "on \(weekday(date, zone: zone))"
    }

    /// "sunset", "sunrise", "sunrise or sunset"; plural "sunrises and sunsets".
    static func watchedNoun(_ events: Set<SunEvent>, plural: Bool = false) -> String {
        let names = SunEvent.allCases.filter(events.contains).map { $0.rawValue + (plural ? "s" : "") }
        return names.joined(separator: plural ? " and " : " or ")
    }

    static func weekday(_ date: Date, zone: TimeZone = .current) -> String {
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
