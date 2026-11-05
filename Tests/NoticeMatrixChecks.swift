import Foundation

enum NoticeMatrixChecks {
    static func run() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let iso = ISO8601DateFormatter()
        let now = iso.date(from: "2026-11-05T12:00:00Z")!
        let start = iso.date(from: "2026-11-05T22:59:00Z")!
        let printedEnd = iso.date(from: "2026-11-06T05:00:00Z")!
        let windowEnd = iso.date(from: "2026-11-06T05:59:00Z")!
        let secondStart = start.addingTimeInterval(86400)
        let secondEnd = printedEnd.addingTimeInterval(86400)
        func ms(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }
        let fields: [String: Any] = [
            "c_ele": "test-ramp", "c_str": "A56", "c_grp_tip": "C", "c_dir": "N",
            "t_des_fra_it": "Entrata Chiusa", "locpri": "Agnano", "c_pnt_dtx_pls_pri": 1133,
            "d_sta": ms(start), "d_sto": ms(printedEnd),
            "t_des_it": "Agnano in entrata è chiuso dalle 23:59 alle 06:00 dal giorno 05/11/2026 al giorno 06/11/2026 verso Pozzuoli. Entrata consigliata verso Pozzuoli: S.S. Domitiana."
        ]
        func event(_ changes: [String: Any]) throws -> AutostradeEvent {
            let row = fields.merging(changes) { _, value in value }
            return try decoder.decode(AutostradeEvent.self, from: JSONSerialization.data(withJSONObject: row))
        }
        func planned(_ changes: [String: Any]) throws -> AutostradeClosureMapper.MappingReport {
            AutostradeClosureMapper.mappingReport(from: [try event(changes)], now: now)
        }

        let conflict = try planned(["indisponibilita": [["d_ini": ms(start), "d_fin": ms(windowEnd)]]])
        guard let ramp = conflict.closures.first else { preconditionFailure("Missing discordant notice") }
        precondition(!conflict.isComplete && ramp.end == windowEnd && ramp.reportedWindow?.end == printedEnd)
        precondition(ClosureFormat.timeRange(ramp).contains("da verificare") && ramp.reason.isEmpty)
        precondition(ramp.alternativeSuggestions?.first?.externalPlace == "SS Domitiana")
        precondition(ramp.alternativeSuggestions?.first?.direction == .towardPozzuoli)
        let badDirection = try planned(["c_dir": "P"])
        let badExit = try planned(["locpri": "Camaldoli", "c_pnt_dtx_pls_pri": 1126])
        precondition([badDirection, badExit].allSatisfy { !$0.isComplete && $0.closures.isEmpty })
        let both = try planned([
            "c_dir": "B", "t_des_dir_it": "in entrambe le direzioni",
            "t_des_fra_it": "Entrata e Uscita Chiuse", "t_des_it": "Svincolo Agnano in entrambe le direzioni."
        ])
        precondition(both.isComplete && both.closures.first?.closedRamps.count == 2)
        precondition(both.closures.first?.matches(direction: .towardCapodichino) == true)

        let italia90Fields: [String: Any] = [
            "c_dir": "B", "t_des_dir_it": "in entrambe le direzioni",
            "locpri": "Italia 90", "c_pnt_dtx_pls_pri": 11221,
            "t_des_it": "Italia 90 in entrata è chiuso in entrambe le direzioni per lavori."
        ]
        let italia90 = try planned(italia90Fields)
        guard let entrance = italia90.closures.first else { preconditionFailure("Missing Italia 90 entrance") }
        precondition(italia90.isComplete && entrance.headline == "Entrata chiusa")
        precondition(Direction.allCases.allSatisfy {
            entrance.matches(direction: $0) && entrance.closedRamps(for: $0).map(\.kind) == [.entrance]
        })
        precondition(A56Line.interchangeLabel(for: entrance.rampExitNumber) == "Ingresso Italia ’90")
        let invalidExitFields = italia90Fields.merging(["t_des_fra_it": "Uscita Chiusa"]) { _, new in new }
        let invalidExit = try planned(invalidExitFields)
        precondition(!invalidExit.isComplete && invalidExit.closures.isEmpty)
        let liveItalia90 = AutostradeRealtimeClosureMapper.mappingReport(
            from: [try event(italia90Fields)], now: start.addingTimeInterval(60)
        )
        precondition(liveItalia90.isComplete && liveItalia90.closures.first?.closedRamps.map(\.kind) == [.entrance])
        precondition(NoticeText.suggestions(in: "Uscita consigliata: Italia ’90.").isEmpty)
        precondition(NoticeText.suggestions(in: "Entrata consigliata: Italia ’90.").first?.label == "Ingresso Italia ’90")

        let connector = try planned(["t_des_fra_it": "Allacciamento Chiuso"])
        let service = try planned(["c_grp_tip": "D", "t_des_fra_it": "Area di Servizio Chiusa"])
        precondition(!connector.isComplete && connector.closures.isEmpty && service.isComplete && service.closures.isEmpty)
        precondition(NoticeText.suggestions(in: "Uscita consigliata verso una località sconosciuta: Agnano.").isEmpty)
        precondition(NoticeText.suggestions(in: "Entrata consigliata verso Pozzuoli: via Agnano agli Astroni.").isEmpty)
        precondition(A56Line.resolveExit(named: "Capodichino/Aeroporto") == 1)
        precondition(A56Line.resolveExit(named: "Secondigliano") == 2)
        precondition(A56Line.resolveExit(named: "Capodichino") == nil)
        precondition(NoticeText.endDate(in: "fino alle 06:00 del 31/02/2026") == nil)
        precondition(NoticeText.endDate(in: "fino alle ore 24,00 del 5/11/2026") == iso.date(from: "2026-11-05T23:00:00Z"))

        let repeated = try planned([
            "d_sto": ms(secondEnd),
            "t_des_it": "Agnano in entrata è chiuso dalle 23:59 alle 06:00 dal giorno 05/11/2026 al giorno 07/11/2026 verso Pozzuoli.",
            "indisponibilita": [
                ["d_ini": ms(start), "d_fin": ms(printedEnd)],
                ["d_ini": ms(secondStart), "d_fin": ms(secondEnd)]
            ]
        ])
        precondition(repeated.isComplete && repeated.closures.count == 2)
        let unboundedRecurrence = try planned(["t_des_it": "Chiusura ogni notte", "d_sto": ms(secondEnd)])
        precondition(!unboundedRecurrence.isComplete && unboundedRecurrence.closures.isEmpty)
        let overlap = RoadClosure(start: start.addingTimeInterval(60), end: printedEnd, direction: .towardPozzuoli,
                                  fromExit: 10, toExit: 12, reason: "", isFullClosure: true, evidence: .scheduled)
        let slices = ClosureMatching.scheduleSlices(repeated.closures + [overlap], direction: .towardPozzuoli, now: now)
        precondition(slices.map { $0.closures.count } == [1, 2, 1])
        precondition(slices[1].end == printedEnd && slices[2].start == secondStart)

        let activeNow = start.addingTimeInterval(120)
        let activeFields: [String: Any] = [
            "c_ele": "test-live", "d_sta": NSNull(), "d_sto": NSNull(), "d_agg": ms(start),
            "t_des_it": "Agnano in entrata è chiuso verso Pozzuoli."
        ]
        let realtime = AutostradeRealtimeClosureMapper.mappingReport(from: [try event(activeFields)], now: activeNow)
        guard let live = realtime.closures.first else { preconditionFailure("Missing live closure with unknown end") }
        precondition(realtime.isComplete && ClosureFormat.endLabel(live) == "Fine non comunicata")
        precondition(live.scheduleDays(notBefore: activeNow).isEmpty)
        let contradictoryFields = activeFields.merging([
            "fino_al": "202611060559P01:303",
            "t_des_it": "Agnano in entrata è chiuso fino alle 06:00 del 06/11/2026 verso Pozzuoli."
        ]) { _, update in update }
        let liveConflict = AutostradeRealtimeClosureMapper.mappingReport(from: [try event(contradictoryFields)], now: activeNow)
        precondition(!liveConflict.isComplete && liveConflict.closures.first?.end == windowEnd)
        precondition(liveConflict.closures.first?.reportedWindow?.end == printedEnd)

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("a56-notices-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let archive = ClosureArchive(fileURL: file)
        _ = await archive.record(repeated.closures, now: now)
        let retained = await archive.record([live], now: activeNow, canInferCancellations: false)
        precondition(retained.count == 2 && retained.contains { $0.start == secondStart && $0.end == secondEnd })
        precondition(retained.contains { $0.evidence == .realtimeConfirmed && $0.hasUnpublishedEnd == true })
        let stillActive = await archive.record([live], now: activeNow.addingTimeInterval(60), canInferCancellations: false)
        precondition(stillActive.count == 2 && stillActive.filter { $0.hasUnpublishedEnd == true }.count == 1)
        let endedAt = printedEnd.addingTimeInterval(60)
        let ended = await archive.record([], now: endedAt, canInferCancellations: false, canRevalidateActive: true)
        precondition(ended.contains { $0.hasUnpublishedEnd == true && $0.end == endedAt })
        print("A56 notice matrix passed: timings, direction, interchange, alternatives and live/archive matching.")
    }
}
