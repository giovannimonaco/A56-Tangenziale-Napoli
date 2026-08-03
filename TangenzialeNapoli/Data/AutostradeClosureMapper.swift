//
//  AutostradeClosureMapper.swift
//  TangenzialeNapoli
//
//  Converts raw `AutostradeEvent`s from previsioni.json into structured,
//  driver-facing `RoadClosure`s for the A56.
//

import Foundation

nonisolated enum AutostradeClosureMapper {

    /// Only the Tangenziale di Napoli.
    static let roadCode = "A56"

    struct MappingIssue: Equatable, Sendable {
        let eventID: String
        let type: String
        let primaryLocation: String
        let secondaryLocation: String
        let occurrenceCount: Int

        var summary: String {
            let locations = [primaryLocation, secondaryLocation]
                .filter { !$0.isEmpty }
                .joined(separator: " – ")
            return locations.isEmpty ? type : "\(type): \(locations)"
        }
    }

    struct MappingReport: Sendable {
        let closures: [RoadClosure]
        let expectedOccurrences: Int
        let mappedOccurrences: Int
        let issues: [MappingIssue]

        var isComplete: Bool {
            expectedOccurrences == mappedOccurrences && issues.isEmpty
        }
    }

    /// Map the whole feed to A56 closures (one event may expand into several
    /// occurrences, one per nightly window). Past windows are dropped.
    static func closures(from events: [AutostradeEvent], now: Date = .now) -> [RoadClosure] {
        mappingReport(from: events, now: now).closures
    }

    /// Maps the feed and counts every relevant occurrence, including failures.
    /// Callers can therefore expose incomplete coverage instead of silently
    /// presenting a partial result as complete.
    static func mappingReport(from events: [AutostradeEvent], now: Date = .now) -> MappingReport {
        let a56 = events.filter { $0.cStr == roadCode }
        var mappedClosures: [RoadClosure] = []
        var expected = 0
        var issues: [MappingIssue] = []

        for event in a56 where eventKind(event) != nil {
            let occurrenceCount = occurrenceWindows(event, now: now).count
            guard occurrenceCount > 0 else { continue }

            expected += occurrenceCount
            let mapped = closures(from: event, now: now)
            mappedClosures.append(contentsOf: mapped)
            let hasConflict = A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsPri,
                named: event.locpri
            ) || A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsSec,
                named: event.locsec
            )
            if mapped.count != occurrenceCount || hasConflict {
                issues.append(
                    MappingIssue(
                        eventID: event.cEle ?? "senza-id",
                        type: event.tDesFraIt ?? "tipo sconosciuto",
                        primaryLocation: event.locpri ?? "",
                        secondaryLocation: event.locsec ?? "",
                        occurrenceCount: occurrenceCount
                    )
                )
            }
        }

        mappedClosures.sort { $0.start < $1.start }
        let report = MappingReport(
            closures: mappedClosures,
            expectedOccurrences: expected,
            mappedOccurrences: mappedClosures.count,
            issues: issues
        )
        AppLog.log(
            "A56 planned coverage=\(report.mappedOccurrences)/\(report.expectedOccurrences), issues=\(issues.map(\.summary))",
            "map"
        )
        return report
    }

    // MARK: - Per-event mapping

    private enum EventKind {
        case segment
        case ramp(ClosureRampImpact.Kind)
    }

    private static func closures(from e: AutostradeEvent, now: Date) -> [RoadClosure] {
        guard let kind = eventKind(e) else { return [] }   // skip e.g. "Area di Servizio Chiusa"

        let both = isBothDirections(e)
        let direction = primaryDirection(e)

        // Resolve the exit endpoints.
        let fromExit: Int
        let toExit: Int
        var rampImpacts: [ClosureRampImpact] = []

        switch kind {
        case .segment:
            guard let a = A56Line.resolveExit(pointID: e.cPntDtxPlsPri, named: e.locpri) else { return [] }
            let b = A56Line.resolveExit(pointID: e.cPntDtxPlsSec, named: e.locsec) ?? a
            (fromExit, toExit) = A56Line.orderedEndpoints(a, b, direction: direction)
        case .ramp(let rampKind):
            guard let a = A56Line.resolveExit(pointID: e.cPntDtxPlsPri, named: e.locpri) else { return [] }
            fromExit = a
            toExit = a
            rampImpacts = [ClosureRampImpact(exitNumber: a, kind: rampKind, direction: direction)]
        }

        let reason = (e.tDesFraCauIt?.isEmpty == false ? e.tDesFraCauIt! : "Lavori")
        let isFull = { if case .segment = kind { return true } else { return false } }()
        let alternatives = parseAlternatives(from: e.tDesIt ?? "")
        let source = e.tDesIt ?? ""

        // Expand into one closure per future window.
        return occurrenceWindows(e, now: now).map { window in
            RoadClosure(
                id: "\(e.cEle ?? "evt")#\(Int(window.start.timeIntervalSince1970))",
                start: window.start,
                end: window.end,
                direction: direction,
                affectsBothDirections: both,
                fromExit: fromExit,
                toExit: toExit,
                rampImpacts: rampImpacts,
                reason: reason,
                suggestedAlternatives: alternatives,
                isFullClosure: isFull,
                sourceText: source,
                evidence: .scheduled
            )
        }
    }

    // MARK: - Field interpretation

    private static func eventKind(_ e: AutostradeEvent) -> EventKind? {
        let t = A56Line.normalize(e.tDesFraIt ?? "")
        if t.contains("tratto chiuso") { return .segment }
        if t.contains("entrata chiusa") { return .ramp(.entrance) }
        if t.contains("uscita chiusa") { return .ramp(.exit) }
        return nil   // "Area di Servizio Chiusa" and anything else: not a route closure
    }

    private static func isBothDirections(_ e: AutostradeEvent) -> Bool {
        e.cDir == "B" || A56Line.normalize(e.tDesDirIt ?? "").contains("entrambe")
    }

    private static func primaryDirection(_ e: AutostradeEvent) -> Direction {
        let text = A56Line.normalize(e.tDesDirIt ?? "")
        if text.contains("capodichino") { return .towardCapodichino }
        if text.contains("pozzuoli") { return .towardPozzuoli }
        // Fall back to the code: N → Pozzuoli, P → Capodichino.
        return e.cDir == "P" ? .towardCapodichino : .towardPozzuoli
    }

    /// Pull suggested alternative svincoli out of the notice text, e.g.
    /// "Entrata consigliata verso Pozzuoli: Vomero." → exit 9.
    private static func parseAlternatives(from text: String) -> [Int] {
        guard !text.isEmpty,
              let re = try? NSRegularExpression(
                pattern: "consigliat[ao][^:]*:\\s*([^.;\\n]+)",
                options: [.caseInsensitive]
              )
        else { return [] }

        let ns = text as NSString
        var exits: [Int] = []
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match, match.numberOfRanges > 1 else { return }
            let name = ns.substring(with: match.range(at: 1))
            if let exit = A56Line.resolveExit(named: name), !exits.contains(exit) {
                exits.append(exit)
            }
        }
        return exits
    }

    // MARK: - Windows

    private struct Occurrence { let start: Date; let end: Date }

    /// The concrete closure windows for an event: the per-day `indisponibilita`
    /// entries when present, otherwise the overall start/stop. Windows that have
    /// already ended are dropped.
    private static func occurrenceWindows(_ e: AutostradeEvent, now: Date) -> [Occurrence] {
        func date(_ ms: Double?) -> Date? { ms.map { Date(timeIntervalSince1970: $0 / 1000) } }

        var windows: [Occurrence] = []
        if let list = e.indisponibilita, !list.isEmpty {
            for w in list {
                if let s = date(w.dIni), let f = date(w.dFin) { windows.append(Occurrence(start: s, end: f)) }
            }
        }
        if windows.isEmpty, let s = date(e.dSta), let f = date(e.dSto) {
            windows.append(Occurrence(start: s, end: f))
        }
        // Keep only windows that haven't fully ended yet.
        return windows.filter { $0.end >= now }
    }
}
