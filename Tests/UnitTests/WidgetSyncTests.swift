import Foundation
import Testing
@testable import TangenzialeNapoli

@Suite("App and widget shared snapshots")
struct WidgetSyncTests {
    private let verified = ClosureDataQuality(
        plannedFeedAvailable: true, realtimeFeedAvailable: true,
        expectedRecords: 0, mappedRecords: 0, unresolvedRecords: [], topologyIssues: []
    )

    private func snapshot(at date: Date, id: String = "shared", complete: Bool = true,
                          startedAt: Date? = nil) -> WidgetSnapshot {
        WidgetSnapshot(
            fetchedAt: date,
            closures: [Fixture.closure(id: id, start: date.addingTimeInterval(-60),
                                       end: date.addingTimeInterval(3600))],
            isComplete: complete, requestStartedAt: startedAt
        )
    }

    @Test func `App publishes to a different instance before requesting reload`() async throws {
        let temporary = try TemporaryArchive()
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        let reload = WidgetReloadRecorder()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {
            await reload.record(await reader.cached())
        })
        let input = snapshot(at: .now)
        #expect(await writer.publishFromApp(input))
        #expect(await reader.cached().closures == input.closures)
        #expect(await reload.snapshots.count == 1)
        #expect(await reload.snapshots.first?.fetchedAt == input.fetchedAt)
        #expect(await reload.snapshots.first?.closures == input.closures)
    }

    @Test(arguments: [true, false])
    func `A fresh app response avoids duplicate widget network and retains quality`(_ complete: Bool) async throws {
        let temporary = try TemporaryArchive()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let date = Date()
        #expect(await writer.publishFromApp(snapshot(at: date, complete: complete)))
        let network = StubProvider(nil)
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        let result = await reader.snapshotForTimeline(using: network, at: date.addingTimeInterval(1))
        #expect(result.status(at: date) == (complete ? .current : .partial))
        #expect(result.fetchedAt == date)
        #expect(await network.requests == 0)
    }

    @Test func `Older or equal app publications never replace newer data or request reload`() async throws {
        let temporary = try TemporaryArchive()
        let reload = WidgetReloadRecorder()
        let store = WidgetSnapshotStore(directory: temporary.directory, requestReload: {
            await reload.record(.unavailable)
        })
        let newest = snapshot(at: Fixture.now, id: "new")
        #expect(await store.publishFromApp(newest))
        #expect(!(await store.publishFromApp(snapshot(at: Fixture.now.addingTimeInterval(-10), id: "old"))))
        #expect(!(await store.publishFromApp(snapshot(at: Fixture.now, id: "equal"))))
        #expect(!(await store.publishFromApp(.unavailable)))
        #expect(await store.cached().closures == newest.closures)
        #expect(await reload.snapshots.count == 1)
    }

    @Test func `An old fetch completion cannot bury a more recent app publication`() async throws {
        let temporary = try TemporaryArchive()
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        let network = WidgetGatedProvider()
        let pending = Task { await reader.refresh(using: network) }
        await network.waitUntilStarted()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let new = snapshot(at: .now, id: "app-new")
        #expect(await writer.publishFromApp(new))
        await network.finish(ClosureFetchResult(
            closures: [Fixture.closure(id: "widget-old")], quality: verified,
            canInferCancellations: false
        ))
        let returned = await pending.value
        #expect(returned.closures == new.closures)
        #expect(await reader.cached().fetchedAt == new.fetchedAt)
        #expect(await reader.cached().closures == new.closures)
    }

    @Test func `Request start order also rejects late completion timestamps`() async throws {
        let temporary = try TemporaryArchive()
        let store = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let new = snapshot(at: Fixture.now, id: "new", startedAt: Fixture.now.addingTimeInterval(-10))
        #expect(await store.publishFromApp(new))
        let old = snapshot(at: Fixture.now.addingTimeInterval(30), id: "late-old",
                           startedAt: Fixture.now.addingTimeInterval(-20))
        #expect(!(await store.publishFromApp(old)))
        #expect(await store.cached().closures == new.closures)
    }

    @Test func `An app request begun before a newer widget request cannot replace its result`() async throws {
        let temporary = try TemporaryArchive()
        let widget = WidgetSnapshotStore(directory: temporary.directory, clock: { Fixture.now })
        let response = await widget.refresh(using: StubProvider([Fixture.closure(id: "widget-new")], quality: verified))
        #expect(response.requestStartedAt == Fixture.now)
        let app = WidgetSnapshotStore(directory: temporary.directory,
                                      clock: { Fixture.now.addingTimeInterval(60) }, requestReload: {})
        let lateApp = snapshot(at: Fixture.now.addingTimeInterval(30), id: "app-old",
                               startedAt: Fixture.now.addingTimeInterval(-60))
        #expect(!(await app.publishFromApp(lateApp)))
        #expect(await app.cached().closures == response.closures)
        #expect(await app.cached().fetchedAt == response.fetchedAt)
    }

    @Test func `Independent writers serialize compare and atomic replace`() async throws {
        let temporary = try TemporaryArchive()
        let snapshots = (0..<24).map { snapshot(at: Fixture.now.addingTimeInterval(Double($0)), id: "\($0)") }
        await withTaskGroup(of: Void.self) { group in
            for input in snapshots.reversed() {
                group.addTask {
                    let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
                    await writer.publishFromApp(input)
                }
            }
        }
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        #expect(await reader.cached().fetchedAt == snapshots.last?.fetchedAt)
        #expect(await reader.cached().closures == snapshots.last?.closures)
    }

    @Test func `Offline widget uses shared app data without marking it fresh`() async throws {
        let temporary = try TemporaryArchive()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let input = snapshot(at: Date().addingTimeInterval(-301), complete: false)
        #expect(await writer.publishFromApp(input))
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        let network = StubProvider(nil)
        let result = await reader.snapshotForTimeline(using: network)
        #expect(await network.requests == 1)
        #expect(result.status(at: .now) == .offline)
        #expect(result.fetchedAt == input.fetchedAt)
        #expect(result.closures == input.closures)
        #expect(!result.isComplete)
        // Failed network attempts don't overwrite a successful shared response.
        #expect(await writer.cached().isOffline == false)
    }

    @Test func `A failed in-flight widget request does not label a new app response offline`() async throws {
        let temporary = try TemporaryArchive()
        let reader = WidgetSnapshotStore(directory: temporary.directory)
        let network = WidgetGatedProvider()
        let pending = Task { await reader.refresh(using: network) }
        await network.waitUntilStarted()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let new = snapshot(at: .now)
        #expect(await writer.publishFromApp(new))
        await network.fail()
        let returned = await pending.value
        #expect(returned.status(at: .now) == .current)
        #expect(returned.fetchedAt == new.fetchedAt)
    }

    @Test func `Widget first launch fetches autonomously and shares its result`() async throws {
        let temporary = try TemporaryArchive()
        let widget = WidgetSnapshotStore(directory: temporary.directory)
        let network = StubProvider([Fixture.closure(start: .now, end: Date().addingTimeInterval(3600))], quality: verified)
        let result = await widget.snapshotForTimeline(using: network)
        #expect(result.status(at: .now) == .current)
        #expect(await network.requests == 1)
        let other = WidgetSnapshotStore(directory: temporary.directory)
        #expect(await other.cached().fetchedAt == result.fetchedAt)
        #expect(await other.cached().closures == result.closures)
        let second = await other.snapshotForTimeline(using: network)
        #expect(second.fetchedAt == result.fetchedAt)
        #expect(await network.requests == 1)
    }

    @Test func `First launch offline is unavailable`() async throws {
        let temporary = try TemporaryArchive()
        let store = WidgetSnapshotStore(directory: temporary.directory)
        let result = await store.snapshotForTimeline(using: StubProvider(nil))
        #expect(result.status(at: .now) == .unavailable)
        #expect(result.fetchedAt == nil)
    }

    @Test func `Shared cache excludes past notices and does not become another history archive`() async throws {
        let temporary = try TemporaryArchive()
        let store = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let current = snapshot(at: Fixture.now)
        let past = Fixture.closure(id: "past", start: Fixture.now.addingTimeInterval(-600), end: Fixture.now)
        #expect(await store.publishFromApp(WidgetSnapshot(
            fetchedAt: Fixture.now, closures: current.closures + [past], isComplete: true
        )))
        #expect(await store.cached().closures == current.closures)
    }

    @Test func `Migration imports the latest legacy copy and deletes both obsolete widget files`() async throws {
        let legacy = try TemporaryArchive()
        let shared = try TemporaryArchive()
        let input = snapshot(at: Fixture.now)
        try JSONEncoder().encode(input).write(to: legacy.directory.appendingPathComponent("a56_widget_snapshot.json"))
        try JSONEncoder().encode(ArchivedClosures(lastFetchedAt: Fixture.now.addingTimeInterval(-60), closures: []))
            .write(to: legacy.directory.appendingPathComponent("a56_widget_archive.json"))
        let store = WidgetSnapshotStore(directory: shared.directory, legacyDirectory: legacy.directory)
        #expect(await store.cached().closures == input.closures)
        #expect(!FileManager.default.fileExists(atPath: legacy.directory.appendingPathComponent("a56_widget_snapshot.json").path))
        #expect(!FileManager.default.fileExists(atPath: legacy.directory.appendingPathComponent("a56_widget_archive.json").path))
        #expect(FileManager.default.fileExists(atPath: shared.directory.appendingPathComponent("a56_widget_snapshot.json").path))
    }

    @Test func `Legacy archive-only migration remains partial and cannot overwrite a newer shared response`() async throws {
        let legacy = try TemporaryArchive()
        let shared = try TemporaryArchive()
        try JSONEncoder().encode(ArchivedClosures(lastFetchedAt: Fixture.now, closures: snapshot(at: Fixture.now).closures))
            .write(to: legacy.directory.appendingPathComponent("a56_widget_archive.json"))
        let store = WidgetSnapshotStore(directory: shared.directory, legacyDirectory: legacy.directory, requestReload: {})
        #expect(await store.cached().status(at: Fixture.now) == .partial)
        let new = snapshot(at: Fixture.now.addingTimeInterval(60), id: "new")
        #expect(await store.publishFromApp(new))
        try JSONEncoder().encode(snapshot(at: Fixture.now, id: "obsolete"))
            .write(to: legacy.directory.appendingPathComponent("a56_widget_snapshot.json"))
        #expect(await store.cached().closures == new.closures)
    }

    @Test func `Widget merge retains active notices but accepts verified future cancellations`() async throws {
        let temporary = try TemporaryArchive()
        let writer = WidgetSnapshotStore(directory: temporary.directory, requestReload: {})
        let date = Date().addingTimeInterval(-301)
        let active = Fixture.closure(id: "active", start: date.addingTimeInterval(-60), end: Date().addingTimeInterval(3600))
        let future = Fixture.closure(id: "future", start: Date().addingTimeInterval(3600), end: Date().addingTimeInterval(7200))
        #expect(await writer.publishFromApp(WidgetSnapshot(fetchedAt: date, closures: [active, future], isComplete: true)))
        let widget = WidgetSnapshotStore(directory: temporary.directory)
        let provider = WidgetFixedProvider(result: ClosureFetchResult(
            closures: [], quality: verified, canInferCancellations: true
        ))
        let result = await widget.snapshotForTimeline(using: provider)
        #expect(result.closures == [active])
    }

    @Test func `A future-dated cache cannot block app updates after the clock is corrected`() async throws {
        let temporary = try TemporaryArchive()
        let future = snapshot(at: Fixture.now.addingTimeInterval(86400), id: "clock-was-wrong")
        try JSONEncoder().encode(future).write(to: temporary.directory.appendingPathComponent("a56_widget_snapshot.json"))
        let store = WidgetSnapshotStore(directory: temporary.directory, clock: { Fixture.now }, requestReload: {})
        let corrected = snapshot(at: Fixture.now, id: "correct-clock")
        #expect(await store.publishFromApp(corrected))
        #expect(await store.cached().closures == corrected.closures)
    }

    @Test func `A future-dated cache does not suppress autonomous widget network`() async throws {
        let temporary = try TemporaryArchive()
        try JSONEncoder().encode(snapshot(at: Fixture.now.addingTimeInterval(86400)))
            .write(to: temporary.directory.appendingPathComponent("a56_widget_snapshot.json"))
        let store = WidgetSnapshotStore(directory: temporary.directory, clock: { Fixture.now })
        let network = StubProvider([Fixture.closure()], quality: verified)
        let result = await store.snapshotForTimeline(using: network)
        #expect(await network.requests == 1)
        #expect(result.fetchedAt == Fixture.now)
        #expect(result.status(at: Fixture.now) == .current)
        #expect(result.closures == [Fixture.closure()])
    }

    @Test func `A disk failure does not hide a successfully fetched widget response`() async throws {
        let temporary = try TemporaryArchive()
        let invalid = temporary.directory.appendingPathComponent("not-a-directory")
        try Data().write(to: invalid)
        let store = WidgetSnapshotStore(directory: invalid, clock: { Fixture.now })
        let network = StubProvider([Fixture.closure()], quality: verified)
        let response = await store.refresh(using: network)
        #expect(response.closures == [Fixture.closure()])
        #expect(response.status(at: Fixture.now) == .current)
    }

    @Test func `Failed disk publication never requests a reload`() async throws {
        let temporary = try TemporaryArchive()
        let invalid = temporary.directory.appendingPathComponent("file-not-directory")
        try Data().write(to: invalid)
        let reload = WidgetReloadRecorder()
        let store = WidgetSnapshotStore(directory: invalid, requestReload: { await reload.record(.unavailable) })
        #expect(!(await store.publishFromApp(snapshot(at: .now))))
        #expect(await reload.snapshots.isEmpty)
    }
}

private actor WidgetReloadRecorder {
    private(set) var snapshots: [WidgetSnapshot] = []
    func record(_ snapshot: WidgetSnapshot) { snapshots.append(snapshot) }
}

private struct WidgetFixedProvider: ClosureProvider {
    let result: ClosureFetchResult
    func fetchClosures() async throws -> ClosureFetchResult { result }
}

private actor WidgetGatedProvider: ClosureProvider {
    private var hasStarted = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var pending: CheckedContinuation<ClosureFetchResult, any Error>?

    func fetchClosures() async throws -> ClosureFetchResult {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            hasStarted = true
            waiters.forEach { $0.resume() }
            waiters = []
        }
    }
    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func finish(_ result: ClosureFetchResult) { pending?.resume(returning: result); pending = nil }
    func fail() { pending?.resume(throwing: URLError(.notConnectedToInternet)); pending = nil }
}
