import Foundation

nonisolated struct ArchivedClosures: Codable, Sendable {
    var schemaVersion: Int?
    var lastFetchedAt: Date
    var closures: [RoadClosure]
}

/// Rolling on-device archive of closures seen across fetches. Keeps the last
/// N days (user-configurable) so closures stay available after they drop from
/// the live feed or when offline.
///
/// An actor, so concurrent refreshes cannot interleave their read-modify-write
/// cycles.
actor ClosureArchive {
    private static let currentSchemaVersion = 3
    private static let fileName = "a56_archive.json"

    static let retentionKey = "archiveRetentionDays"
    static let defaultRetentionDays = 10

    /// How long closures are kept after they end (from the in-app setting).
    private var retention: TimeInterval {
        let days = UserDefaults.standard.object(forKey: Self.retentionKey) as? Int ?? Self.defaultRetentionDays
        return TimeInterval(min(60, max(1, days))) * 24 * 60 * 60
    }

    /// Lives in Application Support, not Caches: the archive is the only record
    /// of closures that already started (the planned feed is forward-only), and
    /// the system purges Caches under storage pressure.
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    private static func defaultFileURL() -> URL {
        let manager = FileManager.default
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? manager.createDirectory(at: support, withIntermediateDirectories: true)
        let url = support.appendingPathComponent(fileName)

        // One-time move of archives written by builds that used Caches.
        let legacy = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        if !manager.fileExists(atPath: url.path), manager.fileExists(atPath: legacy.path) {
            try? manager.moveItem(at: legacy, to: url)
        }
        return url
    }

    func load() -> ArchivedClosures? {
        guard let data = try? Data(contentsOf: fileURL),
              var payload = try? JSONDecoder().decode(ArchivedClosures.self, from: data)
        else { return nil }

        // Version 2 inserted the real Italia 90 line point between Fuorigrotta
        // and Agnano. Shift the old schematic positions once so saved history
        // still refers to the same physical places.
        let version = payload.schemaVersion ?? 1
        if version < 2 {
            payload.closures = payload.closures.map(migrateFromSchema1)
        }
        for index in payload.closures.indices {
            payload.closures[index].coverArchivedSchedule()
        }
        // Older archives may contain exit-only notices for an entrance-only
        // junction. Preserve mixed notices with a valid entrance closure.
        payload.closures.removeAll {
            $0.isRampOnly && $0.closedRamps.isEmpty
                && $0.rampImpacts.contains { $0.isClosed && !$0.existsAtInterchange }
        }
        // Version 3 only retains structured notices; re-encoding removes
        // original text saved by older builds.
        if version < Self.currentSchemaVersion {
            payload.schemaVersion = Self.currentSchemaVersion
            save(payload.closures, lastFetchedAt: payload.lastFetchedAt)
            AppLog.log("archive migrated to schema \(Self.currentSchemaVersion)", "arch")
        }
        return payload
    }

    func snapshot(at now: Date) -> ArchivedClosures? {
        guard var stored = load() else { return nil }
        stored.closures = prune(stored.closures, now: now)
        return stored
    }

    func clear() throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // Nothing is stored yet.
        }
    }

    /// Merge `fetched` into the archive and persist.
    ///
    /// The official feed is forward-only (a closure disappears once it starts),
    /// so a previously-seen closure missing from `fetched` is kept if it has
    /// already started: that's a feed prune, and it may still be active. A
    /// missing future row is treated as cancelled only when the planned feed
    /// was fully available and mapped. A live-feed row that is active but no
    /// longer published is closed at "now" when the live feed was fully
    /// readable (works finished early). Entries older than the retention are
    /// pruned.
    @discardableResult
    func record(
        _ fetched: [RoadClosure],
        now: Date,
        canInferCancellations: Bool = true,
        canRevalidateActive: Bool = false
    ) -> [RoadClosure] {
        let fetchedIDs = Set(fetched.map(\.id))
        let existing = load()?.closures ?? []
        var merged: [RoadClosure] = []
        var retainedMissing = 0
        var revalidated = 0

        for old in existing where !fetchedIDs.contains(old.id) {
            guard old.start <= now || !canInferCancellations else {
                // Still in the future but gone from a fully-mapped planned
                // feed: cancelled.
                continue
            }
            if canRevalidateActive,
               old.evidence == .realtime || old.evidence == .realtimeConfirmed,
               old.start <= now, old.end > now,
               !fetched.contains(where: {
                   $0.evidence != .scheduled && $0.start <= now && ClosureMatching.sameOccurrence($0, old)
               }) {
                // Born from the live feed, would still be active, but the
                // (fully readable) live feed no longer reports it: over.
                let endWithoutLive = max(now, old.scheduledEnd ?? (old.evidence == .realtimeConfirmed ? old.end : now))
                merged.append(old.ended(at: min(old.end, endWithoutLive)))
                revalidated += 1
            } else {
                merged.append(old)
                retainedMissing += 1
            }
        }
        for fresh in fetched {
            if let previous = existing.first(where: {
                $0.id == fresh.id && $0.start <= now && $0.end > now && ClosureMatching.sameOccurrence($0, fresh)
            }), fresh.start <= now, fresh.evidence == .realtime {
                merged.append(reconcile(previous, with: fresh))
            } else if let previous = existing.first(where: { $0.id == fresh.id && $0.hasUnpublishedEnd == true }),
                      fresh.evidence == .scheduled, !canRevalidateActive {
                merged.append(previous)
            } else if fresh.start <= now, fresh.end > now, fresh.evidence == .realtime {
                let currentPlanned = merged.indices.filter {
                    (merged[$0].evidence == .scheduled || merged[$0].evidence == .realtimeConfirmed)
                        && merged[$0].start <= now && merged[$0].end > now
                        && ClosureMatching.sameOccurrence(merged[$0], fresh)
                }
                if currentPlanned.count == 1, let index = currentPlanned.first {
                    merged[index] = merged[index].confirmed(by: fresh)
                } else {
                    merged.append(fresh)
                }
            } else {
                merged.append(fresh)
            }
        }

        let pruned = prune(merged, now: now)
        save(pruned, lastFetchedAt: now)
        AppLog.log(
            "record: fetched=\(fetched.count) archived=\(existing.count) retainedMissing=\(retainedMissing) revalidated=\(revalidated) inferCancellations=\(canInferCancellations) -> merged=\(pruned.count)",
            "arch"
        )
        return pruned
    }

    /// Re-apply the (possibly changed) retention to the stored archive without
    /// re-fetching; used when the user changes the duration in-app.
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
            alternativeSuggestions: fresh.alternativeSuggestions ?? stored.alternativeSuggestions,
            isFullClosure: fresh.isFullClosure,
            evidence: fresh.evidence,
            reportedWindow: fresh.reportedWindow,
            hasUnpublishedEnd: fresh.hasUnpublishedEnd,
            scheduledEnd: fresh.scheduledEnd
        )
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
                    exitNumber: shifted($0.exitNumber),
                    kind: $0.kind,
                    direction: $0.direction,
                    isClosed: $0.isClosed
                )
            },
            reason: old.reason,
            severity: old.severity,
            suggestedAlternatives: old.suggestedAlternatives.map(shifted),
            alternativeSuggestions: nil,
            isFullClosure: old.isFullClosure,
            evidence: old.evidence,
            reportedWindow: old.reportedWindow,
            hasUnpublishedEnd: old.hasUnpublishedEnd,
            scheduledEnd: old.scheduledEnd
        )
    }

    private func save(_ closures: [RoadClosure], lastFetchedAt: Date) {
        let payload = ArchivedClosures(
            schemaVersion: Self.currentSchemaVersion,
            lastFetchedAt: lastFetchedAt,
            closures: closures
        )
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            #if os(iOS)
            var localURL = fileURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try localURL.setResourceValues(resourceValues)
            #endif
        } catch {
            AppLog.log("archive save failed: \(error.localizedDescription)", "arch")
        }
    }
}
