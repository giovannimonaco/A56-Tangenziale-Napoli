import Foundation

/// Maps the real-time eventi.json feed. It keeps reporting a closure after it
/// has started, which covers the overnight gap once previsioni.json drops the
/// row.
nonisolated enum AutostradeRealtimeClosureMapper {

    struct MappingReport: Sendable {
        let closures: [RoadClosure]
        let expectedEvents: Int
        let mappedEvents: Int
        let issues: [AutostradeClosureMapper.MappingIssue]

        var isComplete: Bool {
            expectedEvents == mappedEvents && issues.isEmpty
        }
    }

    static func closures(
        from events: [AutostradeEvent],
        now: Date = .now
    ) -> [RoadClosure] {
        mappingReport(from: events, now: now).closures
    }

    /// Counts every active A56 closure row before mapping it, so an incomplete
    /// live interpretation is visible in the app's quality indicator.
    static func mappingReport(
        from events: [AutostradeEvent],
        now: Date = .now
    ) -> MappingReport {
        let a56 = events.filter { $0.cStr == AutostradeClosureMapper.roadCode }
        let relevant = a56.filter {
            $0.cGrpTip == "C"
                && AutostradeClosureMapper.eventKind($0) != nil
                && (endDate($0).map { $0 > now } ?? true)
        }
        let unrecognized = a56.filter {
            AutostradeClosureMapper.isUnrecognizedClosureType($0)
                && (endDate($0).map { $0 > now } ?? true)
        }

        var closures: [RoadClosure] = []
        var issues: [AutostradeClosureMapper.MappingIssue] = []
        for event in relevant {
            let hasConflict = A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsPri,
                named: event.locpri
            ) || A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsSec,
                named: event.locsec
            )
            if let mapped = closure(from: event, now: now), !hasConflict {
                closures.append(mapped)
            } else {
                issues.append(issue(for: event))
            }
        }
        for event in unrecognized {
            issues.append(issue(for: event))
        }

        closures.sort { $0.start < $1.start }
        let report = MappingReport(
            closures: closures,
            expectedEvents: relevant.count + unrecognized.count,
            mappedEvents: closures.count,
            issues: issues
        )
        AppLog.log(
            "A56 realtime coverage=\(report.mappedEvents)/\(report.expectedEvents), issues=\(issues.map(\.summary))",
            "map"
        )
        return report
    }

    private static func closure(
        from event: AutostradeEvent,
        now: Date
    ) -> RoadClosure? {
        guard let kind = AutostradeClosureMapper.eventKind(event),
              let end = endDate(event),
              end > now
        else { return nil }

        let bothDirections = AutostradeClosureMapper.isBothDirections(event)
        let direction = AutostradeClosureMapper.primaryDirection(event)
        let fromExit: Int
        let toExit: Int
        let rampImpacts: [ClosureRampImpact]
        let isFullClosure: Bool

        switch kind {
        case .segment:
            // Fallback for the occasional live row whose location fields are
            // incomplete: "Tratto Chiuso tra Agnano e Cuma fino alle …".
            let noticeExits = NoticeText.segmentEndpoints(in: event.tDesIt ?? "")
            guard let first = A56Line.resolveExit(
                pointID: event.cPntDtxPlsPri,
                named: event.locpri
            ) ?? noticeExits?.0,
                  let second = A56Line.resolveExit(
                    pointID: event.cPntDtxPlsSec,
                    named: event.locsec
                  ) ?? noticeExits?.1
            else { return nil }
            (fromExit, toExit) = A56Line.orderedEndpoints(first, second, direction: direction)
            rampImpacts = []
            isFullClosure = true

        case .ramp(let rampKind):
            guard let exit = A56Line.resolveExit(
                pointID: event.cPntDtxPlsPri,
                named: event.locpri
            ) else { return nil }
            fromExit = exit
            toExit = exit
            rampImpacts = [
                ClosureRampImpact(exitNumber: exit, kind: rampKind, direction: direction)
            ]
            isFullClosure = false
        }

        let suggestions = NoticeText.suggestions(in: event.tDesIt ?? "")
        return RoadClosure(
            id: event.cEle ?? fallbackID(
                kind: kind,
                fromExit: fromExit,
                toExit: toExit,
                direction: direction,
                end: end
            ),
            start: activationDate(event, now: now),
            end: end,
            direction: direction,
            affectsBothDirections: bothDirections,
            fromExit: fromExit,
            toExit: toExit,
            rampImpacts: rampImpacts,
            reason: nonEmpty(event.tDesFraCauIt) ?? "Lavori",
            suggestedAlternatives: suggestions.map(\.exitNumber),
            alternativeSuggestions: suggestions,
            isFullClosure: isFullClosure,
            sourceText: event.tDesIt ?? "",
            evidence: .realtime
        )
    }

    private static func issue(for event: AutostradeEvent) -> AutostradeClosureMapper.MappingIssue {
        .init(
            eventID: event.cEle ?? "senza-id",
            type: event.tDesFraIt ?? "tipo sconosciuto",
            primaryLocation: event.locpri ?? "",
            secondaryLocation: event.locsec ?? "",
            occurrenceCount: 1
        )
    }

    /// Content-derived id for the rare row without `c_ele`. A random value
    /// here would re-archive the same closure on every fetch.
    private static func fallbackID(
        kind: AutostradeClosureMapper.EventKind,
        fromExit: Int,
        toExit: Int,
        direction: Direction,
        end: Date
    ) -> String {
        let kindKey = { if case .segment = kind { return "seg" } else { return "ramp" } }()
        return "live_\(kindKey)_\(fromExit)-\(toExit)_\(direction.rawValue)_\(Int(end.timeIntervalSince1970))"
    }

    // MARK: - Dates

    /// When the closure started. `d_agg` moves forward on every editorial
    /// update of the row, so prefer the creation day encoded in `c_ele`
    /// combined with the "dalle ore HH:MM" time from the notice, when present.
    private static func activationDate(_ event: AutostradeEvent, now: Date) -> Date {
        if let raw = event.cEle, raw.count >= 8,
           let creationDay = creationDayFormatter.date(from: String(raw.prefix(8))),
           let time = NoticeText.startTime(in: event.tDesIt ?? "") {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Rome") ?? .current
            if let composed = calendar.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: 0,
                of: creationDay
            ) {
                return min(composed, now)
            }
        }
        guard let milliseconds = event.dAgg else { return now }
        return min(Date(timeIntervalSince1970: milliseconds / 1000), now)
    }

    /// `fino_al` stores a 12-digit UTC timestamp followed by the local offset,
    /// for example 04:00 UTC +02 for the driver-facing 06:00 in Naples.
    private static func endDate(_ event: AutostradeEvent) -> Date? {
        if let raw = event.finoAl,
           let parsed = finoAlFormatter.date(from: String(raw.prefix(12))) {
            return parsed
        }
        return NoticeText.endDate(in: event.tDesIt ?? "")
    }

    /// Formatters are expensive to build, and the mapper runs on every row of
    /// every refresh. `DateFormatter` is documented thread-safe for parsing
    /// since iOS 7, so sharing these across calls is fine.
    private static let finoAlFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter
    }()

    private static let creationDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
