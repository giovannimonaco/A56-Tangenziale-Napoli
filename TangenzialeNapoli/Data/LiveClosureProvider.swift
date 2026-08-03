//
//  LiveClosureProvider.swift
//  TangenzialeNapoli
//
//  Real data source: combines the public Autostrade planned and real-time feeds
//  and maps their A56 events into structured closures.
//

import Foundation

/// Fetches planned closures from the official public viability feed.
///
/// This is the same JSON the official site (viabilita.autostrade.it) loads to
/// render its "Previsioni" page — a public, unauthenticated file. It is an
/// unofficial integration (no documented API), so callers should treat it as
/// best-effort and keep a fallback (see `ClosuresViewModel`).
struct LiveClosureProvider: ClosureProvider {

    /// Public feeds used by Autostrade's own viability pages.
    static let feedURL = URL(string: "https://viabilita.autostrade.it/json/previsioni.json")!
    static let realtimeFeedURL = URL(string: "https://viabilita.autostrade.it/json/eventi.json")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchClosures() async throws -> ClosureFetchResult {
        // Fetch both independently. A temporary failure of the supplementary
        // real-time feed must not hide all planned closures, and vice versa.
        async let plannedFeed: AutostradeFeed? = try? fetchFeed(from: Self.feedURL, label: "planned")
        async let realtimeFeed: AutostradeFeed? = try? fetchFeed(from: Self.realtimeFeedURL, label: "realtime")
        let (planned, realtime) = await (plannedFeed, realtimeFeed)

        try Task.checkCancellation()

        guard planned != nil || realtime != nil else {
            throw ClosureFeedError.noAvailableSource
        }

        let now = Date()
        let plannedReport = AutostradeClosureMapper.mappingReport(
            from: planned?.events ?? [],
            now: now
        )
        let realtimeReport = AutostradeRealtimeClosureMapper.mappingReport(
            from: realtime?.events ?? [],
            now: now
        )
        let plannedClosures = plannedReport.closures
        let activeClosures = realtimeReport.closures

        // Preserve the scheduled feed's exact start/end window when the live
        // feed confirms the same occurrence. Only genuinely missing scheduled
        // rows are backfilled with the live activation time.
        let confirmedPlanned = plannedClosures.map { plannedClosure in
            activeClosures.contains {
                AutostradeRealtimeClosureMapper.sameOccurrence(plannedClosure, $0)
            }
                ? plannedClosure.withEvidence(.realtimeConfirmed)
                : plannedClosure
        }
        let activeBackfill = activeClosures.filter { activeClosure in
            !plannedClosures.contains {
                AutostradeRealtimeClosureMapper.sameOccurrence($0, activeClosure)
            }
        }
        let closures = (confirmedPlanned + activeBackfill).sorted { $0.start < $1.start }
        let issueSummaries = (plannedReport.issues + realtimeReport.issues)
            .map(\.summary)
        let integrityIssues = Self.integrityIssues(in: closures)
        let quality = ClosureDataQuality(
            plannedFeedAvailable: planned != nil,
            realtimeFeedAvailable: realtime != nil,
            expectedRecords: plannedReport.expectedOccurrences + realtimeReport.expectedEvents,
            mappedRecords: plannedReport.mappedOccurrences + realtimeReport.mappedEvents,
            unresolvedRecords: issueSummaries,
            topologyIssues: A56Line.validationIssues + integrityIssues
        )
        AppLog.log(
            "planned=\(plannedClosures.count), active=\(activeClosures.count), backfill=\(activeBackfill.count), verified=\(quality.mappedRecords)/\(quality.expectedRecords) → \(closures.count) A56 closures",
            "feed"
        )
        return ClosureFetchResult(
            closures: closures,
            quality: quality,
            canInferCancellations: planned?.events.isEmpty == false && plannedReport.isComplete
        )
    }

    /// Domain-level assertions run on every refresh. They catch regressions
    /// even when JSON decoding and place resolution both technically succeed.
    private static func integrityIssues(in closures: [RoadClosure]) -> [String] {
        var issues: [String] = []
        let duplicateIDs = Dictionary(grouping: closures, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
        if !duplicateIDs.isEmpty {
            issues.append("Identificativi di chiusura duplicati.")
        }

        for closure in closures {
            if closure.start >= closure.end {
                issues.append("\(closure.id): intervallo temporale non valido.")
            }
            if A56Line.exit(closure.fromExit) == nil || A56Line.exit(closure.toExit) == nil {
                issues.append("\(closure.id): posizione fuori dalla linea A56.")
            }
            if closure.kind == .roadBlocked {
                let orderedCorrectly = closure.direction.goesUpTheLine
                    ? closure.fromExit <= closure.toExit
                    : closure.fromExit >= closure.toExit
                if !orderedCorrectly {
                    issues.append("\(closure.id): estremi contrari al senso di marcia.")
                }
            } else if closure.closedRamps.isEmpty
                        || closure.closedRamps.contains(where: { $0.exitNumber != closure.rampExitNumber }) {
                issues.append("\(closure.id): dettaglio entrata/uscita incoerente.")
            }
        }
        return issues
    }

    private func fetchFeed(from url: URL, label: String) async throws -> AutostradeFeed {
        // Cache-busting query param, mirroring the website's own request.
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "index", value: String(Double.random(in: 0..<1)))]

        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.autostrade.it/", forHTTPHeaderField: "Referer")

        AppLog.log("GET \(label) \(components.url!.absoluteString)", "feed")
        let (data, response) = try await session.data(for: request)

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.log("\(label) HTTP \(status), \(data.count) bytes", "feed")
        guard (200..<300).contains(status) else {
            throw ClosureFeedError.badResponse(status)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AutostradeFeed.self, from: data)
    }
}

enum ClosureFeedError: LocalizedError {
    case badResponse(Int)
    case noAvailableSource

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            "Risposta non valida dal servizio viabilità (codice \(code))."
        case .noAvailableSource:
            "I servizi di viabilità programmata e in tempo reale non sono raggiungibili."
        }
    }
}
