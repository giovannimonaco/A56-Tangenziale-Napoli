//
//  DateFormatting.swift
//  TangenzialeNapoli
//
//  Localized date/time helpers for closures, in Italian.
//

import Foundation

enum ClosureFormat {

    private static let italian = Locale(identifier: "it_IT")

    /// "lun 16 giugno" — a friendly day label for cards and section headers.
    static func dayLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime.weekday(.abbreviated).day().month(.wide)
                .locale(italian)
        )
    }

    /// "22:00 – 06:00" for the closure's time window. If the closure crosses
    /// midnight the end is annotated, e.g. "22:00 – 06:00 (+1)".
    static func timeRange(_ closure: RoadClosure) -> String {
        let cal = Calendar.current
        let start = closure.start.formatted(.dateTime.hour().minute().locale(italian))
        let end = closure.end.formatted(.dateTime.hour().minute().locale(italian))
        let daySpan = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: closure.start),
            to: cal.startOfDay(for: closure.end)
        ).day ?? 0
        return daySpan > 0 ? "\(start) – \(end) (+\(daySpan))" : "\(start) – \(end)"
    }

    /// End copy for a closure already in progress. The date is included when
    /// it does not end today, avoiding the impression that a continuous notice
    /// ending several days from now will finish this morning.
    static func endLabel(_ closure: RoadClosure, reference: Date = .now) -> String {
        let time = closure.end.formatted(.dateTime.hour().minute().locale(italian))
        guard !Calendar.current.isDate(closure.end, inSameDayAs: reference) else {
            return "fino alle \(time)"
        }
        let day = closure.end.formatted(
            .dateTime.day(.twoDigits).month(.twoDigits).locale(italian)
        )
        return "fino \(day) · \(time)"
    }

    /// Time copy for one row of the day-by-day scheduled view. Continuous
    /// notices are described in the context of that day instead of exposing a
    /// hard-to-read multi-day `+N` interval.
    static func scheduledTimeLabel(_ closure: RoadClosure, on day: Date) -> String {
        let calendar = Calendar.current
        let days = closure.scheduleDays(notBefore: closure.start, calendar: calendar)
        guard days.count > 1, let first = days.first, let last = days.last else {
            return timeRange(closure)
        }

        let startTime = closure.start.formatted(.dateTime.hour().minute().locale(italian))
        let endTime = closure.end.formatted(.dateTime.hour().minute().locale(italian))
        if calendar.isDate(day, inSameDayAs: first) {
            return "da \(startTime) · continua"
        }
        if calendar.isDate(day, inSameDayAs: last) {
            return "continua · fino \(endTime)"
        }
        return "continua"
    }

    /// "16/06/25 · Lunedì" — explicit date and weekday for a day header.
    static func dayDateLabel(_ date: Date) -> String {
        let numeric = date.formatted(
            .dateTime.locale(italian).day(.twoDigits).month(.twoDigits).year(.twoDigits)
        )
        let weekday = date.formatted(.dateTime.locale(italian).weekday(.wide))
        let capitalized = weekday.prefix(1).uppercased() + weekday.dropFirst()
        return "\(numeric) · \(capitalized)"
    }

    /// When a timestamp was, for the data-status line: "alle 22:15" if today,
    /// otherwise with an explicit day ("ieri alle 22:15", "01/08 alle 22:15").
    /// A bare time would let three-day-old data pass for today's.
    static func updateTimeLabel(_ date: Date, reference: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute().locale(italian))
        if calendar.isDate(date, inSameDayAs: reference) {
            return "alle \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "ieri alle \(time)"
        }
        let day = date.formatted(
            .dateTime.day(.twoDigits).month(.twoDigits).locale(italian)
        )
        return "\(day) alle \(time)"
    }

    /// A relative bucket label for upcoming days, e.g. "Tra 2 giorni".
    static func relativeDayName(_ date: Date, reference: Date = .now) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: reference),
            to: cal.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case ...0: return "Oggi"
        case 1:    return "Domani"
        default:   return "Tra \(days) giorni"
        }
    }
}
