//
//  ClosureProvider.swift
//  TangenzialeNapoli
//
//  Abstraction over the source of closures. Swap the implementation to go
//  from preview data to a live feed without touching the UI.
//

import Foundation

/// Measured quality of one network refresh. Counts are computed before rows
/// are mapped, so an unsupported official event cannot disappear silently.
struct ClosureDataQuality: Equatable, Sendable {
    let plannedFeedAvailable: Bool
    let realtimeFeedAvailable: Bool
    let expectedRecords: Int
    let mappedRecords: Int
    let unresolvedRecords: [String]
    let topologyIssues: [String]

    var mappingIsComplete: Bool {
        expectedRecords == mappedRecords
            && unresolvedRecords.isEmpty
            && topologyIssues.isEmpty
    }

    var isFullyVerified: Bool {
        plannedFeedAvailable && realtimeFeedAvailable && mappingIsComplete
    }
}

struct ClosureFetchResult: Sendable {
    let closures: [RoadClosure]
    let quality: ClosureDataQuality?
    /// Missing future rows can be treated as cancellations only after a
    /// complete planned-feed mapping.
    let canInferCancellations: Bool
    /// Archived closures that came from the live feed can be closed early
    /// (works finished ahead of schedule) only when the live feed itself was
    /// fully readable; otherwise their absence is ambiguous.
    let canRevalidateActive: Bool

    init(
        closures: [RoadClosure],
        quality: ClosureDataQuality?,
        canInferCancellations: Bool,
        canRevalidateActive: Bool = false
    ) {
        self.closures = closures
        self.quality = quality
        self.canInferCancellations = canInferCancellations
        self.canRevalidateActive = canRevalidateActive
    }
}

/// Anything that can supply the current set of A56 closures.
///
/// The app talks to this protocol only, so the data source is replaceable:
/// - `MockClosureProvider`  — seeded realistic data for previews and tests.
/// - `LiveClosureProvider`  — network feeds and parsing pipeline.
protocol ClosureProvider: Sendable {
    /// Returns all known upcoming closures. Implementations may hit the
    /// network, read a cache, or return seeded data.
    func fetchClosures() async throws -> ClosureFetchResult
}

/// Safe production fallback: no synthetic road event must ever be presented as
/// real when both the live source and the local archive are unavailable.
struct EmptyClosureProvider: ClosureProvider {
    func fetchClosures() async throws -> ClosureFetchResult {
        ClosureFetchResult(
            closures: [],
            quality: nil,
            canInferCancellations: false
        )
    }
}

/// Provides sample closures that mirror the shape of real Autostrade notices.
///
/// Dates are generated relative to "today" so the Home screen always has
/// content in its Today / Tomorrow / Next days buckets while there is no
/// live feed wired up yet.
struct MockClosureProvider: ClosureProvider {

    /// Simulated latency, so loading states are exercised in the UI.
    var simulatedDelay: Duration = .milliseconds(350)

    func fetchClosures() async throws -> ClosureFetchResult {
        if simulatedDelay > .zero {
            try await Task.sleep(for: simulatedDelay)
        }
        return ClosureFetchResult(
            closures: SampleClosures.make(),
            quality: nil,
            canInferCancellations: false
        )
    }
}
