import Foundation

/// Decides whether two closures describe the same physical occurrence.
///
/// The planned feed, the real-time feed and the on-device archive use
/// different identifiers for the same closure, so cross-feed reconciliation
/// goes through this single definition; if the criteria diverge, merged rows
/// duplicate or overwrite each other.
nonisolated enum ClosureMatching {
    struct ScheduleSlice: Identifiable, Sendable {
        let start: Date
        let end: Date
        let closures: [RoadClosure]

        var id: Date { start }
    }

    /// Partition at each start and end. Each slice contains exactly the
    /// closures that overlap it, with gaps left out of the schedule.
    static func scheduleSlices(_ closures: [RoadClosure], direction: Direction, now: Date) -> [ScheduleSlice] {
        let scheduled = closures.filter {
            $0.matches(direction: direction) && $0.evidence != .realtime
                && $0.hasUnpublishedEnd != true && $0.start < $0.end && $0.end > now
        }
        let bounds = Set(scheduled.flatMap { [$0.start, $0.end] }).sorted()
        return zip(bounds, bounds.dropFirst()).compactMap { start, end in
            guard end > now else { return nil }
            let active = scheduled.filter { $0.start < end && $0.end > start }
            guard !active.isEmpty else { return nil }
            return .init(start: start, end: end, closures: active)
        }
    }

    static func sameOccurrence(_ lhs: RoadClosure, _ rhs: RoadClosure) -> Bool {
        guard lhs.kind == rhs.kind,
              lhs.lowerExit == rhs.lowerExit,
              lhs.upperExit == rhs.upperExit,
              sameRampImpact(lhs, rhs),
              lhs.affectsBothDirections == rhs.affectsBothDirections,
              lhs.affectsBothDirections || lhs.direction == rhs.direction
        else { return false }
        // Repeated nightly closures share the same places without overlapping
        // in time; the planned and live versions of one occurrence do overlap.
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
}
