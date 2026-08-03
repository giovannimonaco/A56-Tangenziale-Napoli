//
//  ClosureArchive.swift
//  TangenzialeNapoli
//
//  Rolling on-device archive. Accumulates closures seen across fetches and
//  keeps the last N days (user-configurable), so recently-seen closures stay
//  available even after they drop from the live feed or when offline.
//

import Foundation

struct ArchivedClosures: Codable, Sendable {
    var schemaVersion: Int?
    var lastFetchedAt: Date
    var closures: [RoadClosure]
}

struct ClosureArchive {
    private static let currentSchemaVersion = 2

    /// UserDefaults key and default for the in-app retention setting.
    static let retentionKey = "archiveRetentionDays"
    static let defaultRetentionDays = 10

    /// How long to keep closures after they end — read from the in-app setting.
    private var retention: TimeInterval {
        let days = UserDefaults.standard.object(forKey: Self.retentionKey) as? Int ?? Self.defaultRetentionDays
        return TimeInterval(max(1, days) * 24 * 60 * 60)
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("a56_archive.json")
    }()

    func load() -> ArchivedClosures? {
        guard let data = try? Data(contentsOf: fileURL),
              var payload = try? JSONDecoder().decode(ArchivedClosures.self, from: data)
        else { return nil }

        // Version 2 inserted the real Italia 90 line point between Fuorigrotta
        // and Agnano. Shift the old schematic positions once so saved history
        // still refers to the same physical places.
        if (payload.schemaVersion ?? 1) < Self.currentSchemaVersion {
            payload.closures = payload.closures.map(migrateFromSchema1)
            payload.schemaVersion = Self.currentSchemaVersion
            save(payload.closures, lastFetchedAt: payload.lastFetchedAt)
            AppLog.log("archive migrated to schema \(Self.currentSchemaVersion)", "arch")
        }
        return payload
    }

    /// Merge `fetched` into the archive and persist.
    ///
    /// The official feed is forward-only (a closure disappears once it starts),
    /// so a previously-seen closure missing from `fetched` is kept if it has
    /// already started — that's a feed prune, and it may still be active. A
    /// missing future row is treated as cancelled only when the planned feed
    /// was fully available and mapped; otherwise it is retained. Entries older
    /// than the retention are pruned.
    @discardableResult
    func record(
        _ fetched: [RoadClosure],
        now: Date,
        canInferCancellations: Bool = true
    ) -> [RoadClosure] {
        let fetchedIDs = Set(fetched.map(\.id))
        let existing = load()?.closures ?? []
        var merged: [RoadClosure] = []
        var retainedMissing = 0

        for old in existing where !fetchedIDs.contains(old.id) {
            if old.start <= now || !canInferCancellations {
                // Already started may have been pruned by the forward feed.
                // Future rows are retained whenever the planned feed was not
                // fully available/mappable, because absence is then ambiguous.
                merged.append(old)
                retainedMissing += 1
            }
            // else: still in the future but gone → treat as cancelled → drop
        }
        for fresh in fetched {
            if let exactIndex = merged.firstIndex(where: { $0.id == fresh.id }) {
                merged[exactIndex] = fresh
            } else if let equivalentIndex = merged.firstIndex(where: { sameOccurrence($0, fresh) }) {
                // The planned and real-time feeds use different ids for the same
                // closure. Keep one row and preserve the original start/id.
                merged[equivalentIndex] = reconcile(merged[equivalentIndex], with: fresh)
            } else {
                merged.append(fresh)
            }
        }

        let pruned = prune(merged, now: now)
        save(pruned, lastFetchedAt: now)
        AppLog.log("record: fetched=\(fetched.count) archived=\(existing.count) retainedMissing=\(retainedMissing) inferCancellations=\(canInferCancellations) → merged=\(pruned.count)", "arch")
        return pruned
    }

    /// Re-apply the (possibly changed) retention to the stored archive without
    /// re-fetching — used when the user changes the duration in-app.
    @discardableResult
    func reprune(now: Date) -> [RoadClosure] {
        guard let stored = load() else { return [] }
        let kept = prune(stored.closures, now: now)
        save(kept, lastFetchedAt: stored.lastFetchedAt)
        return kept
    }

    // MARK: - Helpers

    private func prune(_ closures: [RoadClosure], now: Date) -> [RoadClosure] {
        let cutoff = now.addingTimeInterval(-retention)
        return closures.filter { $0.end >= cutoff }.sorted { $0.start < $1.start }
    }

    private func sameOccurrence(_ lhs: RoadClosure, _ rhs: RoadClosure) -> Bool {
        guard lhs.kind == rhs.kind,
              lhs.lowerExit == rhs.lowerExit,
              lhs.upperExit == rhs.upperExit,
              sameRampImpact(lhs, rhs),
              lhs.affectsBothDirections == rhs.affectsBothDirections,
              lhs.affectsBothDirections || lhs.direction == rhs.direction
        else { return false }
        // Repeated nightly closures have identical places but do not overlap,
        // while the planned and active versions of one occurrence do.
        return lhs.start < rhs.end && rhs.start < lhs.end
    }

    private func sameRampImpact(_ lhs: RoadClosure, _ rhs: RoadClosure) -> Bool {
        guard lhs.kind == .rampsClosed else { return true }
        let lhsSignature = Set(lhs.closedRamps.map {
            "\($0.exitNumber)#\($0.kind.rawValue)"
        })
        let rhsSignature = Set(rhs.closedRamps.map {
            "\($0.exitNumber)#\($0.kind.rawValue)"
        })
        return lhsSignature == rhsSignature
    }

    private func reconcile(_ stored: RoadClosure, with fresh: RoadClosure) -> RoadClosure {
        RoadClosure(
            id: stored.id,
            start: min(stored.start, fresh.start),
            end: fresh.end,
            direction: fresh.direction,
            affectsBothDirections: fresh.affectsBothDirections,
            fromExit: fresh.fromExit,
            toExit: fresh.toExit,
            rampImpacts: fresh.rampImpacts,
            reason: fresh.reason,
            severity: fresh.severity,
            suggestedAlternatives: fresh.suggestedAlternatives,
            isFullClosure: fresh.isFullClosure,
            sourceText: fresh.sourceText,
            evidence: reconciledEvidence(stored.evidence, fresh.evidence)
        )
    }

    private func reconciledEvidence(
        _ stored: ClosureEvidence?,
        _ fresh: ClosureEvidence?
    ) -> ClosureEvidence? {
        if fresh == .realtimeConfirmed || stored == .realtimeConfirmed {
            return .realtimeConfirmed
        }
        if (fresh == .realtime && stored == .scheduled)
            || (fresh == .scheduled && stored == .realtime) {
            return .realtimeConfirmed
        }
        return fresh ?? stored
    }

    private func migrateFromSchema1(_ old: RoadClosure) -> RoadClosure {
        func shifted(_ position: Int) -> Int {
            position >= 11 ? position + 1 : position
        }

        return RoadClosure(
            id: old.id,
            start: old.start,
            end: old.end,
            direction: old.direction,
            affectsBothDirections: old.affectsBothDirections,
            fromExit: shifted(old.fromExit),
            toExit: shifted(old.toExit),
            rampImpacts: old.rampImpacts.map {
                ClosureRampImpact(
                    id: $0.id,
                    exitNumber: shifted($0.exitNumber),
                    kind: $0.kind,
                    direction: $0.direction,
                    isClosed: $0.isClosed
                )
            },
            reason: old.reason,
            severity: old.severity,
            suggestedAlternatives: old.suggestedAlternatives.map(shifted),
            isFullClosure: old.isFullClosure,
            sourceText: old.sourceText,
            evidence: old.evidence
        )
    }

    private func save(_ closures: [RoadClosure], lastFetchedAt: Date) {
        let payload = ArchivedClosures(
            schemaVersion: Self.currentSchemaVersion,
            lastFetchedAt: lastFetchedAt,
            closures: closures
        )
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
