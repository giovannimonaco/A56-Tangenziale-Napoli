import Foundation
import Darwin
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Portable widget state. A successful request never implies that the road is
/// open: the feeds describe closures, not all traffic conditions.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    static let freshnessLimit: TimeInterval = 5 * 60
    static let refreshInterval: TimeInterval = 30 * 60

    let fetchedAt: Date?
    let closures: [RoadClosure]
    let isComplete: Bool
    var isOffline = false
    /// Orders overlapping fetches by their start, not by a late completion.
    var requestStartedAt: Date? = nil

    static let unavailable = WidgetSnapshot(fetchedAt: nil, closures: [], isComplete: false)

    enum Status: Equatable {
        case current, partial, stale, offline, unavailable

        var label: String {
            switch self {
            case .current: "Avvisi aggiornati"
            case .partial: "Avvisi incompleti"
            case .stale: "Da aggiornare"
            case .offline: "Avvisi salvati"
            case .unavailable: "Avvisi indisponibili"
            }
        }
    }

    func status(at date: Date) -> Status {
        guard let fetchedAt else { return .unavailable }
        if isOffline { return .offline }
        let age = date.timeIntervalSince(fetchedAt)
        guard age >= 0, age < Self.freshnessLimit else { return .stale }
        return isComplete ? .current : .partial
    }

    struct DirectionSummary: Sendable {
        let direction: Direction
        let activeCount: Int
        let nextClosure: RoadClosure?
    }

    func summary(for direction: Direction, at date: Date) -> DirectionSummary {
        let relevant = closures.filter { $0.matches(direction: direction) && $0.end > date }
        return DirectionSummary(
            direction: direction,
            activeCount: relevant.filter { $0.start <= date }.count,
            nextClosure: relevant.filter { $0.start > date }.min {
                ($0.start, $0.id) < ($1.start, $1.id)
            }
        )
    }

    /// Pre-render expiry and known closure transitions even if iOS postpones
    /// the next network refresh. No future entry extends data freshness.
    func timelineDates(from date: Date) -> [Date] {
        let horizon = date.addingTimeInterval(24 * 60 * 60)
        var dates: Set<Date> = [date]
        if let fetchedAt {
            let expiry = fetchedAt.addingTimeInterval(Self.freshnessLimit)
            if expiry > date { dates.insert(expiry) }
        }
        for closure in closures {
            for boundary in [closure.start, closure.end] where boundary > date && boundary <= horizon {
                dates.insert(boundary)
            }
        }
        var limited = Array(dates.sorted().prefix(48))
        // A busy feed must never crowd out the expiry entry: otherwise a
        // postponed reload could leave a fresh-looking snapshot on screen.
        if let fetchedAt {
            let expiry = fetchedAt.addingTimeInterval(Self.freshnessLimit)
            if expiry > date, !limited.contains(expiry) {
                limited[limited.count - 1] = expiry
                limited.sort()
            }
        }
        return limited
    }
}

/// The app and extension exchange only current/future notices in an App Group.
/// A process-local actor serializes callers; flock additionally serializes the
/// compare-and-replace transaction across processes and independent instances.
actor WidgetSnapshotStore {
    nonisolated static let appGroupIdentifier = "group.com.giovannimonaco.TangenzialeNapoli"
    nonisolated static let widgetKind = "A56ClosuresWidget"
    static let shared = WidgetSnapshotStore()

    private let directory: URL
    private let legacyDirectory: URL?
    private let requestReload: @Sendable () async -> Void
    private let clock: @Sendable () -> Date

    /// Explicit directories keep tests independent of entitlements/user data.
    init(
        directory: URL? = nil,
        legacyDirectory: URL? = nil,
        clock: @escaping @Sendable () -> Date = { Date() },
        requestReload: @escaping @Sendable () async -> Void = {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
            #endif
        }
    ) {
        if let directory {
            self.directory = directory
            self.legacyDirectory = legacyDirectory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0]
            #if os(iOS)
            let group = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            )
            #else
            let group: URL? = nil
            #endif
            // With missing provisioning the widget still works independently;
            // sharing becomes available once both signed targets have the group.
            self.directory = (group?.appendingPathComponent("Library/Application Support") ?? support)
                .appendingPathComponent("A56Widget", isDirectory: true)
            self.legacyDirectory = support
            if group == nil { AppLog.log("App Group unavailable; widget cache is process-local", "widget") }
        }
        self.requestReload = requestReload
        self.clock = clock
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        WidgetSnapshotDisk.excludeFromBackup(self.directory)
    }

    func cached() -> WidgetSnapshot {
        do {
            return try transaction { disk in
                try disk.migrateLegacy(from: legacyDirectory)
                return disk.read() ?? .unavailable
            }
        } catch {
            AppLog.log("widget cache read failed: \(error.localizedDescription)", "widget")
            return .unavailable
        }
    }

    /// Called only after the app has finished a genuine successful refresh.
    /// Reload is requested after the shared atomic write, never before it.
    @discardableResult
    func publishFromApp(_ snapshot: WidgetSnapshot) async -> Bool {
        let result = persist(snapshot)
        guard result.didWrite else { return false }
        AppLog.log("published shared snapshot \(String(describing: snapshot.fetchedAt)); requesting widget reload", "widget")
        await requestReload()
        return true
    }

    /// A reload following an app refresh must not immediately fetch again.
    /// Partial responses are reusable too: their quality is preserved verbatim.
    func snapshotForTimeline(
        using provider: any ClosureProvider = LiveClosureProvider(), at date: Date? = nil
    ) async -> WidgetSnapshot {
        let snapshot = cached()
        let reference = date ?? clock()
        if snapshot.status(at: reference) == .current || snapshot.status(at: reference) == .partial {
            AppLog.log("reusing fresh shared snapshot \(String(describing: snapshot.fetchedAt)); no network", "widget")
            return snapshot
        }
        return await refresh(using: provider)
    }

    /// Always fetches. WidgetKit uses snapshotForTimeline to coalesce app reloads;
    /// autonomous periodic refresh still uses the original live provider.
    func refresh(using provider: any ClosureProvider = LiveClosureProvider()) async -> WidgetSnapshot {
        let startedAt = clock()
        do {
            let result = try await provider.fetchClosures()
            try Task.checkCancellation()
            let latest = cached()
            if WidgetSnapshotDisk.hasPlausibleClock(latest, at: clock()),
               let revision = latest.requestStartedAt ?? latest.fetchedAt, revision > startedAt {
                return latest
            }

            // Reuse the existing archive merge rules without a second persistent
            // widget archive or cross-process actor assumptions. Each refresh has
            // a unique scratch archive seeded from the latest shared snapshot.
            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("A56WidgetMerge-\(UUID())", isDirectory: true)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratch) }
            let archive = ClosureArchive(fileURL: scratch.appendingPathComponent("archive.json"))
            if WidgetSnapshotDisk.hasPlausibleClock(latest, at: clock()),
               let fetchedAt = latest.fetchedAt {
                await archive.record(latest.closures, now: fetchedAt, canInferCancellations: false)
            }
            let now = clock()
            let closures = await archive.record(
                result.closures, now: now,
                canInferCancellations: result.canInferCancellations,
                canRevalidateActive: result.canRevalidateActive
            )
            try Task.checkCancellation()
            let snapshot = WidgetSnapshot(
                fetchedAt: now, closures: closures,
                isComplete: result.quality?.isFullyVerified == true,
                requestStartedAt: startedAt
            )
            return persist(snapshot).snapshot
        } catch {
            var snapshot = cached()
            // An app update during an older failed widget fetch remains current.
            if WidgetSnapshotDisk.hasPlausibleClock(snapshot, at: clock()),
               let fetchedAt = snapshot.fetchedAt, fetchedAt >= startedAt { return snapshot }
            snapshot.isOffline = true
            return snapshot
        }
    }

    private func persist(_ candidate: WidgetSnapshot) -> (snapshot: WidgetSnapshot, didWrite: Bool) {
        do {
            return try transaction { disk in
                try disk.migrateLegacy(from: legacyDirectory)
                let current = disk.read()
                guard WidgetSnapshotDisk.shouldReplace(current, with: candidate, at: clock()) else {
                    return (current ?? .unavailable, false)
                }
                let snapshot = WidgetSnapshotDisk.relevant(candidate)
                try disk.write(snapshot)
                return (snapshot, true)
            }
        } catch {
            AppLog.log("widget cache publish failed: \(error.localizedDescription)", "widget")
            let previous = cached()
            // A storage failure must not hide a trustworthy response that can
            // still be displayed by this timeline. No app reload is requested.
            let display = WidgetSnapshotDisk.shouldReplace(previous, with: candidate, at: clock())
                ? WidgetSnapshotDisk.relevant(candidate) : previous
            return (display, false)
        }
    }

    private func transaction<T>(_ body: (WidgetSnapshotDisk) throws -> T) throws -> T {
        let disk = WidgetSnapshotDisk(directory: directory)
        let descriptor = open(disk.lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try body(disk)
    }
}

private nonisolated struct WidgetSnapshotDisk {
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("a56_widget_snapshot.json") }
    var lockURL: URL { directory.appendingPathComponent("a56_widget_snapshot.lock") }

    // A corrected system clock must not make a future-dated cache unbeatable.
    // Allow at most one minute of clock skew when ordering competing writers.
    static func hasPlausibleClock(_ snapshot: WidgetSnapshot, at now: Date) -> Bool {
        guard let fetchedAt = snapshot.fetchedAt, fetchedAt <= now.addingTimeInterval(60) else { return false }
        return (snapshot.requestStartedAt ?? fetchedAt) <= now.addingTimeInterval(60)
    }

    static func shouldReplace(_ current: WidgetSnapshot?, with candidate: WidgetSnapshot, at now: Date) -> Bool {
        guard let date = candidate.fetchedAt, hasPlausibleClock(candidate, at: now) else { return false }
        guard let current, let currentDate = current.fetchedAt,
              hasPlausibleClock(current, at: now) else { return true }
        return date > currentDate
            && (candidate.requestStartedAt ?? date) >= (current.requestStartedAt ?? currentDate)
    }

    func read() -> WidgetSnapshot? { Self.read(fileURL) }

    private static func read(_ url: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func relevant(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
        WidgetSnapshot(
            fetchedAt: snapshot.fetchedAt,
            closures: snapshot.closures.filter { $0.end > (snapshot.fetchedAt ?? .distantPast) },
            isComplete: snapshot.isComplete,
            requestStartedAt: snapshot.requestStartedAt
        )
    }

    func write(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
        Self.excludeFromBackup(fileURL)
    }

    /// Older private widget copies are imported once, with unknown-quality
    /// archives kept partial. Delete legacy files only after a valid copy exists.
    func migrateLegacy(from legacy: URL?) throws {
        guard let legacy, legacy.standardizedFileURL != directory.standardizedFileURL else { return }
        let oldSnapshot = legacy.appendingPathComponent("a56_widget_snapshot.json")
        let oldArchive = legacy.appendingPathComponent("a56_widget_archive.json")
        var candidates = [read(), Self.read(oldSnapshot)].compactMap { $0 }
        if let data = try? Data(contentsOf: oldArchive),
           let archive = try? JSONDecoder().decode(ArchivedClosures.self, from: data) {
            candidates.append(WidgetSnapshot(fetchedAt: archive.lastFetchedAt,
                                             closures: archive.closures, isComplete: false))
        }
        guard let newest = candidates.filter({ $0.fetchedAt != nil }).max(by: {
            $0.fetchedAt! < $1.fetchedAt!
        }) else { return }
        if read()?.fetchedAt != newest.fetchedAt { try write(Self.relevant(newest)) }
        try? FileManager.default.removeItem(at: oldSnapshot)
        try? FileManager.default.removeItem(at: oldArchive)
    }

    static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
