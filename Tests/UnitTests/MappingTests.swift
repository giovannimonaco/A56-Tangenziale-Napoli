import Foundation
import Testing
@testable import TangenzialeNapoli

@Suite("Official feed mapping")
struct MappingTests {
    @Test(arguments: [
        ("Agnano", 12), ("Italia ’90", 11), ("Capodichino/Aeroporto", 1),
        ("Secondigliano", 2), ("Doganella/Viale Umberto Maddalena", 3), ("Arco Felice", 15)
    ])
    func `Known interchange aliases resolve`(_ name: String, _ position: Int) {
        #expect(A56Line.resolveExit(named: name) == position)
    }

    @Test(arguments: ["", "Capodichino", "Vomero Agnano", "luogo sconosciuto"])
    func `Ambiguous and unknown locations remain unresolved`(_ name: String) {
        #expect(A56Line.resolveExit(named: name) == nil)
    }

    @Test(arguments: [("N", Direction.towardPozzuoli), ("P", .towardCapodichino)])
    func `Road endpoints follow travel direction`(_ code: String, _ direction: Direction) throws {
        let event = try Fixture.event([
            "c_dir": code, "t_des_fra_it": "Tratto Chiuso", "locpri": "Agnano", "locsec": "Vomero"
        ])
        let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        let closure = try #require(report.closures.first)
        #expect(report.isComplete)
        #expect(closure.direction == direction)
        #expect(closure.fromExit == (direction.goesUpTheLine ? 9 : 12))
        #expect(closure.toExit == (direction.goesUpTheLine ? 12 : 9))
    }

    @Test func `Contradictory direction or point identifiers reduce coverage`() throws {
        for event in [
            try Fixture.event(["t_des_dir_it": "Capodichino"]),
            try Fixture.event(["c_pnt_dtx_pls_pri": 1127])
        ] {
            let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
            #expect(report.expectedOccurrences == 1)
            #expect(report.closures.isEmpty)
            #expect(!report.hasCompleteCoverage)
        }
    }

    @Test func `Malformed recurring windows keep readable occurrences and expose gaps`() throws {
        let event = try Fixture.event(["indisponibilita": [
            ["d_ini": Fixture.now.addingTimeInterval(600).timeIntervalSince1970 * 1000,
             "d_fin": Fixture.now.addingTimeInterval(3600).timeIntervalSince1970 * 1000],
            ["d_ini": "invalid"]
        ]])
        let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        #expect(report.expectedOccurrences == 2)
        #expect(report.mappedOccurrences == 1)
        #expect(!report.hasCompleteCoverage)
    }

    @Test func `Conflicting outer bounds preserve the gap between recurring windows`() throws {
        let firstStart = Fixture.now.addingTimeInterval(600)
        let firstEnd = firstStart.addingTimeInterval(3600)
        let secondStart = firstStart.addingTimeInterval(86400)
        let secondEnd = secondStart.addingTimeInterval(3600)
        let early = firstStart.addingTimeInterval(-600)
        let late = secondEnd.addingTimeInterval(600)
        let event = try Fixture.event([
            "d_sta": early.timeIntervalSince1970 * 1000, "d_sto": late.timeIntervalSince1970 * 1000,
            "indisponibilita": [
                ["d_ini": firstStart.timeIntervalSince1970 * 1000, "d_fin": firstEnd.timeIntervalSince1970 * 1000],
                ["d_ini": secondStart.timeIntervalSince1970 * 1000, "d_fin": secondEnd.timeIntervalSince1970 * 1000]
            ]
        ])
        let report = AutostradeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        #expect(report.closures.map(\.start) == [early, secondStart])
        #expect(report.closures.map(\.end) == [firstEnd, late])
        #expect(report.hasCompleteCoverage)
        #expect(!report.isComplete)
        #expect(report.issues.allSatisfy { $0.coveredByMappedWindow })
    }

    @Test func `Realtime end timestamps are UTC despite the published local offset`() throws {
        let event = try Fixture.event([
            "d_sta": Fixture.now.addingTimeInterval(-60).timeIntervalSince1970 * 1000,
            "fino_al": "202611060500P01:303"
        ])
        let report = AutostradeRealtimeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        #expect(report.closures.first?.end == Fixture.date("2026-11-06T05:00:00Z"))
        #expect(report.closures.first.map { ClosureFormat.timeLabel($0.end) } == "06:00")
    }

    @Test(arguments: [0.0, -1.0, 1_793_916_000.0, Double.infinity, Double.nan])
    func `Invalid or seconds based timestamps are rejected`(_ value: Double) {
        #expect(AutostradeClosureMapper.sanitizedDate(value) == nil)
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func `Nonfinite dates never depend on Foundation comparison behavior`(_ value: Double) {
        #expect(!AutostradeClosureMapper.isPlausibleDate(Date(timeIntervalSince1970: value)))
    }

    @Test func `Expired windows and unrelated roads are excluded`() throws {
        let expired = try Fixture.event([
            "d_sta": Fixture.now.addingTimeInterval(-600).timeIntervalSince1970 * 1000,
            "d_sto": Fixture.now.timeIntervalSince1970 * 1000
        ])
        let report = AutostradeClosureMapper.mappingReport(
            from: [expired, try Fixture.event(["c_str": "A1"])], now: Fixture.now
        )
        #expect(report.isComplete)
        #expect(report.expectedOccurrences == 0)
        #expect(report.closures.isEmpty)
    }

    @Test func `Both directions includes each carriageway but no nonexistent Italia 90 exit`() throws {
        let valid = AutostradeClosureMapper.mappingReport(
            from: [try Fixture.event(["c_dir": "B"])], now: Fixture.now
        )
        let closure = try #require(valid.closures.first)
        #expect(Direction.allCases.allSatisfy { closure.matches(direction: $0) })
        let invalid = AutostradeClosureMapper.mappingReport(
            from: [try Fixture.event(["locpri": "Italia 90", "t_des_fra_it": "Uscita Chiusa"])],
            now: Fixture.now
        )
        #expect(!invalid.hasCompleteCoverage)
        #expect(invalid.closures.isEmpty)
    }

    @Test func `Unknown live end stays visible without inventing a reopening time`() throws {
        let event = try Fixture.event(["c_ele": NSNull(), "d_sta": NSNull(), "d_sto": NSNull()])
        let first = AutostradeRealtimeClosureMapper.mappingReport(from: [event], now: Fixture.now)
        let second = AutostradeRealtimeClosureMapper.mappingReport(
            from: [event], now: Fixture.now.addingTimeInterval(60)
        )
        let closure = try #require(first.closures.first)
        #expect(first.isComplete)
        #expect(closure.hasUnpublishedEnd == true)
        #expect(closure.id == second.closures.first?.id)
        #expect(ClosureFormat.endLabel(closure) == "Fine non comunicata")
        #expect(closure.scheduleDays(notBefore: Fixture.now).isEmpty)
    }

    @Test func `Unreadable rows cannot silently establish complete coverage`() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let feed = try decoder.decode(AutostradeFeed.self, from: Data(#"{"events":[{"c_str":"A1"},{"road":"A56"},{"c_str":"A56","d_sta":"bad"},{"c_str":"A56"}]}"#.utf8))
        #expect(feed.events.count == 2)
        #expect(feed.undecodedEventCount == 2)
    }
}
