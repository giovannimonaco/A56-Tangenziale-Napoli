import Foundation

/// Measured quality of one network refresh. Counts are computed before rows
/// are mapped, so an unsupported official event cannot disappear silently.
nonisolated struct ClosureDataQuality: Equatable, Sendable {
    let plannedFeedAvailable: Bool
    let realtimeFeedAvailable: Bool
    let expectedRecords: Int
    let mappedRecords: Int
    let unresolvedRecords: [String]
    let topologyIssues: [String]
    var mappedTimingIssues: [String] = []

    var mappingIsComplete: Bool {
        mappingHasCompleteCoverage && mappedTimingIssues.isEmpty
    }

    private var mappingHasCompleteCoverage: Bool {
        expectedRecords == mappedRecords
            && unresolvedRecords.isEmpty
            && topologyIssues.isEmpty
    }

    var canAssessTrip: Bool {
        plannedFeedAvailable && realtimeFeedAvailable && mappingHasCompleteCoverage
    }

    var isFullyVerified: Bool {
        plannedFeedAvailable && realtimeFeedAvailable && mappingIsComplete
    }
}

nonisolated struct ClosureFetchResult: Sendable {
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
/// - `MockClosureProvider`: seeded data for previews and tests.
/// - `LiveClosureProvider`: network feeds and parsing pipeline.
nonisolated protocol ClosureProvider: Sendable {
    /// Returns all known upcoming closures. Implementations may hit the
    /// network, read a cache, or return seeded data.
    func fetchClosures() async throws -> ClosureFetchResult
}

/// Production fallback: returns nothing, rather than synthetic data, when both
/// the live source and the local archive are unavailable.
struct EmptyClosureProvider: ClosureProvider {
    func fetchClosures() async throws -> ClosureFetchResult {
        ClosureFetchResult(
            closures: [],
            quality: nil,
            canInferCancellations: false
        )
    }
}

/// Sample closures shaped like real Autostrade notices, with dates relative
/// to "today" so the Home screen buckets are always populated.
struct MockClosureProvider: ClosureProvider {

    /// Simulated latency, so loading states show up in the UI.
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
