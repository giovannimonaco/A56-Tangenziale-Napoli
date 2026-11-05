import Foundation

/// Drivers need the time on the A56, even when checking from another zone.
nonisolated enum ClosureFormat {

    private static let italian = Locale(identifier: "it_IT")
    static let timeZone = TimeZone(identifier: "Europe/Rome")!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = italian
        calendar.timeZone = timeZone
        return calendar
    }()

    static var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: italian, calendar: calendar, timeZone: timeZone)
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(dateStyle.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// "lun 16 giugno", day label for cards and section headers.
    static func dayLabel(_ date: Date) -> String {
        date.formatted(
            dateStyle.weekday(.abbreviated).day().month(.wide)
        )
    }

    /// "22:00 – 06:00" for the closure's time window. When the closure crosses
    /// midnight the end gets a day offset, e.g. "22:00 – 06:00 (+1)".
    static func timeRange(_ closure: RoadClosure) -> String {
        if closure.hasUnpublishedEnd == true { return "Fine non comunicata" }
        let start = timeLabel(closure.start)
        let end = timeLabel(closure.end)
        let daySpan = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: closure.start),
            to: calendar.startOfDay(for: closure.end)
        ).day ?? 0
        let interval = daySpan > 0 ? "\(start) – \(end) (+\(daySpan))" : "\(start) – \(end)"
        return closure.reportedWindow == nil ? interval : "\(interval) · da verificare"
    }

    /// End copy for a closure already in progress. Includes the date when the
    /// closure does not end today, so a multi-day notice does not look like it
    /// finishes this morning.
    static func endLabel(_ closure: RoadClosure, reference: Date = .now) -> String {
        if closure.hasUnpublishedEnd == true { return "Fine non comunicata" }
        let time = timeLabel(closure.end)
        let warning = closure.reportedWindow == nil ? "" : " · da verificare"
        guard !calendar.isDate(closure.end, inSameDayAs: reference) else {
            return "fino alle \(time)\(warning)"
        }
        let day = closure.end.formatted(
            dateStyle.day(.twoDigits).month(.twoDigits)
        )
        return "fino \(day) · \(time)\(warning)"
    }

    /// Time copy for one row of the day-by-day scheduled view. Multi-day
    /// notices are described relative to that day instead of with a `+N`
    /// interval.
    static func scheduledTimeLabel(_ closure: RoadClosure, on day: Date) -> String {
        if closure.reportedWindow != nil || closure.hasUnpublishedEnd == true { return timeRange(closure) }
        let days = closure.scheduleDays(notBefore: closure.start, calendar: calendar)
        guard days.count > 1, let first = days.first, let last = days.last else {
            return timeRange(closure)
        }

        let startTime = timeLabel(closure.start)
        let endTime = timeLabel(closure.end)
        if calendar.isDate(day, inSameDayAs: first) {
            return "da \(startTime) · continua"
        }
        if calendar.isDate(day, inSameDayAs: last) {
            return "continua · fino \(endTime)"
        }
        return "continua"
    }

    /// "16/06/25 · Lunedì", date and weekday for a day header.
    static func dayDateLabel(_ date: Date) -> String {
        let numeric = date.formatted(
            dateStyle.day(.twoDigits).month(.twoDigits).year(.twoDigits)
        )
        let weekday = date.formatted(dateStyle.weekday(.wide))
        let capitalized = weekday.prefix(1).uppercased() + weekday.dropFirst()
        return "\(numeric) · \(capitalized)"
    }

    /// Timestamp for the data-status line: "alle 22:15" if today, otherwise
    /// with an explicit day ("ieri alle 22:15", "01/08 alle 22:15"). A bare
    /// time would let days-old data pass for today's.
    static func updateTimeLabel(_ date: Date, reference: Date = .now) -> String {
        let time = timeLabel(date)
        if calendar.isDate(date, inSameDayAs: reference) {
            return "alle \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "ieri alle \(time)"
        }
        let day = date.formatted(
            dateStyle.day(.twoDigits).month(.twoDigits)
        )
        return "\(day) alle \(time)"
    }

    /// Relative label for upcoming days, e.g. "Tra 2 giorni".
    static func relativeDayName(_ date: Date, reference: Date = .now) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: reference),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case ...0: return "Oggi"
        case 1:    return "Domani"
        default:   return "Tra \(days) giorni"
        }
    }
}
