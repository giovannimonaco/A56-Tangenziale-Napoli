//
//  AutostradeRealtimeClosureMapper.swift
//  TangenzialeNapoli
//
//  Maps the official real-time "eventi.json" feed. This feed is the overnight
//  safety net: it still reports a closure after it has started, even when the
//  forward-looking "previsioni.json" feed no longer contains yesterday's row.
//

import Foundation

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
        let relevant = events.filter {
            $0.cStr == AutostradeClosureMapper.roadCode
                && $0.cGrpTip == "C"
                && eventKind($0) != nil
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
                issues.append(
                    .init(
                        eventID: event.cEle ?? "senza-id",
                        type: event.tDesFraIt ?? "tipo sconosciuto",
                        primaryLocation: event.locpri ?? "",
                        secondaryLocation: event.locsec ?? "",
                        occurrenceCount: 1
                    )
                )
            }
        }
        closures.sort { $0.start < $1.start }
        let report = MappingReport(
            closures: closures,
            expectedEvents: relevant.count,
            mappedEvents: closures.count,
            issues: issues
        )
        AppLog.log(
            "A56 realtime coverage=\(report.mappedEvents)/\(report.expectedEvents), issues=\(issues.map(\.summary))",
            "map"
        )
        return report
    }

    private enum EventKind {
        case segment
        case ramp(ClosureRampImpact.Kind)
    }

    private static func closure(
        from event: AutostradeEvent,
        now: Date
    ) -> RoadClosure? {
        guard let kind = eventKind(event),
              let end = endDate(event),
              end > now
        else { return nil }

        let bothDirections = isBothDirections(event)
        let direction = primaryDirection(event)
        let fromExit: Int
        let toExit: Int
        let rampImpacts: [ClosureRampImpact]
        let isFullClosure: Bool

        switch kind {
        case .segment:
            let noticeExits = segmentExits(from: event.tDesIt ?? "")
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

        return RoadClosure(
            id: event.cEle ?? UUID().uuidString,
            start: activationDate(event, now: now),
            end: end,
            direction: direction,
            affectsBothDirections: bothDirections,
            fromExit: fromExit,
            toExit: toExit,
            rampImpacts: rampImpacts,
            reason: nonEmpty(event.tDesFraCauIt) ?? "Lavori",
            suggestedAlternatives: parseAlternatives(from: event.tDesIt ?? ""),
            isFullClosure: isFullClosure,
            sourceText: event.tDesIt ?? "",
            evidence: .realtime
        )
    }

    private static func eventKind(_ event: AutostradeEvent) -> EventKind? {
        let type = A56Line.normalize(event.tDesFraIt ?? "")
        if type.contains("tratto chiuso") { return .segment }
        if type.contains("entrata chiusa") { return .ramp(.entrance) }
        if type.contains("uscita chiusa") { return .ramp(.exit) }
        return nil
    }

    private static func isBothDirections(_ event: AutostradeEvent) -> Bool {
        event.cDir == "B" || A56Line.normalize(event.tDesDirIt ?? "").contains("entrambe")
    }

    private static func primaryDirection(_ event: AutostradeEvent) -> Direction {
        let text = A56Line.normalize(event.tDesDirIt ?? "")
        if text.contains("capodichino") { return .towardCapodichino }
        if text.contains("pozzuoli") { return .towardPozzuoli }
        return event.cDir == "P" ? .towardCapodichino : .towardPozzuoli
    }

    private static func activationDate(_ event: AutostradeEvent, now: Date) -> Date {
        guard let milliseconds = event.dAgg else { return now }
        return min(Date(timeIntervalSince1970: milliseconds / 1000), now)
    }

    /// `fino_al` stores a 12-digit UTC timestamp followed by the local offset,
    /// for example 04:00 UTC +02 for the driver-facing 06:00 in Naples.
    private static func endDate(_ event: AutostradeEvent) -> Date? {
        if let raw = event.finoAl {
            let timestamp = String(raw.prefix(12))
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMddHHmm"
            if let parsed = formatter.date(from: timestamp) { return parsed }
        }
        return parseEndFromNotice(event.tDesIt ?? "")
    }

    private static func parseEndFromNotice(_ text: String) -> Date? {
        guard let expression = try? NSRegularExpression(
            pattern: "fino alle\\s+(\\d{1,2}):(\\d{2})\\s+del\\s+(\\d{2})/(\\d{2})/(\\d{4})",
            options: [.caseInsensitive]
        ) else { return nil }

        let nsText = text as NSString
        guard let match = expression.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges == 6 else { return nil }

        let values = (1...5).compactMap { Int(nsText.substring(with: match.range(at: $0))) }
        guard values.count == 5 else { return nil }
        var components = DateComponents()
        components.hour = values[0]
        components.minute = values[1]
        components.day = values[2]
        components.month = values[3]
        components.year = values[4]
        components.timeZone = TimeZone(identifier: "Europe/Rome")
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Fallback for the occasional live row whose `locpri`/`locsec` fields are
    /// incomplete: "Tratto Chiuso tra Agnano e Cuma fino alle …".
    private static func segmentExits(from text: String) -> (Int, Int)? {
        guard let expression = try? NSRegularExpression(
            pattern: "tratto chiuso tra\\s+(.+?)\\s+e\\s+(.+?)\\s+fino alle",
            options: [.caseInsensitive]
        ) else { return nil }

        let nsText = text as NSString
        guard let match = expression.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges == 3,
              let first = A56Line.resolveExit(named: nsText.substring(with: match.range(at: 1))),
              let second = A56Line.resolveExit(named: nsText.substring(with: match.range(at: 2)))
        else { return nil }
        return (first, second)
    }

    private static func parseAlternatives(from text: String) -> [Int] {
        guard !text.isEmpty,
              let expression = try? NSRegularExpression(
                pattern: "consigliat[ao][^:]*:\\s*([^.;\\n]+)",
                options: [.caseInsensitive]
              )
        else { return [] }

        let nsText = text as NSString
        var exits: [Int] = []
        expression.enumerateMatches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            let name = nsText.substring(with: match.range(at: 1))
            if let exit = A56Line.resolveExit(named: name), !exits.contains(exit) {
                exits.append(exit)
            }
        }
        return exits
    }

    static func sameOccurrence(_ lhs: RoadClosure, _ rhs: RoadClosure) -> Bool {
        guard lhs.kind == rhs.kind,
              lhs.lowerExit == rhs.lowerExit,
              lhs.upperExit == rhs.upperExit,
              sameRampImpact(lhs, rhs),
              lhs.affectsBothDirections == rhs.affectsBothDirections,
              lhs.affectsBothDirections || lhs.direction == rhs.direction
        else { return false }
        return lhs.start < rhs.end && rhs.start < lhs.end
    }

    private static func sameRampImpact(_ lhs: RoadClosure, _ rhs: RoadClosure) -> Bool {
        guard lhs.kind == .rampsClosed else { return true }
        let lhsSignature = Set(lhs.closedRamps.map {
            "\($0.exitNumber)#\($0.kind.rawValue)"
        })
        let rhsSignature = Set(rhs.closedRamps.map {
            "\($0.exitNumber)#\($0.kind.rawValue)"
        })
        return lhsSignature == rhsSignature
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
