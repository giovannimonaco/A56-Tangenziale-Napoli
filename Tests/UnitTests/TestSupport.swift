import Foundation
@testable import TangenzialeNapoli

enum Fixture {
    static let now = Date(timeIntervalSince1970: 1_793_916_000) // 2026-11-05 22:00 UTC

    static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func event(_ overrides: [String: Any] = [:]) throws -> AutostradeEvent {
        let fields: [String: Any] = [
            "c_str": "A56", "c_ele": "fixture", "c_dir": "N",
            "t_des_fra_it": "Entrata Chiusa", "locpri": "Agnano",
            "d_sta": now.addingTimeInterval(600).timeIntervalSince1970 * 1000,
            "d_sto": now.addingTimeInterval(3600).timeIntervalSince1970 * 1000
        ]
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AutostradeEvent.self, from: JSONSerialization.data(
            withJSONObject: fields.merging(overrides) { _, new in new }
        ))
    }

    static func closure(
        id: String = "fixture", start: Date = now.addingTimeInterval(-600),
        end: Date = now.addingTimeInterval(3600), evidence: ClosureEvidence = .scheduled,
        direction: Direction = .towardPozzuoli, both: Bool = false
    ) -> RoadClosure {
        RoadClosure(id: id, start: start, end: end, direction: direction,
                    affectsBothDirections: both, fromExit: 8, toExit: 9,
                    reason: "Lavori", isFullClosure: true, evidence: evidence)
    }
}

/// Each case owns a separate directory; tests never open the user's archive.
final class TemporaryArchive {
    let directory: URL
    let url: URL
    let archive: ClosureArchive

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("A56-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("archive.json")
        archive = ClosureArchive(fileURL: url)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

actor StubProvider: ClosureProvider {
    enum Failure: Error { case offline }
    var result: ClosureFetchResult?
    private(set) var requests = 0

    init(_ closures: [RoadClosure]? = [], quality: ClosureDataQuality? = nil) {
        result = closures.map {
            ClosureFetchResult(closures: $0, quality: quality, canInferCancellations: false)
        }
    }

    func fetchClosures() async throws -> ClosureFetchResult {
        requests += 1
        guard let result else { throw Failure.offline }
        return result
    }

    func goOffline() { result = nil }
}
