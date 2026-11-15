import Foundation
import Testing
@testable import TangenzialeNapoli

@Suite("Naples time and freshness")
struct TimeAndFreshnessTests {
    @Test(arguments: [
        ("2026-01-05T22:30:00Z", "23:30"), ("2026-07-05T21:30:00Z", "23:30"),
        ("2026-03-29T00:30:00Z", "01:30"), ("2026-03-29T01:30:00Z", "03:30"),
        ("2026-10-25T00:30:00Z", "02:30"), ("2026-10-25T01:30:00Z", "02:30")
    ])
    func `Naples clock follows daylight saving transitions`(_ instant: String, _ label: String) {
        #expect(ClosureFormat.timeLabel(Fixture.date(instant)) == label)
        #expect(ClosureFormat.calendar.timeZone.identifier == "Europe/Rome")
    }

    @Test(arguments: ["31/02/2026", "29/02/2026", "32/11/2026"])
    func `Impossible notice dates are rejected`(_ date: String) {
        #expect(NoticeText.endDate(in: "fino alle 06:00 del \(date)") == nil)
    }

    @Test func `Midnight and overnight labels use the Naples calendar`() {
        #expect(NoticeText.endDate(in: "fino alle ore 24,00 del 5/11/2026")
                == Fixture.date("2026-11-05T23:00:00Z"))
        let closure = Fixture.closure(
            start: Fixture.date("2026-03-28T22:00:00Z"),
            end: Fixture.date("2026-03-29T04:00:00Z")
        )
        #expect(ClosureFormat.timeRange(closure) == "23:00 – 06:00 (+1)")
        #expect(closure.scheduleDays(notBefore: closure.start).count == 1)
        #expect(ClosureFormat.relativeDayName(closure.end, reference: closure.start) == "Domani")
    }

    @MainActor @Test func `Freshness expires exactly at five minutes and after clock rollback`() async throws {
        let temporary = try TemporaryArchive()
        let provider = StubProvider()
        var now = Fixture.now
        let model = ClosuresViewModel(provider: provider, archive: temporary.archive, clock: { now })
        await model.load()
        #expect(model.freshness == .fresh(Fixture.now))
        now = Fixture.now.addingTimeInterval(ClosuresViewModel.freshnessLimit - 0.001)
        model.refreshNow()
        #expect(!model.dataNeedsVerification)
        now = Fixture.now.addingTimeInterval(ClosuresViewModel.freshnessLimit)
        model.refreshNow()
        #expect(model.freshness == .expired(Fixture.now))
        now = Fixture.now.addingTimeInterval(-1)
        model.refreshNow()
        #expect(model.freshness == .expired(Fixture.now))
    }

    @MainActor @Test func `Foreground refresh throttles and revalidates on expiry`() async throws {
        let temporary = try TemporaryArchive()
        let provider = StubProvider()
        var now = Fixture.now
        let model = ClosuresViewModel(provider: provider, archive: temporary.archive, clock: { now })
        await model.load()
        now += 299
        await model.refreshIfStale()
        #expect(await provider.requests == 1)
        now += 1
        await model.refreshIfStale()
        #expect(await provider.requests == 2)
        #expect(model.freshness == .fresh(now))
    }

    @MainActor @Test func `Active intervals include start and exclude end`() async throws {
        let temporary = try TemporaryArchive()
        let closure = Fixture.closure(start: Fixture.now, end: Fixture.now.addingTimeInterval(60), both: true)
        var now = Fixture.now.addingTimeInterval(-1)
        let model = ClosuresViewModel(provider: StubProvider([closure]), archive: temporary.archive, clock: { now })
        await model.load()
        #expect(model.activeClosures(for: .towardPozzuoli).isEmpty)
        now += 1
        model.refreshNow()
        #expect(model.activeClosures(for: .towardPozzuoli) == [closure])
        #expect(model.activeClosures(for: .towardCapodichino) == [closure])
        now += 60
        model.refreshNow()
        #expect(model.activeClosures(for: .towardPozzuoli).isEmpty)
        #expect(model.pastDays(for: .towardPozzuoli).first?.roadBlocks == [closure])
    }
}
