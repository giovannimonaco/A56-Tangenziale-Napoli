import Foundation

/// Decides whether two closures describe the same physical occurrence.
///
/// The planned feed, the real-time feed and the on-device archive use
/// different identifiers for the same closure, so cross-feed reconciliation
/// goes through this single definition; if the criteria diverge, merged rows
/// duplicate or overwrite each other.
nonisolated enum ClosureMatching {

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
