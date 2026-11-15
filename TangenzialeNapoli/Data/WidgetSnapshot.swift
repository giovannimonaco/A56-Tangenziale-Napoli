import Foundation

/// Portable widget state. A successful request never implies that the road is
/// open: the feeds describe closures, not all traffic conditions.
nonisolated struct WidgetSnapshot: Codable, Sendable {
    static let freshnessLimit: TimeInterval = 5 * 60
    static let refreshInterval: TimeInterval = 30 * 60

    let fetchedAt: Date?
    let closures: [RoadClosure]
    let isComplete: Bool
    var isOffline = false

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

/// Runs inside the extension, with its own archive and no dependency on the
/// containing app's lifecycle or location permission. Atomic files are private
/// to that extension; an App Group entitlement isn't needed.
actor WidgetSnapshotStore {
    static let shared = WidgetSnapshotStore()

    private let fileURL: URL
    private let archive: ClosureArchive

    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("a56_widget_snapshot.json")
        archive = ClosureArchive(fileURL: directory.appendingPathComponent("a56_widget_archive.json"))
    }

    func cached() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .unavailable }
        return snapshot
    }

    func refresh(using provider: any ClosureProvider = LiveClosureProvider()) async -> WidgetSnapshot {
        do {
            let result = try await provider.fetchClosures()
            try Task.checkCancellation()
            let now = Date()
            let closures = await archive.record(
                result.closures,
                now: now,
                canInferCancellations: result.canInferCancellations,
                canRevalidateActive: result.canRevalidateActive
            )
            let snapshot = WidgetSnapshot(
                fetchedAt: now,
                closures: closures,
                isComplete: result.quality?.isFullyVerified == true
            )
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: fileURL, options: .atomic)
                var url = fileURL
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? url.setResourceValues(values)
            }
            return snapshot
        } catch {
            var snapshot = cached()
            snapshot.isOffline = true
            return snapshot
        }
    }
}
