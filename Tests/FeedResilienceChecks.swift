import Foundation

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let fixture = request.value(forHTTPHeaderField: "A56-Test-Fixture") else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let planned = url.path.hasSuffix("previsioni.json")
        let unavailable = fixture == "offline"
            || (fixture == "partial" && !planned)
            || (fixture == "planned-unavailable" && planned)
        let status = unavailable ? 503
            : (fixture == "range" && !planned ? 206 : 200)
        let content: String
        switch fixture {
        case "bounded-times" where planned:
            let start = Date().addingTimeInterval(6 * 3600).timeIntervalSince1970 * 1000
            let end = start + 6 * 3600 * 1000
            content = """
            {"events":[{"c_str":"A56","c_dir":"N","t_des_fra_it":"Entrata Chiusa","locpri":"Agnano",
            "d_sta":\(start),"d_sto":\(end),"indisponibilita":[{"d_ini":\(start),"d_fin":\(end + 5 * 3600 * 1000)}]}]}
            """
        case "renamed":
            content = #"{"events":[{"road":"A56","type":"Tratto Chiuso"}]}"#
        case "malformed":
            content = #"{"events":[{"c_str":"A1"},{"c_str":"A56","d_sta":"bad"}]}"#
        case "empty":
            content = #"{"events":[]}"#
        default:
            content = #"{"events":[{"c_str":"A1"}]}"#
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let age: TimeInterval = fixture == "stalled" && !planned ? 15 * 60 : 20
        let headers = ["Last-Modified": formatter.string(from: Date().addingTimeInterval(-age))]
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(content.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor enum FeedResilienceChecks {
    private static func provider(_ fixture: String) -> LiveClosureProvider {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["A56-Test-Fixture": fixture]
        configuration.protocolClasses = [FixtureProtocol.self]
        return LiveClosureProvider(session: URLSession(configuration: configuration))
    }

    static func run() async throws {
        for fixture in ["renamed", "malformed"] {
            let result = try await provider(fixture).fetchClosures()
            precondition(result.quality?.isFullyVerified == false, "Invalid feeds must not produce an all-clear")
            precondition(!result.canInferCancellations && !result.canRevalidateActive,
                         "Unreadable rows cannot cancel or end cached closures")
        }

        let partial = try await provider("partial").fetchClosures()
        precondition(partial.quality?.isFullyVerified == false)
        precondition(partial.canInferCancellations && !partial.canRevalidateActive,
                     "Each feed supplies evidence only within its own scope")

        let empty = try await provider("empty").fetchClosures()
        precondition(empty.quality?.isFullyVerified == false && !empty.canInferCancellations && !empty.canRevalidateActive,
                     "An empty schedule cannot wipe future notices or produce an all-clear")

        let range = try await provider("range").fetchClosures()
        precondition(range.quality?.realtimeFeedAvailable == false && !range.canRevalidateActive,
                     "A valid JSON fragment served as HTTP 206 cannot invalidate active closures")

        let stalled = try await provider("stalled").fetchClosures()
        precondition(stalled.quality?.realtimeFeedAvailable == false && !stalled.canRevalidateActive,
                     "A successful HTTP response can still contain an old publication")

        let bounded = try await provider("bounded-times").fetchClosures()
        precondition(bounded.quality?.isFullyVerified == true
            && bounded.canInferCancellations && bounded.closures.first?.reportedWindow != nil,
            "A mapped timing discrepancy should only affect trips that encounter the closure")

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("a56-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let archive = ClosureArchive(fileURL: file)
        var clock = Date(timeIntervalSince1970: 1_793_916_000) // 5 Nov 2026, 23:00 in Naples
        let planned = RoadClosure(id: "planned", start: clock.addingTimeInterval(3600),
                                  end: clock.addingTimeInterval(7200), direction: .towardPozzuoli,
                                  fromExit: 12, toExit: 14, reason: "Test", isFullClosure: true, evidence: .scheduled)
        let live = RoadClosure(id: "live", start: clock.addingTimeInterval(-3600),
                                end: clock.addingTimeInterval(7200), direction: .towardCapodichino,
                                fromExit: 14, toExit: 12, reason: "Test", isFullClosure: true, evidence: .realtime)
        let legacy = ArchivedClosures(schemaVersion: 2, lastFetchedAt: clock, closures: [planned, live])
        var oldPayload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        oldPayload["closures"] = (oldPayload["closures"] as! [[String: Any]]).map { row in
            row.merging(["sourceText": "Legacy notice text"]) { _, text in text }
        }
        try JSONSerialization.data(withJSONObject: oldPayload).write(to: file)
        let migrated = await archive.load()
        let storedData = try Data(contentsOf: file)
        precondition(migrated?.closures == [planned, live] && migrated?.schemaVersion == 3)
        precondition(!String(decoding: storedData, as: UTF8.self).contains("sourceText"),
                     "Archive migration must remove copies of the original notices")
        let invalid = try await provider("malformed").fetchClosures()
        let retained = await archive.record(invalid.closures, now: clock,
                                            canInferCancellations: invalid.canInferCancellations,
                                            canRevalidateActive: invalid.canRevalidateActive)
        precondition(retained.contains(planned) && retained.contains(live))

        let offline = ClosuresViewModel(provider: provider("offline"), archive: archive, clock: { clock })
        await offline.load()
        precondition(offline.freshness == .cache(clock) && offline.dataNeedsVerification)
        precondition(offline.activeClosures(for: .towardCapodichino) == [live])
        precondition(offline.freshness?.updateLabel(reference: clock).contains("avvisi salvati alle 23:00") == true)

        for (fixture, title) in [
            ("partial", "Tempo reale assente"),
            ("planned-unavailable", "Programmazione assente"),
            ("malformed", "Avvisi incompleti")
        ] {
            let model = ClosuresViewModel(provider: provider(fixture), archive: archive, clock: { clock })
            await model.load()
            precondition(model.dataNeedsVerification && model.freshness?.limitationTitle == title)
            precondition(model.freshness?.updateLabel(reference: clock) == "\(title) · controllo alle 23:00")
        }

        let scoped = ClosuresViewModel(provider: provider("bounded-times"), archive: archive, clock: { clock })
        await scoped.load()
        precondition(!scoped.dataNeedsVerification && scoped.freshness?.limitationTitle == nil
            && scoped.closures.contains { $0.reportedWindow != nil })

        let online = ClosuresViewModel(provider: provider("valid"), archive: archive, clock: { clock })
        await online.load()
        let lastFetch = clock
        precondition(online.freshness == .fresh(lastFetch) && !online.dataNeedsVerification)
        clock += ClosuresViewModel.freshnessLimit
        online.refreshNow()
        precondition(online.freshness == .expired(lastFetch) && online.dataNeedsVerification)
        precondition(online.freshness?.limitationTitle == "Avvisi non aggiornati")
        await online.refreshIfStale()
        precondition(online.freshness == .fresh(clock), "An in-app refresh must revalidate expired notices")
        let cleared = await online.clearLocalArchive()
        let afterClear = await archive.load()
        precondition(cleared && afterClear == nil)

        let unavailable = ClosuresViewModel(provider: provider("offline"), archive: archive, clock: { clock })
        await unavailable.load()
        precondition(unavailable.freshness == .unavailable)
        precondition(unavailable.freshness?.limitationTitle == "Avvisi indisponibili")

        precondition(ClosureFormat.timeLabel(lastFetch) == "23:00", "Use Naples time regardless of the device time zone")
        print("A56 feed integrity, cache fallback, refresh expiry and Naples time checks passed.")
    }
}
