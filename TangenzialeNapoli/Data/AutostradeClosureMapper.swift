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

    enum EventKind {
        case segment
        case ramp(ClosureRampImpact.Kind)
    }

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

        for event in a56 {
            guard eventKind(event) != nil else {
                // A closure-group row of a type the app cannot interpret yet
                // (e.g. "Allacciamento Chiuso") must degrade the quality
                // indicator, not vanish behind a green "all verified" state.
                if isUnrecognizedClosureType(event) {
                    expected += 1
                    issues.append(issue(for: event, occurrenceCount: 1))
                }
                continue
            }

            let parsedWindows = parsedWindows(event)
            guard !parsedWindows.isEmpty else {
                // A recognized closure whose dates cannot be read is a live
                // problem, not an empty schedule.
                expected += 1
                issues.append(issue(for: event, occurrenceCount: 1))
                continue
            }
            let windows = parsedWindows.filter { $0.end >= now }
            guard !windows.isEmpty else { continue }   // fully in the past

            expected += windows.count

            let hasConflict = A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsPri,
                named: event.locpri
            ) || A56Line.hasResolutionConflict(
                pointID: event.cPntDtxPlsSec,
                named: event.locsec
            )
            // When the official id and its label point at two different
            // places, the position is unreliable: report instead of guessing.
            let mapped = hasConflict ? [] : closures(from: event, windows: windows)
            mappedClosures.append(contentsOf: mapped)
            if mapped.count != windows.count {
                issues.append(issue(for: event, occurrenceCount: windows.count))
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

    private static func closures(from e: AutostradeEvent, windows: [Occurrence]) -> [RoadClosure] {
        guard let kind = eventKind(e) else { return [] }

        let both = isBothDirections(e)
        let direction = primaryDirection(e)

        let fromExit: Int
        let toExit: Int
        var rampImpacts: [ClosureRampImpact] = []

        switch kind {
        case .segment:
            // The notice text is the fallback for rows whose location fields
            // are incomplete. A one-endpoint segment is never published as a
            // zero-length stretch: better an explicit gap in the report than
            // an understated closure.
            let noticeExits = NoticeText.segmentEndpoints(in: e.tDesIt ?? "")
            guard let a = A56Line.resolveExit(pointID: e.cPntDtxPlsPri, named: e.locpri)
                    ?? noticeExits?.0,
                  let b = A56Line.resolveExit(pointID: e.cPntDtxPlsSec, named: e.locsec)
                    ?? noticeExits?.1
            else { return [] }
            (fromExit, toExit) = A56Line.orderedEndpoints(a, b, direction: direction)
        case .ramp(let rampKind):
            guard let a = A56Line.resolveExit(pointID: e.cPntDtxPlsPri, named: e.locpri) else { return [] }
            fromExit = a
            toExit = a
            rampImpacts = [ClosureRampImpact(exitNumber: a, kind: rampKind, direction: direction)]
        }

        let reason = (e.tDesFraCauIt?.isEmpty == false ? e.tDesFraCauIt! : "Lavori")
        let isFull = { if case .segment = kind { return true } else { return false } }()
        let suggestions = NoticeText.suggestions(in: e.tDesIt ?? "")
        let source = e.tDesIt ?? ""

        return windows.map { window in
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
                suggestedAlternatives: suggestions.map(\.exitNumber),
                alternativeSuggestions: suggestions,
                isFullClosure: isFull,
                sourceText: source,
                evidence: .scheduled
            )
        }
    }

    private static func issue(for event: AutostradeEvent, occurrenceCount: Int) -> MappingIssue {
        MappingIssue(
            eventID: event.cEle ?? "senza-id",
            type: event.tDesFraIt ?? "tipo sconosciuto",
            primaryLocation: event.locpri ?? "",
            secondaryLocation: event.locsec ?? "",
            occurrenceCount: occurrenceCount
        )
    }

    // MARK: - Field interpretation

    static func eventKind(_ e: AutostradeEvent) -> EventKind? {
        let t = A56Line.normalize(e.tDesFraIt ?? "")
        if t.contains("tratto chiuso") { return .segment }
        if t.contains("entrata chiusa") { return .ramp(.entrance) }
        if t.contains("uscita chiusa") { return .ramp(.exit) }
        return nil   // "Area di Servizio Chiusa" and anything else: not a route closure
    }

    /// A closure-group row ("C") whose type the mapper does not understand but
    /// whose wording says something is closed or deviated. The group check
    /// filters out non-closures ("Coda"), the wording check filters out
    /// benign unknown types.
    static func isUnrecognizedClosureType(_ e: AutostradeEvent) -> Bool {
        guard e.cGrpTip == "C", eventKind(e) == nil else { return false }
        let t = A56Line.normalize(e.tDesFraIt ?? "")
        return t.contains("chius") || t.contains("deviaz")
    }

    static func isBothDirections(_ e: AutostradeEvent) -> Bool {
        e.cDir == "B" || A56Line.normalize(e.tDesDirIt ?? "").contains("entrambe")
    }

    static func primaryDirection(_ e: AutostradeEvent) -> Direction {
        let text = A56Line.normalize(e.tDesDirIt ?? "")
        if text.contains("capodichino") { return .towardCapodichino }
        if text.contains("pozzuoli") { return .towardPozzuoli }
        // Fall back to the code: N is Pozzuoli, P is Capodichino.
        return e.cDir == "P" ? .towardCapodichino : .towardPozzuoli
    }

    // MARK: - Windows

    struct Occurrence: Sendable {
        let start: Date
        let end: Date
    }

    /// The concrete closure windows for an event: the per-day `indisponibilita`
    /// entries when present, otherwise the overall start/stop. Timestamps that
    /// fail the sanity check are treated as unreadable, so a schema change on
    /// the date fields degrades visibly instead of hiding events.
    static func parsedWindows(_ e: AutostradeEvent) -> [Occurrence] {
        var windows: [Occurrence] = []
        if let list = e.indisponibilita, !list.isEmpty {
            for w in list {
                if let s = sanitizedDate(w.dIni), let f = sanitizedDate(w.dFin), s < f {
                    windows.append(Occurrence(start: s, end: f))
                }
            }
        }
        if windows.isEmpty, let s = sanitizedDate(e.dSta), let f = sanitizedDate(e.dSto), s < f {
            windows.append(Occurrence(start: s, end: f))
        }
        return windows
    }

    /// Accepts epoch-millisecond values only within a plausible range for a
    /// traffic notice (2020 through two years from now).
    private static func sanitizedDate(_ milliseconds: Double?) -> Date? {
        guard let milliseconds else { return nil }
        let date = Date(timeIntervalSince1970: milliseconds / 1000)
        let lowerBound = Date(timeIntervalSince1970: 1_577_836_800)   // 2020-01-01
        let upperBound = Date.now.addingTimeInterval(2 * 365 * 24 * 3600)
        guard date >= lowerBound, date <= upperBound else { return nil }
        return date
    }
}
