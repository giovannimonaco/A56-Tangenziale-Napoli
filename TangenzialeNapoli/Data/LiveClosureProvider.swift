import Foundation

/// Combines the public Autostrade planned and real-time feeds and maps their
/// A56 events into structured closures.
///
/// These are the same JSON files the official site (viabilita.autostrade.it)
/// loads for its viability pages: public, unauthenticated, and undocumented,
/// so keep a fallback around (see `ClosuresViewModel`).
nonisolated struct LiveClosureProvider: ClosureProvider {

    static let feedURL = URL(string: "https://viabilita.autostrade.it/json/previsioni.json")!
    static let realtimeFeedURL = URL(string: "https://viabilita.autostrade.it/json/eventi.json")!
    private static let maximumPublicationAge: TimeInterval = 5 * 60
    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()
    private static let feedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.feedSession
    }

    @concurrent func fetchClosures() async throws -> ClosureFetchResult {
        // Fetch both independently. A temporary failure of the supplementary
        // real-time feed must not hide all planned closures, and vice versa.
        async let plannedFeed = readFeed(from: Self.feedURL, label: "planned")
        async let realtimeFeed = readFeed(from: Self.realtimeFeedURL, label: "realtime")
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
        let duplicateLiveIDs = Set(Dictionary(grouping: activeClosures, by: \.id)
            .filter { $0.value.count > 1 }.keys)

        // Only confirm an unambiguous currently active occurrence. A long
        // live notice can overlap several future nightly windows.
        var confirmedLiveIDs = Set<String>()
        let confirmedPlanned = plannedClosures.map { plannedClosure in
            guard plannedClosure.start <= now else { return plannedClosure }
            let matches = activeClosures.filter { ClosureMatching.sameOccurrence(plannedClosure, $0) }
            guard matches.count == 1, let live = matches.first, !duplicateLiveIDs.contains(live.id),
                  plannedClosures.filter({ $0.start <= now && ClosureMatching.sameOccurrence($0, live) }).count == 1
            else { return plannedClosure }
            confirmedLiveIDs.insert(live.id)
            return plannedClosure.confirmed(by: live)
        }
        let activeBackfill = activeClosures.filter { !confirmedLiveIDs.contains($0.id) }
        let candidates = confirmedPlanned + activeBackfill
        let groups = Dictionary(grouping: candidates, by: \.id)
        let closures = groups.values.compactMap { rows -> RoadClosure? in
            guard let first = rows.first, rows.allSatisfy({ $0 == first }) else { return nil }
            return first
        }.sorted { ($0.start, $0.id) < ($1.start, $1.id) }

        let mappingIssues = plannedReport.issues + realtimeReport.issues
        var issueSummaries = mappingIssues.filter { !$0.coveredByMappedWindow }.map(\.summary)
        var mappedTimingIssues = mappingIssues.filter(\.coveredByMappedWindow).map(\.summary)
        if confirmedPlanned.contains(where: { $0.evidence == .realtimeConfirmed && $0.reportedWindow != nil && $0.hasUnpublishedEnd != true }) {
            mappedTimingIssues.append("Programmazione e tempo reale riportano orari discordanti.")
        }
        if let dropped = planned?.undecodedEventCount, dropped > 0 {
            issueSummaries.append("\(dropped) righe del feed programmato non decodificabili.")
        } else if planned?.events.isEmpty == true {
            issueSummaries.append("Il feed programmato nazionale è vuoto.")
        }
        if let dropped = realtime?.undecodedEventCount, dropped > 0 {
            issueSummaries.append("\(dropped) righe del feed in tempo reale non decodificabili.")
        } else if realtime?.events.isEmpty == true {
            issueSummaries.append("Il feed nazionale in tempo reale è vuoto.")
        }
        let integrityIssues = A56Line.validationIssues + Self.integrityIssues(in: candidates)
        let quality = ClosureDataQuality(
            plannedFeedAvailable: planned != nil,
            realtimeFeedAvailable: realtime != nil,
            expectedRecords: plannedReport.expectedOccurrences + realtimeReport.expectedEvents,
            mappedRecords: plannedReport.mappedOccurrences + realtimeReport.mappedEvents,
            unresolvedRecords: issueSummaries,
            topologyIssues: integrityIssues,
            mappedTimingIssues: mappedTimingIssues
        )
        AppLog.log(
            "planned=\(plannedClosures.count), active=\(activeClosures.count), backfill=\(activeBackfill.count), verified=\(quality.mappedRecords)/\(quality.expectedRecords) -> \(closures.count) A56 closures",
            "feed"
        )
        return ClosureFetchResult(
            closures: closures,
            quality: quality,
            canInferCancellations: integrityIssues.isEmpty && planned?.events.isEmpty == false
                && planned?.undecodedEventCount == 0 && plannedReport.hasCompleteCoverage,
            canRevalidateActive: integrityIssues.isEmpty && realtime?.events.isEmpty == false
                && realtime?.undecodedEventCount == 0 && realtimeReport.isComplete
        )
    }

    private func readFeed(from url: URL, label: String) async -> AutostradeFeed? {
        do {
            return try await fetchFeed(from: url, label: label)
        } catch {
            AppLog.log("\(label) rejected: \(error.localizedDescription)", "feed")
            return nil
        }
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
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "index", value: String(Double.random(in: 0..<1)))]
        guard let requestURL = components?.url else {
            throw ClosureFeedError.badResponse(-1)
        }

        var request = URLRequest(url: requestURL, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        AppLog.log("GET \(label) \(requestURL.absoluteString)", "feed")
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else { throw ClosureFeedError.badResponse(-1) }
        let status = response.statusCode
        AppLog.log("\(label) HTTP \(status), \(data.count) bytes", "feed")
        guard status == 200, response.value(forHTTPHeaderField: "Content-Range") == nil else {
            throw ClosureFeedError.badResponse(status)
        }
        guard data.count <= 8 * 1024 * 1024 else { throw ClosureFeedError.oversizedResponse }
        // A new HTTP request can still return a stalled snapshot. The publisher
        // stamps each generated file with Last-Modified; without a recent stamp
        // its omissions are not evidence that a closure ended or was cancelled.
        guard let modified = response.value(forHTTPHeaderField: "Last-Modified")
            .flatMap(Self.httpDateFormatter.date(from:)),
            (-60..<Self.maximumPublicationAge).contains(Date().timeIntervalSince(modified))
        else { throw ClosureFeedError.unverifiedPublicationTime }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AutostradeFeed.self, from: data)
    }
}

enum ClosureFeedError: LocalizedError {
    case badResponse(Int)
    case oversizedResponse
    case unverifiedPublicationTime
    case noAvailableSource

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            "Risposta non valida dal servizio viabilità (codice \(code))."
        case .oversizedResponse:
            "Risposta troppo grande dal servizio viabilità."
        case .unverifiedPublicationTime:
            "La data di pubblicazione degli avvisi non è verificabile o non è recente."
        case .noAvailableSource:
            "I servizi di viabilità programmata e in tempo reale non sono raggiungibili."
        }
    }
}
