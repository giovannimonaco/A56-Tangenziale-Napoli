//
//  ClosuresViewModel.swift
//  TangenzialeNapoli
//
//  Loads closures from the live feed with a robust fallback chain
//  (live → last-good cache → unavailable) and groups them per direction.
//

import Foundation
import Observation

@MainActor
@Observable
final class ClosuresViewModel {

    /// Where the currently displayed data came from.
    enum DataSource: Equatable {
        case live(Date, ClosureDataQuality) // fresh from the network
        case cache(Date)    // last good response, network unavailable
        case unavailable    // no trustworthy live or cached response

        var isStale: Bool {
            switch self {
            case .live(_, let quality): !quality.isFullyVerified
            case .cache, .unavailable: true
            }
        }
    }

    /// The one distinction the status line communicates. `partial` means the
    /// refresh DID succeed but one feed or some rows could not be read; it
    /// must not look like the offline `cache` state, or users will retry a
    /// refresh that already worked.
    enum Freshness: Equatable {
        case fresh(Date)
        case partial(Date)
        case cache(Date)
        case unavailable
    }

    var freshness: Freshness? {
        switch dataSource {
        case .live(let date, let quality):
            quality.isFullyVerified ? .fresh(date) : .partial(date)
        case .cache(let date):
            .cache(date)
        case .unavailable:
            .unavailable
        case nil:
            nil
        }
    }

    /// One day for one direction, split into the two things a driver cares
    /// about: roads blocked vs ramps closed.
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
    private let archive = ClosureArchive()

    private(set) var closures: [RoadClosure] = []
    /// Rolling ~10-day archive, for the history screen and the offline fallback.
    private(set) var archivedClosures: [RoadClosure] = []
    private(set) var isLoading = false
    private(set) var dataSource: DataSource?
    /// "Now" used to split active vs upcoming. Refreshed on load and by a timer.
    private(set) var now: Date = .now
    /// When the live feed last loaded successfully (drives refresh-on-foreground).
    private(set) var lastLoadedAt: Date?

    /// Defaults to the live feed. The last resort is deliberately empty:
    /// synthetic closures are reserved for previews and explicit test setups.
    init(provider: ClosureProvider? = nil, fallback: ClosureProvider? = nil) {
        self.provider = provider ?? LiveClosureProvider()
        self.fallback = fallback ?? EmptyClosureProvider()
    }

    func load() async {
        guard !isLoading else {
            AppLog.log("load() ignored: refresh already in progress", "vm")
            return
        }
        isLoading = true
        now = Date()
        AppLog.log("load() start, now=\(now.formatted(date: .abbreviated, time: .standard))", "vm")
        defer { isLoading = false; logSummary(); dumpClosures() }

        // 1. Try the live feed.
        do {
            let result = try await provider.fetchClosures()
            let timestamp = Date()
            // The official feed only lists FUTURE windows: once a closure starts
            // it disappears from it. So we drive the UI from the rolling archive
            // (which retains closures we saw while they were still upcoming),
            // not just this fetch — otherwise an active overnight closure checked
            // after midnight would show nothing.
            archivedClosures = await archive.record(
                result.closures,
                now: timestamp,
                canInferCancellations: result.canInferCancellations,
                canRevalidateActive: result.canRevalidateActive
            )
            closures = archivedClosures
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
        if let stored = await archive.load() {
            closures = stored.closures.sorted { $0.start < $1.start }
            archivedClosures = stored.closures
            dataSource = .cache(stored.lastFetchedAt)
            AppLog.log("CACHE fallback: archived=\(closures.count)", "vm")
            return
        }

        // 3. Last resort: an explicitly unavailable state, never fake events.
        closures = ((try? await fallback.fetchClosures())?.closures ?? []).sorted { $0.start < $1.start }
        archivedClosures = []
        dataSource = .unavailable
        AppLog.log("UNAVAILABLE fallback", "vm")
    }

    /// Detailed per-closure dump (deduplicated by event) — for debugging which
    /// cases the user has right now and how they're coloured/classified.
    /// The whole body is Debug-only: it walks every closure and builds strings,
    /// work that Release builds must not pay for.
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
            let tunnel = c.sourceText.lowercased().contains("galleria") ? "tunnel-in-text" : "-"
            AppLog.log("\(kind) | \(c.headline) | \(c.direction.shortName) | \(place) | sev=\(c.severity.displayName) | reason=\(c.reason) | \(tunnel)", "dump")
        }
        #endif
    }

    /// Logs active / upcoming / past counts per direction after a load.
    /// Debug-only for the same reason: `upcomingDays`/`pastDays` are the most
    /// expensive calls in the view model.
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
    func refreshNow() { now = Date() }

    /// Called when the app returns to the foreground: re-fetch if the data is
    /// older than `maxAge`, otherwise just re-evaluate "now". This is what makes
    /// reopening the app show closures added to the feed since the last load.
    func refreshIfStale(maxAge: TimeInterval = 120) async {
        guard !isLoading else { AppLog.log("refreshIfStale: skip (loading)", "vm"); return }
        if let last = lastLoadedAt, Date().timeIntervalSince(last) < maxAge {
            AppLog.log("refreshIfStale: fresh (age=\(Int(Date().timeIntervalSince(last)))s) → refreshNow", "vm")
            refreshNow()
        } else {
            AppLog.log("refreshIfStale: stale → reload", "vm")
            await load()
        }
    }

    /// Re-apply the archive retention (no network) after the user changes the
    /// duration setting.
    func applyRetentionChange() {
        Task {
            archivedClosures = await archive.reprune(now: now)
            closures = archivedClosures
            AppLog.log("retention applied, archived=\(archivedClosures.count)", "vm")
        }
    }

    // MARK: - Direction-scoped grouping

    private var calendar: Calendar { .current }

    /// Closures happening RIGHT NOW in this direction. Shown even when they
    /// began before midnight — the common case for overnight (23:00–06:00)
    /// closures that would otherwise vanish in the early hours.
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
    /// recent first — the rolling ~10-day history kept on device.
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
        viewModel.lastLoadedAt = .now
        return viewModel
    }

    /// Deterministic cached-data state: known closures remain visible, but
    /// every status must clearly communicate that it needs verification.
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
        viewModel.lastLoadedAt = .now
        return viewModel
    }
    #endif
}
