import Foundation
import Testing
@testable import TangenzialeNapoli

@Suite("Independent widget snapshots")
struct WidgetSnapshotTests {
    private let verified = ClosureDataQuality(
        plannedFeedAvailable: true, realtimeFeedAvailable: true,
        expectedRecords: 0, mappedRecords: 0, unresolvedRecords: [], topologyIssues: []
    )

    @Test(arguments: [(-1.0, WidgetSnapshot.Status.stale), (0, .current), (299.999, .current), (300, .stale)])
    func `Snapshot expires exactly at five minutes`(_ elapsed: Double, _ status: WidgetSnapshot.Status) {
        let snapshot = WidgetSnapshot(fetchedAt: Fixture.now, closures: [], isComplete: true)
        #expect(snapshot.status(at: Fixture.now.addingTimeInterval(elapsed)) == status)
    }

    @Test func `Partial offline and unavailable states retain their meaning`() {
        let partial = WidgetSnapshot(fetchedAt: Fixture.now, closures: [], isComplete: false)
        #expect(partial.status(at: Fixture.now) == .partial)
        #expect(partial.status(at: Fixture.now.addingTimeInterval(300)) == .stale)
        let offline = WidgetSnapshot(fetchedAt: Fixture.now, closures: [], isComplete: true, isOffline: true)
        #expect(offline.status(at: Fixture.now) == .offline)
        #expect(offline.status(at: Fixture.now.addingTimeInterval(3600)) == .offline)
        #expect(WidgetSnapshot.unavailable.status(at: Fixture.now) == .unavailable)
    }

    @Test func `Each direction counts active notices and chooses the earliest future notice`() {
        let active = Fixture.closure()
        let opposite = Fixture.closure(id: "opposite", direction: .towardCapodichino)
        let both = Fixture.closure(id: "both", both: true)
        let ended = Fixture.closure(id: "ended", end: Fixture.now)
        let future = Fixture.closure(id: "a", start: Fixture.now.addingTimeInterval(10))
        let tied = Fixture.closure(id: "b", start: future.start)
        let later = Fixture.closure(id: "later", start: Fixture.now.addingTimeInterval(20))
        let snapshot = WidgetSnapshot(fetchedAt: Fixture.now,
            closures: [later, tied, future, ended, opposite, both, active], isComplete: true)
        let west = snapshot.summary(for: .towardPozzuoli, at: Fixture.now)
        let east = snapshot.summary(for: .towardCapodichino, at: Fixture.now)
        #expect(west.activeCount == 2)
        #expect(west.nextClosure?.id == "a")
        #expect(east.activeCount == 2)
        #expect(east.nextClosure == nil)
    }

    @Test func `Timeline includes expiry and transitions with sorted unique dates`() {
        let closure = Fixture.closure(start: Fixture.now.addingTimeInterval(60),
                                      end: Fixture.now.addingTimeInterval(120))
        let beyond = Fixture.closure(id: "beyond", start: Fixture.now.addingTimeInterval(86401),
                                     end: Fixture.now.addingTimeInterval(86500))
        let snapshot = WidgetSnapshot(fetchedAt: Fixture.now, closures: [closure, closure, beyond], isComplete: true)
        let dates = snapshot.timelineDates(from: Fixture.now)
        #expect(dates == [Fixture.now, closure.start, closure.end, Fixture.now.addingTimeInterval(300)])
        #expect(snapshot.status(at: dates.last!) == .stale)
    }

    @Test func `Timeline caps entries and does not reschedule expired freshness`() {
        let many = (1...70).map { index in
            Fixture.closure(id: "\(index)", start: Fixture.now.addingTimeInterval(Double(index * 10)),
                            end: Fixture.now.addingTimeInterval(Double(index * 10 + 1)))
        }
        let snapshot = WidgetSnapshot(fetchedAt: Fixture.now.addingTimeInterval(-300),
                                      closures: many, isComplete: true)
        let dates = snapshot.timelineDates(from: Fixture.now)
        #expect(dates.count == 48)
        #expect(dates.first == Fixture.now)
        #expect(dates == dates.sorted())
        #expect(snapshot.status(at: dates.last!) == .stale)
    }

    @Test func `Dense transitions cannot displace the freshness expiry entry`() {
        let many = (1...70).map { index in
            Fixture.closure(id: "\(index)", start: Fixture.now.addingTimeInterval(Double(index)),
                            end: Fixture.now.addingTimeInterval(Double(index) + 0.5))
        }
        let snapshot = WidgetSnapshot(fetchedAt: Fixture.now, closures: many, isComplete: true)
        let dates = snapshot.timelineDates(from: Fixture.now)
        #expect(dates.count == 48)
        #expect(dates.contains(Fixture.now.addingTimeInterval(300)))
        #expect(snapshot.status(at: dates.last!) == .stale)
    }

    @Test func `Store independently fetches persists and restores an offline snapshot`() async throws {
        let temporary = try TemporaryArchive()
        let store = WidgetSnapshotStore(directory: temporary.directory)
        #expect(await store.cached().fetchedAt == nil)
        let now = Date()
        let closure = Fixture.closure(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(3600))
        let provider = StubProvider([closure], quality: verified)
        let online = await store.refresh(using: provider)
        let fetchedAt = try #require(online.fetchedAt)
        #expect(online.status(at: fetchedAt) == .current)
        #expect(online.closures == [closure])
        #expect(await provider.requests == 1)
        let reopened = WidgetSnapshotStore(directory: temporary.directory)
        #expect(await reopened.cached().closures == [closure])
        let offline = await reopened.refresh(using: StubProvider(nil))
        #expect(offline.fetchedAt == fetchedAt)
        #expect(offline.closures == online.closures)
        #expect(offline.status(at: fetchedAt) == .offline)
    }

    @Test func `Store never calls an incomplete response current`() async throws {
        let temporary = try TemporaryArchive()
        let snapshot = await WidgetSnapshotStore(directory: temporary.directory).refresh(using: StubProvider())
        let date = try #require(snapshot.fetchedAt)
        #expect(snapshot.status(at: date) == .partial)
    }

    @Test func `Store handles first launch offline and corrupt files`() async throws {
        let temporary = try TemporaryArchive()
        let store = WidgetSnapshotStore(directory: temporary.directory)
        let first = await store.refresh(using: StubProvider(nil))
        #expect(first.status(at: .now) == .unavailable)
        let url = temporary.directory.appendingPathComponent("a56_widget_snapshot.json")
        try Data("invalid".utf8).write(to: url)
        #expect(await store.cached().status(at: .now) == .unavailable)
    }
}
