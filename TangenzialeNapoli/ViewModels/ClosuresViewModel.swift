import Foundation
import Observation

/// Loads closures (live feed -> last-good cache -> unavailable) and groups
/// them per direction.
@MainActor
@Observable
final class ClosuresViewModel {
    nonisolated static let freshnessLimit: TimeInterval = 5 * 60

    /// Where the currently displayed data came from.
    enum DataSource: Equatable {
        case live(Date, ClosureDataQuality) // fresh from the network
        case cache(Date)    // last good response, network unavailable
        case unavailable    // no trustworthy live or cached response

    }

    /// State for the status line. `partial` means the refresh succeeded but
    /// one feed or some rows could not be read; it must not look like the
    /// offline `cache` state, or users will retry a refresh that already
    /// worked.
    enum Freshness: Equatable {
        case fresh(Date)
        case partial(Date, ClosureDataQuality)
        case expired(Date)
        case cache(Date)
        case unavailable

        var limitationTitle: String? {
            switch self {
            case .fresh: nil
            case .partial(_, let quality):
                if !quality.realtimeFeedAvailable { "Tempo reale assente" }
                else if !quality.plannedFeedAvailable { "Programmazione assente" }
                else { "Avvisi incompleti" }
            case .expired: "Avvisi non aggiornati"
            case .cache: "Avvisi salvati"
            case .unavailable: "Avvisi indisponibili"
            }
        }

        var limitationDetail: String? {
            switch self {
            case .fresh:
                return nil
            case .partial(_, let quality):
                var details: [String] = []
                if !quality.realtimeFeedAvailable {
                    details.append("Mancano gli avvisi in tempo reale del gestore.")
                }
                if !quality.plannedFeedAvailable {
                    details.append("Mancano gli avvisi sulle chiusure programmate.")
                }
                if !quality.mappingIsComplete {
                    details.append("Alcuni avvisi sono incompleti.")
                }
                return details.joined(separator: " ")
            case .expired:
                return "Ricarica per aggiornare gli avvisi del gestore."
            case .cache:
                return "L’aggiornamento non è riuscito. Vedi gli ultimi avvisi salvati sul dispositivo."
            case .unavailable:
                return "Gli avvisi del gestore non sono disponibili e non ci sono avvisi salvati."
            }
        }

        func updateLabel(reference: Date) -> String {
            switch self {
            case .fresh(let date):
                return "Aggiornato \(ClosureFormat.updateTimeLabel(date, reference: reference))"
            case .partial(let date, _):
                let time = ClosureFormat.updateTimeLabel(date, reference: reference)
                return "\(limitationTitle ?? "Avvisi incompleti") · controllo \(time)"
            case .expired(let date):
                return "Avvisi non aggiornati · ultimo controllo \(ClosureFormat.updateTimeLabel(date, reference: reference))"
            case .cache(let date):
                return "Aggiornamento fallito · avvisi salvati \(ClosureFormat.updateTimeLabel(date, reference: reference))"
            case .unavailable:
                return "Avvisi del gestore indisponibili · nessun dato salvato"
            }
        }
    }

    var freshness: Freshness? {
        switch dataSource {
        case .live(let date, let quality):
            let age = now.timeIntervalSince(date)
            if age < 0 || age >= Self.freshnessLimit { return .expired(date) }
            return quality.isFullyVerified ? .fresh(date) : .partial(date, quality)
        case .cache(let date):
            return .cache(date)
        case .unavailable:
            return .unavailable
        case nil:
            return nil
        }
    }

    var dataNeedsVerification: Bool {
        if case .fresh = freshness { return false }
        return true
    }

    /// One day for one direction, split into road blocks and ramp closures.
    struct DirectionDay: Identifiable {
        let date: Date
        let label: String
        let roadBlocks: [RoadClosure]
        let rampClosures: [RoadClosure]
        var id: Date { date }
        var isEmpty: Bool { roadBlocks.isEmpty && rampClosures.isEmpty }
    }

    private let provider: ClosureProvider
    private let fallback: ClosureProvider
    private let archive: ClosureArchive
    private let clock: () -> Date
    private var lastAttemptAt: Date?

    private(set) var closures: [RoadClosure] = []
    /// Rolling ~10-day archive, for the history screen and the offline fallback.
    private(set) var archivedClosures: [RoadClosure] = []
    private(set) var isLoading = false
    private(set) var isClearingArchive = false
    private(set) var dataSource: DataSource?
    /// "Now" used to split active vs upcoming. Refreshed on load and by a timer.
    private(set) var now: Date
    /// When the live feed last loaded successfully (drives refresh-on-foreground).
    private(set) var lastLoadedAt: Date?

    /// Defaults to the live feed with an empty last resort: synthetic
    /// closures are reserved for previews and tests.
    init(
        provider: ClosureProvider? = nil,
        fallback: ClosureProvider? = nil,
        archive: ClosureArchive = ClosureArchive(),
        clock: @escaping () -> Date = { .now }
    ) {
        self.provider = provider ?? LiveClosureProvider()
        self.fallback = fallback ?? EmptyClosureProvider()
        self.archive = archive
        self.clock = clock
        self.now = clock()
    }

    func load() async {
        guard !isLoading, !isClearingArchive else {
            AppLog.log("load() ignored: refresh already in progress", "vm")
            return
        }
        isLoading = true
        refreshNow()
        lastAttemptAt = now
        AppLog.log("load() start, now=\(now.formatted(date: .abbreviated, time: .standard))", "vm")
        defer { isLoading = false; logSummary(); dumpClosures() }

        // Show the saved notices while the first network request is pending.
        if dataSource == nil, let stored = await archive.snapshot(at: now) {
            presentCache(stored)
        }

        // 1. Try the live feed.
        do {
            let result = try await provider.fetchClosures()
            let timestamp = clock()
            // The official feed only lists future windows: once a closure starts
            // it disappears from it. So the UI is driven by the rolling archive
            // (which retains closures seen while they were still upcoming), not
            // just this fetch; otherwise an active overnight closure checked
            // after midnight would show nothing.
            archivedClosures = await archive.record(
                result.closures,
                now: timestamp,
                canInferCancellations: result.canInferCancellations,
                canRevalidateActive: result.canRevalidateActive
            )
            closures = archivedClosures
            refreshNow()
            dataSource = .live(
                timestamp,
                result.quality ?? ClosureDataQuality(
                    plannedFeedAvailable: true,
                    realtimeFeedAvailable: true,
                    expectedRecords: result.closures.count,
                    mappedRecords: result.closures.count,
                    unresolvedRecords: [],
                    topologyIssues: []
                )
            )
            lastLoadedAt = timestamp
            AppLog.log("LIVE ok: closures=\(closures.count) archived=\(archivedClosures.count)", "vm")
            return
        } catch where Task.isCancelled {
            AppLog.log("LIVE cancelled", "vm")
            return
        } catch {
            AppLog.log("LIVE failed: \(error.localizedDescription)", "vm")
        }

        // 2. Fall back to the accumulated on-device archive (last good data).
        refreshNow()
        if let stored = await archive.snapshot(at: now) {
            presentCache(stored)
            AppLog.log("CACHE fallback: archived=\(closures.count)", "vm")
            return
        }
        if let lastLoadedAt {
            // A disk failure must not erase an already displayed snapshot.
            dataSource = .cache(lastLoadedAt)
            return
        }

        // 3. Last resort: an explicitly unavailable state, never fake events.
        closures = ((try? await fallback.fetchClosures())?.closures ?? []).sorted { $0.start < $1.start }
        archivedClosures = []
        dataSource = .unavailable
        AppLog.log("UNAVAILABLE fallback", "vm")
    }

    private func presentCache(_ stored: ArchivedClosures) {
        closures = stored.closures
        archivedClosures = stored.closures
        dataSource = .cache(stored.lastFetchedAt)
    }

    /// Per-closure dump, deduplicated by event, showing how each case got
    /// classified. The whole body is Debug-only: it walks every closure and
    /// builds strings, work Release builds should not pay for.
    private func dumpClosures() {
        #if DEBUG
        var seen = Set<String>()
        AppLog.log("===== A56 closures (\(closures.count) occurrences) =====", "dump")
        for c in closures {
            let eventID = String(c.id.prefix { $0 != "#" })
            guard seen.insert(eventID).inserted else { continue }
            let kind = c.kind == .roadBlocked ? "ROAD" : "ramp"
            let place = c.isRampOnly
                ? A56Line.interchangeLabel(for: c.fromExit)
                : "\(A56Line.driverLabel(for: c.fromExit)) to \(A56Line.driverLabel(for: c.toExit))"
            AppLog.log("\(kind) | \(c.headline) | \(c.direction.shortName) | \(place) | sev=\(c.severity.displayName) | reason=\(c.reason)", "dump")
        }
        #endif
    }

    /// Logs active/upcoming/past counts per direction after a load. Debug-only
    /// as well: `upcomingDays`/`pastDays` are the most expensive calls in the
    /// view model.
    private func logSummary() {
        #if DEBUG
        for dir in Direction.allCases {
            let active = activeClosures(for: dir).count
            let upcoming = upcomingDays(for: dir).reduce(0) { $0 + $1.roadBlocks.count + $1.rampClosures.count }
            let past = pastDays(for: dir).reduce(0) { $0 + $1.roadBlocks.count + $1.rampClosures.count }
            AppLog.log("\(dir.shortName): active=\(active) upcoming=\(upcoming) past=\(past)", "vm")
        }
        #endif
    }

    /// Re-evaluate "now" so the active/upcoming split stays correct while the
    /// app stays open (driven by a minute timer in the view).
    func refreshNow() { now = clock() }

    /// Called when the app returns to the foreground: re-fetch if the data is
    /// older than `maxAge`, otherwise just re-evaluate "now". Picks up closures
    /// added to the feed since the last load.
    func refreshIfStale(maxAge: TimeInterval = freshnessLimit) async {
        refreshNow()
        guard !isLoading else { AppLog.log("refreshIfStale: skip (loading)", "vm"); return }
        if let lastAttemptAt {
            let age = now.timeIntervalSince(lastAttemptAt)
            // Retry failed or partial requests on a later tick without
            // hitting the service on every foreground transition.
            let interval = dataNeedsVerification ? min(maxAge, 120) : maxAge
            if age >= 0, age < interval { return }
        }
        await load()
    }

    /// Re-apply the archive retention (no network) after the user changes the
    /// duration setting.
    func applyRetentionChange() {
        Task {
            archivedClosures = await archive.reprune(now: now)
            AppLog.log("retention applied, archived=\(archivedClosures.count)", "vm")
        }
    }

    @discardableResult
    func clearLocalArchive() async -> Bool {
        guard !isLoading, !isClearingArchive else { return false }
        isClearingArchive = true
        defer { isClearingArchive = false }
        do {
            try await archive.clear()
            archivedClosures = []
            return true
        } catch {
            AppLog.log("archive deletion failed: \(error.localizedDescription)", "arch")
            return false
        }
    }

    // MARK: - Direction-scoped grouping

    private var calendar: Calendar { ClosureFormat.calendar }

    /// Closures active at `now` for this direction. Shown even when they began
    /// before midnight, the common case for overnight (23:00–06:00) closures
    /// that would otherwise vanish in the early hours.
    func activeClosures(for direction: Direction) -> [RoadClosure] {
        closures
            .filter { $0.matches(direction: direction) && $0.start <= now && $0.end > now }
            .sorted { $0.start < $1.start }
    }

    /// Scheduled picture grouped by day. A continuous closure is included on
    /// every day it affects, alongside notices that start on that specific day.
    /// Today and Tomorrow remain visible even when empty.
    func upcomingDays(for direction: Direction) -> [DirectionDay] {
        let today = calendar.startOfDay(for: now)
        let relevant = closures.filter {
            $0.matches(direction: direction) && $0.end > now
        }

        var dayKeys = Set<Date>([today])
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
            dayKeys.insert(tomorrow)
        }
        for closure in relevant {
            dayKeys.formUnion(closure.scheduleDays(notBefore: now, calendar: calendar))
        }

        return dayKeys
            .filter { $0 >= today }
            .sorted()
            .map { day in
                let ofDay = relevant
                    .filter { $0.scheduleDays(notBefore: now, calendar: calendar).contains(day) }
                    .sorted { $0.start < $1.start }
                return DirectionDay(
                    date: day,
                    label: ClosureFormat.relativeDayName(day, reference: now),
                    roadBlocks: ofDay.filter { $0.kind == .roadBlocked },
                    rampClosures: ofDay.filter { $0.kind == .rampsClosed }
                )
            }
    }

    /// Closures relevant to a direction and not yet ended (used by the map).
    func closures(for direction: Direction) -> [RoadClosure] {
        closures.filter { $0.matches(direction: direction) && $0.end > now }
    }

    /// Past closures (already ended) for a direction, grouped by day, most
    /// recent first. The rolling ~10-day history kept on device.
    func pastDays(for direction: Direction) -> [DirectionDay] {
        let past = archivedClosures.filter { $0.matches(direction: direction) && $0.end <= now }
        let grouped = Dictionary(grouping: past) { calendar.startOfDay(for: $0.start) }
        return grouped.keys.sorted(by: >).map { day in
            let ofDay = grouped[day]!.sorted { $0.start < $1.start }
            return DirectionDay(
                date: day,
                label: ClosureFormat.dayDateLabel(day),
                roadBlocks: ofDay.filter { $0.kind == .roadBlocked },
                rampClosures: ofDay.filter { $0.kind == .rampsClosed }
            )
        }
    }

    #if DEBUG
    /// A view model pre-populated for SwiftUI previews (no network).
    static func preview(closures seed: [RoadClosure]) -> ClosuresViewModel {
        let viewModel = ClosuresViewModel()
        viewModel.closures = seed.sorted { $0.start < $1.start }
        viewModel.archivedClosures = viewModel.closures
        viewModel.dataSource = .live(
            .now,
            ClosureDataQuality(
                plannedFeedAvailable: true,
                realtimeFeedAvailable: true,
                expectedRecords: seed.count,
                mappedRecords: seed.count,
                unresolvedRecords: [],
                topologyIssues: []
            )
        )
        viewModel.lastAttemptAt = .now
        return viewModel
    }

    /// Deterministic cached-data state: closures stay visible, status reads
    /// as needing verification.
    static func previewCached(closures seed: [RoadClosure]) -> ClosuresViewModel {
        let viewModel = preview(closures: seed)
        viewModel.dataSource = .cache(Date().addingTimeInterval(-30 * 60))
        return viewModel
    }

    /// Deterministic no-data state for accessibility and safety UI checks.
    static func previewUnavailable() -> ClosuresViewModel {
        let viewModel = ClosuresViewModel()
        viewModel.closures = []
        viewModel.archivedClosures = []
        viewModel.dataSource = .unavailable
        viewModel.lastAttemptAt = .now
        return viewModel
    }
    #endif
}
