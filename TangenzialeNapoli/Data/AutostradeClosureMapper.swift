import Foundation

/// Maps planned events from previsioni.json to A56 `RoadClosure`s.
nonisolated enum AutostradeClosureMapper {

    static let roadCode = "A56"

    enum EventKind {
        case segment
        case ramp(ClosureRampImpact.Kind)
        case bothRamps
    }

    struct MappingIssue: Equatable, Sendable {
        let eventID: String
        let type: String
        let primaryLocation: String
        let secondaryLocation: String
        let occurrenceCount: Int
        var detail: String? = nil
        var coveredByMappedWindow = false

        var summary: String {
            let locations = [primaryLocation, secondaryLocation]
                .filter { !$0.isEmpty }
                .joined(separator: " – ")
            let subject = locations.isEmpty ? type : "\(type): \(locations)"
            return detail.map { "\(subject) · \($0)" } ?? subject
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

        var hasCompleteCoverage: Bool {
            expectedOccurrences == mappedOccurrences && issues.allSatisfy(\.coveredByMappedWindow)
        }
    }

    /// Map the whole feed to A56 closures (one event may expand into several
    /// occurrences, one per nightly window). Past windows are dropped.
    static func closures(from events: [AutostradeEvent], now: Date = .now) -> [RoadClosure] {
        mappingReport(from: events, now: now).closures
    }

    /// Maps the feed and counts every relevant occurrence, including failures,
    /// so callers can expose incomplete coverage.
    static func mappingReport(from events: [AutostradeEvent], now: Date = .now) -> MappingReport {
        let a56 = events.filter { $0.roadCode == roadCode }
        var mappedClosures: [RoadClosure] = []
        var expected = 0
        var issues: [MappingIssue] = []

        for event in a56 {
            guard eventKind(event) != nil else {
                // Closure-group rows of a type we can't interpret yet (e.g.
                // "Allacciamento Chiuso") still count against the quality
                // indicator.
                if isUnrecognizedClosureType(event) {
                    expected += 1
                    issues.append(issue(for: event, occurrenceCount: 1))
                }
                continue
            }

            let (parsedWindows, invalidWindows) = parsedWindows(event)
            let windows = parsedWindows.filter { $0.end > now }
            let expectedCount = windows.count + invalidWindows
            guard expectedCount > 0 else { continue }   // fully in the past
            expected += expectedCount
            let mapped = closures(from: event, windows: windows)
            mappedClosures.append(contentsOf: mapped)
            if mapped.count != expectedCount {
                issues.append(issue(for: event, occurrenceCount: expectedCount - mapped.count))
            }
            let discordant = mapped.isEmpty ? [] : windows.filter { $0.reportedWindow != nil }
            if !discordant.isEmpty {
                var timing = issue(for: event, occurrenceCount: discordant.count)
                timing.detail = "Orari discordanti"
                timing.coveredByMappedWindow = !discordant.contains(where: \.hasUncoveredTimes)
                issues.append(timing)
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
        guard let kind = eventKind(e), let direction = primaryDirection(e) else { return [] }

        let both = isBothDirections(e)

        let fromExit: Int
        let toExit: Int
        var rampImpacts: [ClosureRampImpact] = []

        switch kind {
        case .segment:
            guard let (a, b) = segmentEndpoints(e) else { return [] }
            (fromExit, toExit) = A56Line.orderedEndpoints(a, b, direction: direction)
        case .ramp, .bothRamps:
            guard let a = rampExit(e) else { return [] }
            fromExit = a
            toExit = a
            rampImpacts = validRampImpacts(for: kind, at: a, direction: direction)
            guard !rampImpacts.isEmpty else { return [] }
        }

        let reason = e.tDesFraCauIt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isFull = { if case .segment = kind { return true } else { return false } }()
        let suggestions = NoticeText.suggestions(in: e.tDesIt ?? "")
        let source = e.tDesIt ?? ""

        return windows.map { window in
            RoadClosure(
                id: "\(e.cEle ?? "planned_\(fromExit)-\(toExit)_\(direction.rawValue)_\(rampImpacts.map(\.kind.rawValue).joined(separator: "+"))")#\(Int(window.sourceStart.timeIntervalSince1970))",
                start: window.start,
                end: window.end,
                direction: direction,
                affectsBothDirections: both,
                fromExit: fromExit,
                toExit: toExit,
                rampImpacts: rampImpacts,
                reason: reason,
                suggestedAlternatives: suggestions.compactMap(\.exitNumber),
                alternativeSuggestions: suggestions,
                isFullClosure: isFull,
                sourceText: source,
                evidence: .scheduled,
                reportedWindow: window.reportedWindow
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
        return switch t {
        case "tratto chiuso": .segment
        case "entrata chiusa": .ramp(.entrance)
        case "uscita chiusa": .ramp(.exit)
        case "entrata e uscita chiuse", "entrata e uscita chiusa": .bothRamps
        default: nil
        }
    }

    static func rampKinds(_ kind: EventKind) -> [ClosureRampImpact.Kind] {
        switch kind {
        case .segment: []
        case .ramp(let ramp): [ramp]
        case .bothRamps: [.entrance, .exit]
        }
    }

    static func validRampImpacts(for kind: EventKind, at number: Int, direction: Direction) -> [ClosureRampImpact] {
        rampKinds(kind)
            .map { ClosureRampImpact(exitNumber: number, kind: $0, direction: direction) }
            .filter(\.existsAtInterchange)
    }

    /// The closure group is authoritative for unknown types. A row without
    /// a group is ambiguous if its type is missing or suggests a closure.
    static func isUnrecognizedClosureType(_ e: AutostradeEvent) -> Bool {
        guard eventKind(e) == nil else { return false }
        let t = A56Line.normalize(e.tDesFraIt ?? "")
        guard t != "area di servizio chiusa" else { return false }
        if e.cGrpTip == "C" { return true }
        if e.cGrpTip == "D" { return false } // services, not carriageways or ramps
        return t.isEmpty || t.contains("chius") || t.contains("deviaz") || t.contains("divieto di transito")
    }

    static func isBothDirections(_ e: AutostradeEvent) -> Bool {
        e.cDir == "B" || A56Line.normalize(e.tDesDirIt ?? "").contains("entrambe")
    }

    static func primaryDirection(_ e: AutostradeEvent) -> Direction? {
        let text = A56Line.normalize(e.tDesDirIt ?? "")
        let byText = NoticeText.direction(named: text)
        let byNotice = NoticeText.travelDirection(in: e.tDesIt ?? "")
        let byCode: Direction?
        switch e.cDir {
        case "P": byCode = .towardCapodichino
        case "N": byCode = .towardPozzuoli
        default: byCode = nil
        }
        if isBothDirections(e) {
            guard byText == nil, byCode == nil, byNotice == nil else { return nil }
            return .towardPozzuoli
        }
        let directions = Set([byText, byCode, byNotice].compactMap { $0 })
        return directions.count == 1 ? directions.first : nil
    }

    static func rampExit(_ e: AutostradeEvent) -> Int? {
        guard !A56Line.hasResolutionConflict(pointID: e.cPntDtxPlsPri, named: e.locpri) else {
            return nil
        }
        let structured = A56Line.resolveExit(pointID: e.cPntDtxPlsPri, named: e.locpri)
        let notice = NoticeText.rampExit(in: e.tDesIt ?? "")
        if let structured, let notice, structured != notice { return nil }
        return structured ?? notice
    }

    static func segmentEndpoints(_ e: AutostradeEvent) -> (Int, Int)? {
        let notice = NoticeText.segmentEndpoints(in: e.tDesIt ?? "")
        let noticePlaces = notice.map { Set([$0.0, $0.1]) }
        func resolve(_ id: Int?, _ name: String?) -> (exit: Int?, conflicts: Bool) {
            // For segments, 1117 can label the terminal as generic “Capodichino”.
            // Distinguish it from 11071 (Capodichino Svincolo) only when the
            // original notice explicitly says “Fine Tangenziale”.
            if id == 1117, noticePlaces?.contains(1) == true,
               A56Line.normalize(e.tDesIt ?? "").contains("fine tangenziale"),
               name?.isEmpty != false || A56Line.normalize(name ?? "") == "capodichino"
                    || name.flatMap(A56Line.resolveExit(named:)) == 1
                    || name.flatMap(A56Line.resolveExit(named:)) == 2 {
                return (1, false)
            }
            return (
                A56Line.resolveExit(pointID: id, named: name),
                A56Line.hasResolutionConflict(pointID: id, named: name)
            )
        }

        let first = resolve(e.cPntDtxPlsPri, e.locpri)
        let second = resolve(e.cPntDtxPlsSec, e.locsec)
        guard !first.conflicts, !second.conflicts else { return nil }
        if let a = first.exit, let b = second.exit {
            guard a != b, noticePlaces == nil || noticePlaces == Set([a, b]) else { return nil }
            return (a, b)
        }
        guard let (a, b) = notice, a != b,
              [first.exit, second.exit].compactMap({ $0 }).allSatisfy({ $0 == a || $0 == b })
        else { return nil }
        return (a, b)
    }

    // MARK: - Windows

    private struct Occurrence: Sendable {
        var start: Date
        var end: Date
        let sourceStart: Date
        var reportedWindow: RoadClosure.ReportedWindow?
        var hasUncoveredTimes = false

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
            sourceStart = start
        }
    }

    /// The concrete closure windows for an event: the per-day `indisponibilita`
    /// entries when present, otherwise the overall start/stop. Timestamps that
    /// fail the sanity check count as unreadable, so a schema change on the
    /// date fields shows up as an issue instead of hiding events.
    private static func parsedWindows(_ e: AutostradeEvent) -> ([Occurrence], Int) {
        if let list = e.indisponibilita, !list.isEmpty {
            let valid = list.compactMap { window -> Occurrence? in
                guard let s = sanitizedDate(window.dIni), let f = sanitizedDate(window.dFin), s < f
                else { return nil }
                return Occurrence(start: s, end: f)
            }
            let invalid = list.count - valid.count
            return (invalid == 0 ? compareBounds(valid, event: e) : valid, invalid)
        }
        if let s = sanitizedDate(e.dSta), let f = sanitizedDate(e.dSto), s < f {
            let text = A56Line.normalize(e.tDesIt ?? "")
            if text.contains("ogni notte") || text.contains("nelle notti") || text.contains("giornalier") {
                return ([], 1)
            }
            return (compareBounds([Occurrence(start: s, end: f)], event: e), 0)
        }
        return ([], 1)
    }

    private static func compareBounds(_ windows: [Occurrence], event: AutostradeEvent) -> [Occurrence] {
        var windows = windows.sorted { $0.start < $1.start }
        guard let first = windows.first, let last = windows.last else { return windows }
        var published = [RoadClosure.ReportedWindow]()
        if let start = sanitizedDate(event.dSta), let end = sanitizedDate(event.dSto), start < end {
            published.append(.init(start: start, end: end))
        }
        if let text = NoticeText.plannedBounds(in: event.tDesIt ?? "") { published.append(text) }
        // An event can repeat nightly. Compare its overall start/end with the
        // outer boundaries only, so a mismatch never fills the daytime gaps.
        for bound in published {
            if bound.start != first.start {
                windows[0].reportedWindow = .init(start: bound.start, end: windows.count == 1 ? bound.end : first.end)
                if abs(bound.start.timeIntervalSince(first.start)) <= 3 * 3600 {
                    windows[0].start = min(windows[0].start, bound.start)
                }
            }
            if bound.end != last.end {
                let i = windows.count - 1
                windows[i].reportedWindow = .init(start: windows.count == 1 ? bound.start : last.start, end: bound.end)
                if abs(bound.end.timeIntervalSince(last.end)) <= 3 * 3600 {
                    windows[i].end = max(windows[i].end, bound.end)
                }
            }
        }
        // The route can rule out a mapped closure outside its conservative
        // window only if every published boundary is accounted for.
        windows[0].hasUncoveredTimes = published.contains { $0.start < windows[0].start }
        let lastIndex = windows.count - 1
        if published.contains(where: { $0.end > windows[lastIndex].end }) {
            windows[lastIndex].hasUncoveredTimes = true
        }
        return windows
    }

    /// Accepts epoch-millisecond values only within a plausible range for a
    /// traffic notice (2020 through two years from now).
    static func sanitizedDate(_ milliseconds: Double?) -> Date? {
        guard let milliseconds else { return nil }
        let date = Date(timeIntervalSince1970: milliseconds / 1000)
        let lowerBound = Date(timeIntervalSince1970: 1_577_836_800)   // 2020-01-01
        let upperBound = Date.now.addingTimeInterval(2 * 365 * 24 * 3600)
        guard date >= lowerBound, date <= upperBound else { return nil }
        return date
    }
}
