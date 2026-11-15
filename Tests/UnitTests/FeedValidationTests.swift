import Foundation
import Testing
@testable import TangenzialeNapoli

/// A response is selected by a request header, so concurrent cases share no mutable fixture state.
private final class FeedProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let fixture = request.value(forHTTPHeaderField: "A56-Fixture") else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let planned = url.path.hasSuffix("previsioni.json")
        let failed = fixture == "offline" || (fixture == "missing-live" && !planned)
            || (fixture == "missing-planned" && planned)
        var headers = [String: String]()
        let age: TimeInterval = fixture == "stale" ? 901 : (fixture == "future" ? -120 : 20)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        if fixture != "undated" {
            headers["Last-Modified"] = formatter.string(from: Date().addingTimeInterval(-age))
        }
        if fixture == "content-range" { headers["Content-Range"] = "bytes 0-50/100" }
        let status = failed ? 503 : (fixture == "http206" ? 206 : 200)
        let body: String
        switch fixture {
        case "empty": body = #"{"events":[]}"#
        case "renamed": body = #"{"events":[{"road":"A56"}]}"#
        case "malformed": body = #"{"events":[{"c_str":"A56","d_sta":"invalid"}]}"#
        case "bad-json": body = "{"
        default: body = #"{"events":[{"c_str":"A1"}]}"#
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite("HTTP feed trust and partial availability")
struct FeedValidationTests {
    private func fetch(_ fixture: String) async throws -> ClosureFetchResult {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FeedProtocol.self]
        config.httpAdditionalHeaders = ["A56-Fixture": fixture]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        return try await LiveClosureProvider(session: session).fetchClosures()
    }

    @Test(arguments: ["offline", "http206", "content-range", "stale", "future", "undated", "bad-json"])
    func `Untrustworthy responses from both feeds fail the refresh`(_ fixture: String) async {
        await #expect(throws: (any Error).self) { try await fetch(fixture) }
    }

    @Test(arguments: ["empty", "renamed", "malformed"])
    func `Empty or unreadable coverage cannot infer cancellations or an all clear`(_ fixture: String) async throws {
        let result = try await fetch(fixture)
        #expect(result.quality?.isFullyVerified == false)
        #expect(!result.canInferCancellations)
        #expect(!result.canRevalidateActive)
    }

    @Test(arguments: ["missing-live", "missing-planned"])
    func `Partial availability grants only the relevant omission evidence`(_ fixture: String) async throws {
        let result = try await fetch(fixture)
        #expect(result.quality?.isFullyVerified == false)
        #expect(result.canInferCancellations == (fixture == "missing-live"))
        #expect(result.canRevalidateActive == (fixture == "missing-planned"))
    }

    @Test func `Readable non A56 rows establish verified empty A56 coverage`() async throws {
        let result = try await fetch("valid")
        #expect(result.quality?.isFullyVerified == true)
        #expect(result.closures.isEmpty)
        #expect(result.canInferCancellations && result.canRevalidateActive)
    }
}
