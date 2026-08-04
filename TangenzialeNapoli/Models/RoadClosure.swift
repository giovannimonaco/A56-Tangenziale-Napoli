//
//  RoadClosure.swift
//  TangenzialeNapoli
//
//  The core domain model: one planned closure on the A56.
//

import Foundation

/// What a closure means to a driver — the single most important distinction in
/// the app. Either the road ahead is blocked, or only some ramps are closed.
nonisolated enum ClosureKind: Hashable, Sendable {
    /// The carriageway itself is closed: you cannot drive through this stretch.
    case roadBlocked
    /// The carriageway is open, but one or more ramps (entrances/exits) are
    /// closed at a single exit.
    case rampsClosed
}

/// How directly the displayed closure is supported by the two official feeds.
nonisolated enum ClosureEvidence: String, Codable, Hashable, Sendable {
    /// Present in the official forward-looking schedule.
    case scheduled
    /// Present only in the official live feed; its activation time can be less
    /// precise than a scheduled window.
    case realtime
    /// The scheduled occurrence is also present in the official live feed.
    case realtimeConfirmed
}

/// A single planned closure (chiusura programmata) on the A56.
///
/// Everything the UI needs is kept here; `sourceText` preserves the original
/// notice so a displayed closure can always be checked against its source.
nonisolated struct RoadClosure: Identifiable, Codable, Hashable, Sendable {
    /// Stable identifier. For live data it is derived from the official event
    /// id (`c_ele`) plus the day, so the same notice keeps the same id.
    let id: String

    /// Start and end of the closure as full date-times. Night closures cross
    /// midnight, so `end` may fall on the day after `start`.
    let start: Date
    let end: Date

    /// Carriageway / travel direction affected.
    let direction: Direction

    /// `true` when the closure affects both carriageways (official "in entrambe
    /// le direzioni"); such closures appear under either direction filter.
    let affectsBothDirections: Bool

    /// Endpoints of the closed stretch (exit numbers). Order follows travel
    /// direction; use `lowerExit` / `upperExit` for geographic ordering.
    let fromExit: Int
    let toExit: Int

    /// Affected entrances/exits along the stretch.
    let rampImpacts: [ClosureRampImpact]

    /// Why the closure is in place, e.g. "Lavori di pavimentazione".
    let reason: String

    let severity: Severity

    /// Suggested alternative exits to use instead (exit numbers).
    let suggestedAlternatives: [Int]

    /// Structured detour hints parsed from the notice text. Optional so
    /// archives saved by older builds still decode.
    let alternativeSuggestions: [AlternativeSuggestion]?

    /// `true` when the whole carriageway segment is closed (not just ramps).
    let isFullClosure: Bool

    /// The original official notice text, kept verbatim for auditing.
    let sourceText: String

    /// Optional for backward compatibility with archives saved by older builds.
    let evidence: ClosureEvidence?

    init(
        id: String = UUID().uuidString,
        start: Date,
        end: Date,
        direction: Direction,
        affectsBothDirections: Bool = false,
        fromExit: Int,
        toExit: Int,
        rampImpacts: [ClosureRampImpact] = [],
        reason: String,
        severity: Severity? = nil,
        suggestedAlternatives: [Int] = [],
        alternativeSuggestions: [AlternativeSuggestion]? = nil,
        isFullClosure: Bool = false,
        sourceText: String = "",
        evidence: ClosureEvidence? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.direction = direction
        self.affectsBothDirections = affectsBothDirections
        self.fromExit = fromExit
        self.toExit = toExit
        self.rampImpacts = rampImpacts
        self.reason = reason
        // Severity is derived from the closure's facts by default (see
        // `Severity.derived`), but callers can supply an explicit value.
        self.severity = severity ?? Severity.derived(
            isFullClosure: isFullClosure,
            spanExits: abs(toExit - fromExit),
            closedRampCount: rampImpacts.filter(\.isClosed).count,
            reason: reason,
            noticeText: sourceText
        )
        self.suggestedAlternatives = suggestedAlternatives
        self.alternativeSuggestions = alternativeSuggestions
        self.isFullClosure = isFullClosure
        self.sourceText = sourceText
        self.evidence = evidence
    }

    // MARK: - Derived helpers

    /// Lower of the two endpoint exit numbers (top of the map).
    var lowerExit: Int { min(fromExit, toExit) }
    /// Upper of the two endpoint exit numbers (bottom of the map).
    var upperExit: Int { max(fromExit, toExit) }

    /// Whether a given exit number lies within the closed stretch.
    func contains(exit number: Int) -> Bool {
        (lowerExit...upperExit).contains(number)
    }

    /// The calendar day the closure starts on. Used to bucket closures into
    /// Today / Tomorrow / Next days on the home screen.
    var startDay: Date {
        Calendar.current.startOfDay(for: start)
    }

    /// Calendar rows in which this closure must appear in the scheduled view.
    /// An overnight closure belongs to the evening on which it starts, while a
    /// genuinely continuous closure is repeated on every affected row so the
    /// driver never has to cross-reference it with that day's other notices.
    func scheduleDays(notBefore reference: Date, calendar: Calendar = .current) -> [Date] {
        guard end > reference else { return [] }

        let earliest = max(calendar.startOfDay(for: start), calendar.startOfDay(for: reference))
        var latest = calendar.startOfDay(for: end)
        let endsInMorning = calendar.component(.hour, from: end) <= 12
        if latest > calendar.startOfDay(for: start), endsInMorning,
           let previous = calendar.date(byAdding: .day, value: -1, to: latest) {
            latest = previous
        }
        guard earliest <= latest else { return [] }

        var days: [Date] = []
        var day = earliest
        while day <= latest {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// `true` when the closure is a single-ramp / single-exit event.
    var isRampOnly: Bool { !isFullClosure && lowerExit == upperExit }

    /// Whether this closure is relevant to a driver heading in `direction`.
    /// "Both directions" closures match either.
    func matches(direction: Direction) -> Bool {
        affectsBothDirections || self.direction == direction
    }

    // MARK: - Driver-facing model

    /// The one distinction a driver cares about first: is the road blocked, or
    /// are only ramps closed?
    var kind: ClosureKind { isFullClosure ? .roadBlocked : .rampsClosed }

    var closedRamps: [ClosureRampImpact] { rampImpacts.filter(\.isClosed) }
    var closedEntrances: [ClosureRampImpact] { closedRamps.filter { $0.kind == .entrance } }
    var closedExits: [ClosureRampImpact] { closedRamps.filter { $0.kind == .exit } }

    /// Closed ramps that are relevant while displaying one carriageway.
    /// A notice marked "both directions" applies to either map even though the
    /// raw feed gives its single ramp impact a fallback direction.
    func closedRamps(for direction: Direction) -> [ClosureRampImpact] {
        closedRamps.filter { affectsBothDirections || $0.direction == direction }
    }

    /// For a ramp-only closure, the exit the ramps belong to.
    var rampExitNumber: Int { lowerExit }

    /// The published "leave the road here" exit for a driver heading in
    /// `direction`, if the notice states one. Re-entry suggestions and hints
    /// for the other carriageway are excluded on purpose: presenting one of
    /// those as "exit here" would send the driver the wrong way.
    func recommendedExitBefore(for direction: Direction) -> Int? {
        alternativeSuggestions?.first {
            $0.kind == .exitBefore && ($0.direction == nil || $0.direction == direction)
        }?.exitNumber
    }

    /// Big headline for a card, in driver language.
    var headline: String {
        switch kind {
        case .roadBlocked:
            return "Strada chiusa"
        case .rampsClosed:
            let hasEntrance = !closedEntrances.isEmpty
            let hasExit = !closedExits.isEmpty
            switch (hasEntrance, hasExit) {
            case (true, true):  return "Entrata e uscita chiuse"
            case (true, false): return "Entrata chiusa"
            default:            return "Uscita chiusa"
            }
        }
    }

    /// Copy while changing only the source evidence. Used when the live feed
    /// confirms a scheduled occurrence without sacrificing its exact window.
    func withEvidence(_ evidence: ClosureEvidence) -> RoadClosure {
        RoadClosure(
            id: id,
            start: start,
            end: end,
            direction: direction,
            affectsBothDirections: affectsBothDirections,
            fromExit: fromExit,
            toExit: toExit,
            rampImpacts: rampImpacts,
            reason: reason,
            severity: severity,
            suggestedAlternatives: suggestedAlternatives,
            alternativeSuggestions: alternativeSuggestions,
            isFullClosure: isFullClosure,
            sourceText: sourceText,
            evidence: evidence
        )
    }

    /// Copy with the window truncated at `date`. Used when the live feed stops
    /// reporting a closure it previously published.
    func ended(at date: Date) -> RoadClosure {
        RoadClosure(
            id: id,
            start: start,
            end: max(date, start.addingTimeInterval(60)),
            direction: direction,
            affectsBothDirections: affectsBothDirections,
            fromExit: fromExit,
            toExit: toExit,
            rampImpacts: rampImpacts,
            reason: reason,
            severity: severity,
            suggestedAlternatives: suggestedAlternatives,
            alternativeSuggestions: alternativeSuggestions,
            isFullClosure: isFullClosure,
            sourceText: sourceText,
            evidence: evidence
        )
    }
}
