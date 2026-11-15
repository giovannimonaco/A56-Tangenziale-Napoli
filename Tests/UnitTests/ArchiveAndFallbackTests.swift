import Foundation
import MapKit
import Testing
@testable import TangenzialeNapoli

@Suite("Archive persistence and fallback")
struct ArchiveAndFallbackTests {
    @Test func `Archive survives a new actor and clearing is idempotent`() async throws {
        let temporary = try TemporaryArchive()
        let closure = Fixture.closure()
        await temporary.archive.record([closure], now: Fixture.now)
        let reopened = ClosureArchive(fileURL: temporary.url)
        let payload = try #require(await reopened.snapshot(at: Fixture.now))
        #expect(payload.schemaVersion == 3)
        #expect(payload.lastFetchedAt == Fixture.now)
        #expect(payload.closures == [closure])
        try await reopened.clear()
        try await reopened.clear()
        #expect(await reopened.load() == nil)
    }

    @Test func `Corrupt and missing files produce no fabricated archive`() async throws {
        let temporary = try TemporaryArchive()
        #expect(await temporary.archive.load() == nil)
        try Data("{broken".utf8).write(to: temporary.url)
        #expect(await temporary.archive.snapshot(at: Fixture.now) == nil)
        await temporary.archive.record([Fixture.closure()], now: Fixture.now)
        #expect(await temporary.archive.load()?.closures.count == 1)
    }

    @Test func `Legacy coordinates migrate once and original notice text is removed`() async throws {
        let temporary = try TemporaryArchive()
        let old = RoadClosure(id: "legacy", start: Fixture.now, end: Fixture.now.addingTimeInterval(3600),
                              direction: .towardPozzuoli, fromExit: 11, toExit: 14,
                              reason: "Lavori", suggestedAlternatives: [10, 12], isFullClosure: true)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(
            ArchivedClosures(schemaVersion: 1, lastFetchedAt: Fixture.now, closures: [old])
        )) as? [String: Any])
        var rows = try #require(json["closures"] as? [[String: Any]])
        rows[0]["sourceText"] = "Testo ufficiale legacy"
        json["closures"] = rows
        try JSONSerialization.data(withJSONObject: json).write(to: temporary.url)
        let first = try #require(await temporary.archive.load())
        let second = try #require(await temporary.archive.load())
        #expect(first.schemaVersion == 3)
        #expect(first.closures.first?.fromExit == 12)
        #expect(first.closures.first?.toExit == 15)
        #expect(first.closures.first?.suggestedAlternatives == [10, 13])
        #expect(first.closures == second.closures)
        #expect(!String(decoding: try Data(contentsOf: temporary.url), as: UTF8.self).contains("sourceText"))
    }

    @Test func `Only verified schedule omissions cancel future notices`() async throws {
        let temporary = try TemporaryArchive()
        let active = Fixture.closure(id: "active")
        let future = Fixture.closure(id: "future", start: Fixture.now.addingTimeInterval(60))
        await temporary.archive.record([future, active], now: Fixture.now)
        let partial = await temporary.archive.record([], now: Fixture.now, canInferCancellations: false)
        #expect(Set(partial.map(\.id)) == ["active", "future"])
        let verified = await temporary.archive.record([], now: Fixture.now, canInferCancellations: true)
        #expect(verified == [active])
    }

    @Test func `Only verified live omissions can end an active live notice`() async throws {
        let temporary = try TemporaryArchive()
        let live = Fixture.closure(evidence: .realtime)
        await temporary.archive.record([live], now: Fixture.now)
        let partial = await temporary.archive.record([], now: Fixture.now, canRevalidateActive: false)
        #expect(partial == [live])
        let verified = await temporary.archive.record([], now: Fixture.now, canRevalidateActive: true)
        #expect(verified.first?.end == Fixture.now)
    }

    @Test func `Repeated observations keep one persistent occurrence`() async throws {
        let temporary = try TemporaryArchive()
        let closure = Fixture.closure()
        for offset in 0..<3 {
            let records = await temporary.archive.record([closure], now: Fixture.now.addingTimeInterval(Double(offset)))
            #expect(records == [closure])
        }
    }

    @MainActor @Test func `Offline load restores saved notices and reports their age`() async throws {
        let temporary = try TemporaryArchive()
        let closure = Fixture.closure()
        await temporary.archive.record([closure], now: Fixture.now)
        let model = ClosuresViewModel(provider: StubProvider(nil), archive: temporary.archive,
                                      clock: { Fixture.now.addingTimeInterval(120) })
        await model.load()
        #expect(model.freshness == .cache(Fixture.now))
        #expect(model.dataNeedsVerification)
        #expect(model.activeClosures(for: .towardPozzuoli) == [closure])
        #expect(model.freshness?.updateLabel(reference: Fixture.now).contains("23:00") == true)
    }

    @MainActor @Test func `Offline first launch remains explicitly unavailable`() async throws {
        let temporary = try TemporaryArchive()
        let model = ClosuresViewModel(provider: StubProvider(nil), archive: temporary.archive,
                                      clock: { Fixture.now })
        await model.load()
        #expect(model.freshness == .unavailable)
        #expect(model.closures.isEmpty)
        #expect(model.dataNeedsVerification)
        #expect(!model.isLoading)
    }

    @MainActor @Test func `Network failure after successful load keeps last saved data`() async throws {
        let temporary = try TemporaryArchive()
        let provider = StubProvider([Fixture.closure()])
        let model = ClosuresViewModel(provider: provider, archive: temporary.archive, clock: { Fixture.now })
        await model.load()
        await provider.goOffline()
        await model.load()
        #expect(model.closures == [Fixture.closure()])
        #expect(model.freshness == .cache(Fixture.now))
        #expect(await model.clearLocalArchive())
        #expect(await temporary.archive.load() == nil)
        #expect(model.archivedClosures.isEmpty)
    }

    @MainActor @Test func `Favorite round trip preserves location and identity`() throws {
        let place = TripPlanner.Place(name: "Casa", subtitle: "Napoli",
                                      location: CLLocation(latitude: 40.85, longitude: 14.25))
        let favorite = TripFavorite(place: place)
        let decoded = try JSONDecoder().decode(TripFavorite.self, from: JSONEncoder().encode(favorite))
        #expect(decoded.id == favorite.id)
        #expect(decoded.matches(place))
        #expect(decoded.place.coordinate.latitude == place.coordinate.latitude)
        #expect(!decoded.matches(TripPlanner.Place(name: "Casa", subtitle: "Napoli",
                                                   location: CLLocation(latitude: 40.86, longitude: 14.25))))
    }
}

/// This suite alone modifies the archive preference, restoring it after each case.
@Suite("Archive retention settings", .serialized)
struct ArchiveRetentionTests {
    @Test(arguments: [(-1, 1), (100, 60), (3, 3)])
    func `Retention clamps settings and includes the cutoff`(_ setting: Int, _ expectedDays: Int) async throws {
        let previous = UserDefaults.standard.object(forKey: ClosureArchive.retentionKey)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: ClosureArchive.retentionKey) }
            else { UserDefaults.standard.removeObject(forKey: ClosureArchive.retentionKey) }
        }
        UserDefaults.standard.set(setting, forKey: ClosureArchive.retentionKey)
        let temporary = try TemporaryArchive()
        let cutoff = Fixture.now.addingTimeInterval(-Double(expectedDays) * 86400)
        let records = [
            Fixture.closure(id: "boundary", start: cutoff.addingTimeInterval(-60), end: cutoff),
            Fixture.closure(id: "expired", start: cutoff.addingTimeInterval(-60), end: cutoff.addingTimeInterval(-1))
        ]
        let retained = await temporary.archive.record(records, now: Fixture.now)
        #expect(retained.map(\.id) == ["boundary"])
        #expect(await temporary.archive.reprune(now: Fixture.now.addingTimeInterval(1)) == [])
    }
}
