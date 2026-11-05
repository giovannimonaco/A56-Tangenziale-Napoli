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
        let a56 = events.filter { $0.roadCode == AutostradeClosureMapper.roadCode }
        let relevant = a56.filter {
            AutostradeClosureMapper.eventKind($0) != nil
                && (endDate($0).map { $0 > now } ?? true)
        }
        let unrecognized = a56.filter {
            AutostradeClosureMapper.isUnrecognizedClosureType($0)
                && (endDate($0).map { $0 > now } ?? true)
        }

        var closures: [RoadClosure] = []
        var issues: [AutostradeClosureMapper.MappingIssue] = []
        for event in relevant {
            if let mapped = closure(from: event, now: now) {
                closures.append(mapped)
                if mapped.reportedWindow != nil {
                    var timing = issue(for: event)
                    timing.detail = "Orari discordanti"
                    timing.coveredByMappedWindow = true
                    issues.append(timing)
                } else if mapped.hasUnpublishedEnd == true, event.finoAl?.isEmpty == false {
                    var timing = issue(for: event)
                    timing.detail = "Fine non leggibile"
                    issues.append(timing)
                }
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
              let direction = AutostradeClosureMapper.primaryDirection(event) else { return nil }
        let start = activationDate(event, now: now)
        let ends = publishedEnds(event)
        let end = ends.max() ?? .distantFuture
        guard start <= now, end > now else { return nil }

        let bothDirections = AutostradeClosureMapper.isBothDirections(event)
        let fromExit: Int
        let toExit: Int
        let rampImpacts: [ClosureRampImpact]
        let isFullClosure: Bool

        switch kind {
        case .segment:
            guard let (first, second) = AutostradeClosureMapper.segmentEndpoints(event) else { return nil }
            (fromExit, toExit) = A56Line.orderedEndpoints(first, second, direction: direction)
            rampImpacts = []
            isFullClosure = true

        case .ramp, .bothRamps:
            guard let exit = AutostradeClosureMapper.rampExit(event) else { return nil }
            fromExit = exit
            toExit = exit
            rampImpacts = AutostradeClosureMapper.validRampImpacts(for: kind, at: exit, direction: direction)
            guard !rampImpacts.isEmpty else { return nil }
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
            start: start,
            end: end,
            direction: direction,
            affectsBothDirections: bothDirections,
            fromExit: fromExit,
            toExit: toExit,
            rampImpacts: rampImpacts,
            reason: event.tDesFraCauIt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            suggestedAlternatives: suggestions.compactMap(\.exitNumber),
            alternativeSuggestions: suggestions,
            isFullClosure: isFullClosure,
            sourceText: event.tDesIt ?? "",
            evidence: .realtime,
            reportedWindow: ends.min().flatMap { $0 < end ? .init(start: start, end: $0) : nil },
            hasUnpublishedEnd: ends.isEmpty ? true : nil
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
        let ramps = AutostradeClosureMapper.rampKinds(kind).map(\.rawValue).joined(separator: "+")
        return "live_\(ramps)_\(fromExit)-\(toExit)_\(direction.rawValue)_\(Int(end.timeIntervalSince1970))"
    }

    // MARK: - Dates

    /// Use a published start if present. The row ID can predate the closure.
    /// Otherwise the update time is only the first observed reference time.
    private static func activationDate(_ event: AutostradeEvent, now: Date) -> Date {
        if let start = AutostradeClosureMapper.sanitizedDate(event.dSta) { return start }
        if let bounds = NoticeText.plannedBounds(in: event.tDesIt ?? "") { return bounds.start }
        return min(AutostradeClosureMapper.sanitizedDate(event.dAgg) ?? now, now)
    }

    /// `fino_al` stores a 12-digit UTC timestamp followed by the local offset,
    /// for example 04:00 UTC +02 for the driver-facing 06:00 in Naples.
    private static func endDate(_ event: AutostradeEvent) -> Date? {
        publishedEnds(event).max()
    }

    private static func publishedEnds(_ event: AutostradeEvent) -> [Date] {
        let structured = event.finoAl.flatMap { raw -> Date? in
            let timestamp = String(raw.prefix(12))
            guard timestamp.count == 12, let parsed = finoAlFormatter.date(from: timestamp),
                  finoAlFormatter.string(from: parsed) == timestamp else { return nil }
            return AutostradeClosureMapper.sanitizedDate(parsed.timeIntervalSince1970 * 1000)
        }
        return [structured, NoticeText.endDate(in: event.tDesIt ?? "")].compactMap { $0 }
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

}
