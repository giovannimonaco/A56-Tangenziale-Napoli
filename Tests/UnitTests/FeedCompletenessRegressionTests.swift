import Foundation
import MapKit
import Testing
@testable import TangenzialeNapoli

@Suite("Feed completeness regressions")
struct FeedCompletenessRegressionTests {
    private let terminalText = "Tratto Chiuso tra Fine Tangenziale Napoli e Secondigliano-Aeroporto per manutenzione programmata."

    private func terminalEvent(_ overrides: [String: Any] = [:]) throws -> AutostradeEvent {
        try Fixture.event([
            "c_ele": "synthetic-terminal", "t_des_fra_it": "Tratto Chiuso",
            "locpri": "Secondigliano-Aeroporto", "locsec": "Capodichino",
            "c_pnt_dtx_pls_pri": 11222, "c_pnt_dtx_pls_sec": 1117,
            "n_crd_lat_ini": 40.8769, "n_crd_lon_ini": 14.2899,
            "n_crd_lat_fin": 40.8719, "n_crd_lon_fin": 14.2833,
            "t_des_it": terminalText
        ].merging(overrides) { _, replacement in replacement })
    }

    @Test(arguments: [false, true], ["N", "P"])
    func `Distinct terminal identifiers survive collapsed prose aliases`(_ reversed: Bool, _ code: String) throws {
        var fields: [String: Any] = ["c_dir": code]
        if reversed {
            fields.merge([
                "locpri": "Capodichino", "locsec": "Secondigliano-Aeroporto",
                "c_pnt_dtx_pls_pri": 1117, "c_pnt_dtx_pls_sec": 11222,
                "n_crd_lat_ini": 40.8719, "n_crd_lon_ini": 14.2833,
                "n_crd_lat_fin": 40.8769, "n_crd_lon_fin": 14.2899
            ]) { _, replacement in replacement }
        }
        let event = try terminalEvent(fields)
        let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        let closure = try #require(report.closures.first)
        #expect(report.expectedOccurrences == 1)
        #expect(report.mappedOccurrences == 1)
        #expect(report.isComplete)
        #expect(closure.isFullClosure)
        #expect(closure.fromExit == (code == "N" ? 1 : 2))
        #expect(closure.toExit == (code == "N" ? 2 : 1))
        #expect(closure.id.hasPrefix("synthetic-terminal#"))
    }

    @Test func `Terminal recovery retains the wider disputed schedule window`() throws {
        let publishedEnd = Fixture.now.addingTimeInterval(3600)
        let windowEnd = publishedEnd.addingTimeInterval(3600)
        let event = try terminalEvent(["indisponibilita": [[
            "d_ini": Fixture.now.addingTimeInterval(600).timeIntervalSince1970 * 1000,
            "d_fin": windowEnd.timeIntervalSince1970 * 1000
        ]]])
        let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        let closure = try #require(report.closures.first)
        #expect(report.hasCompleteCoverage)
        #expect(!report.isComplete)
        #expect(closure.end == windowEnd)
        #expect(closure.reportedWindow?.end == publishedEnd)
        #expect(report.issues.count == 1)
        #expect(report.issues.first?.coveredByMappedWindow == true)
    }

    @Test func `Realtime uses the same terminal distinction without losing the active closure`() throws {
        let event = try terminalEvent([
            "d_sta": Fixture.now.addingTimeInterval(-60).timeIntervalSince1970 * 1000,
            "fino_al": "202611060500P01:303"
        ])
        let report = AutostradeRealtimeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        let closure = try #require(report.closures.first)
        #expect(report.isComplete)
        #expect(closure.fromExit == 1)
        #expect(closure.toExit == 2)
        #expect(closure.evidence == .realtime)
    }

    @Test(arguments: ["N", "P"])
    func `Recovered terminal segment has real length and blocks matching route traversals`(_ code: String) throws {
        let event = try terminalEvent(["c_dir": code])
        let closure = try #require(AutostradeClosureMapper.mappingReport(
            from: [event], now: Fixture.now).closures.first)
        let line = A56RouteGeometry.segment(from: closure.fromExit, to: closure.toExit, direction: closure.direction)
        try #require(line.count >= 2)
        let schematicLength = zip(line, line.dropFirst()).reduce(0.0) {
            $0 + MKMapPoint($1.0).distance(to: MKMapPoint($1.1))
        }
        #expect(schematicLength > 1, "The two schematic positions must remain distinct")
        let published = try #require(closure.reportedSegment)
        let first = CLLocation(latitude: published.first.latitude, longitude: published.first.longitude)
        let second = CLLocation(latitude: published.second.latitude, longitude: published.second.longitude)
        #expect(first.distance(from: second) > 200, "The physical span must retain the part outside the schematic anchors")
        let resolved = try #require(A56RouteGeometry.resolvedReportedSegment(for: closure, direction: closure.direction))
        let physicalLine = A56RouteGeometry.closureSegment(for: closure, direction: closure.direction)
        let physicalLength = zip(physicalLine, physicalLine.dropFirst()).reduce(0.0) {
            $0 + MKMapPoint($1.0).distance(to: MKMapPoint($1.1))
        }
        #expect(physicalLength > 200)
        #expect(resolved.end - resolved.start > 200)
        let route = A56RouteGeometry.segment(from: code == "N" ? 1 : 3, to: code == "N" ? 3 : 1,
                                             direction: closure.direction)
        guard case .withA56(let traversals) = A56TripMatcher.usage(coordinates: route) else {
            Issue.record("The matching terminal mainline must be recognized")
            return
        }
        let impacts = A56TripMatcher.impacts(on: traversals, closures: [closure],
                                            departure: closure.start, duration: 600)
        #expect(impacts.count == 1)
        #expect(impacts.first?.kind == .roadBlock)
        #expect(impacts.first?.blocksRoute == true)

        let beyondSecondAnchor = A56RouteGeometry.segment(from: code == "N" ? 2 : 4, to: code == "N" ? 4 : 2,
                                                           direction: closure.direction)
        guard case .withA56(let terminalTraversals) = A56TripMatcher.usage(coordinates: beyondSecondAnchor) else {
            Issue.record("The mainline beyond the coarse terminal anchor must be recognized")
            return
        }
        #expect(A56TripMatcher.impacts(on: terminalTraversals, closures: [closure],
                                       departure: closure.start, duration: 600).first?.blocksRoute == true,
                "Published endpoint coordinates extend the closure beyond schematic position 2")

        let elsewhere = A56RouteGeometry.segment(from: code == "N" ? 5 : 8, to: code == "N" ? 8 : 5,
                                                 direction: closure.direction)
        guard case .withA56(let otherTraversals) = A56TripMatcher.usage(coordinates: elsewhere) else {
            Issue.record("The unrelated mainline must be recognized")
            return
        }
        #expect(A56TripMatcher.impacts(on: otherTraversals, closures: [closure],
                                       departure: closure.start, duration: 600).isEmpty)
    }

    @Test func `Physical terminal endpoints survive encoding confirmation and ending`() throws {
        let closure = try #require(AutostradeClosureMapper.mappingReport(
            from: [try terminalEvent()], now: Fixture.now).closures.first)
        let segment = try #require(closure.reportedSegment)
        #expect(segment.firstLabel == "Secondigliano-Aeroporto")
        #expect(segment.secondLabel == "Fine Tangenziale Napoli")
        let decoded = try JSONDecoder().decode(RoadClosure.self, from: JSONEncoder().encode(closure))
        #expect(decoded.reportedSegment == segment)
        #expect(closure.ended(at: closure.end).reportedSegment == segment)
        #expect(closure.confirmed(by: Fixture.closure(evidence: .realtime)).reportedSegment == segment)
    }

    @Test func `Incomplete identifiers cannot invent a terminal segment`() throws {
        for fields: [String: Any] in [
            ["c_pnt_dtx_pls_sec": NSNull()], ["c_pnt_dtx_pls_sec": 0],
            ["c_pnt_dtx_pls_sec": 99999], ["c_pnt_dtx_pls_pri": 1127],
            ["locsec": "Vomero"],
            ["n_crd_lat_ini": NSNull()], ["n_crd_lat_ini": 0],
            ["n_crd_lon_fin": 100],
            ["t_des_it": "Tratto Chiuso tra Fine Tangenziale Napoli e Fine Tangenziale Napoli per lavori."],
            ["t_des_it": "Tratto Chiuso tra Fine Tangenziale Napoli e Capodimonte per lavori."]
        ] {
            let report = AutostradeClosureMapper.mappingReport(from: [try terminalEvent(fields)], now: Fixture.now)
            #expect(!report.hasCompleteCoverage)
            #expect(report.closures.isEmpty)
        }
    }

    @Test func `Archive copies retain physical endpoints and older payloads decode without them`() async throws {
        let temporary = try TemporaryArchive()
        let planned = try #require(AutostradeClosureMapper.mappingReport(
            from: [try terminalEvent()], now: Fixture.now).closures.first)
        let segment = try #require(planned.reportedSegment)
        let liveEvent = try terminalEvent([
            "c_ele": planned.id,
            "d_sta": Fixture.now.addingTimeInterval(-60).timeIntervalSince1970 * 1000,
            "fino_al": "202611060500P01:303"
        ])
        let live = try #require(AutostradeRealtimeClosureMapper.mappingReport(
            from: [liveEvent], now: Fixture.now).closures.first)
        await temporary.archive.record([live], now: Fixture.now)
        let reconciled = await temporary.archive.record([live], now: Fixture.now.addingTimeInterval(1))
        #expect(reconciled.first?.reportedSegment == segment)
        #expect(await temporary.archive.load()?.closures.first?.reportedSegment == segment)

        for version in [1, 2, 3] {
            try JSONEncoder().encode(ArchivedClosures(schemaVersion: version, lastFetchedAt: Fixture.now,
                                                      closures: [live])).write(to: temporary.url)
            #expect(await temporary.archive.load()?.closures.first?.reportedSegment == segment)
        }

        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(live)) as? [String: Any])
        old.removeValue(forKey: "reportedSegment")
        let decoded = try JSONDecoder().decode(RoadClosure.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.reportedSegment == nil)
        #expect(decoded.id == live.id)
    }

    @Test func `Previously resolved terminal segments keep their existing endpoints`() throws {
        for (location, pointID, expectedEnd) in [("Capodichino Svincolo", 11071, 2), ("Doganella", 11224, 3)] {
            let event = try terminalEvent([
                "locpri": location, "c_pnt_dtx_pls_pri": pointID,
                "t_des_it": "Tratto Chiuso tra Fine Tangenziale Napoli e \(location) per manutenzione."
            ])
            let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
            #expect(report.hasCompleteCoverage)
            #expect(report.closures.first?.fromExit == 1)
            #expect(report.closures.first?.toExit == expectedEnd)
        }
    }

    @Test func `Complete provider includes the recovered terminal notice and its timing warning`() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TerminalFeedProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let result = try await LiveClosureProvider(session: session).fetchClosures()
        let quality = try #require(result.quality)
        #expect(quality.isFullyVerified)
        #expect(quality.expectedRecords == 1)
        #expect(quality.mappedRecords == 1)
        #expect(quality.unresolvedRecords.isEmpty)
        #expect(quality.topologyIssues.isEmpty)
        #expect(result.canInferCancellations && result.canRevalidateActive)
        let closure = try #require(result.closures.first)
        #expect(closure.fromExit == 1 && closure.toExit == 2)
        #expect(closure.reportedWindow != nil)
    }

    @Test func `Physical endpoints away from the verified road cannot produce complete quality`() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TerminalFeedProtocol.self]
        configuration.httpAdditionalHeaders = ["A56-Terminal-Case": "off-road"]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let result = try await LiveClosureProvider(session: session).fetchClosures()
        #expect(result.quality?.isFullyVerified == false)
        #expect(result.quality?.topologyIssues.isEmpty == false)
        #expect(result.closures.count == 1, "Keep the notice visible while its geometry needs verification")
        #expect(!result.canInferCancellations)
        #expect(!result.canRevalidateActive)
    }
}

private final class TerminalFeedProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let now = Date()
        let start = now.addingTimeInterval(600).timeIntervalSince1970 * 1000
        let end = now.addingTimeInterval(3600).timeIntervalSince1970 * 1000
        let firstLatitude = request.value(forHTTPHeaderField: "A56-Terminal-Case") == "off-road" ? 40.8 : 40.8769
        let body = url.path.hasSuffix("previsioni.json") ? """
        {"events":[{"c_str":"A56","c_ele":"synthetic-terminal-provider","c_dir":"N",
        "t_des_fra_it":"Tratto Chiuso","locpri":"Secondigliano-Aeroporto","locsec":"Capodichino",
        "c_pnt_dtx_pls_pri":11222,"c_pnt_dtx_pls_sec":1117,
        "n_crd_lat_ini":\(firstLatitude),"n_crd_lon_ini":14.2899,"n_crd_lat_fin":40.8719,"n_crd_lon_fin":14.2833,
        "t_des_it":"Tratto Chiuso tra Fine Tangenziale Napoli e Secondigliano-Aeroporto per manutenzione.",
        "d_sta":\(start),"d_sto":\(end),"indisponibilita":[{"d_ini":\(start),"d_fin":\(end + 3600000)}]}]}
        """ : #"{"events":[{"c_str":"A1"}]}"#
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Last-Modified": formatter.string(from: now.addingTimeInterval(-10))])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
