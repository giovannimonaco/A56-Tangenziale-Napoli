import Foundation

/// Root object of previsioni.json: `{ "events": [ … ] }`.
/// Source: https://viabilita.autostrade.it/json/previsioni.json (public, no auth).
///
/// Rows are decoded one by one: a malformed row (typically for another
/// motorway) is dropped and counted instead of failing the whole feed.
nonisolated struct AutostradeFeed: Decodable, Sendable {
    let events: [AutostradeEvent]
    let undecodedEventCount: Int

    private enum CodingKeys: String, CodingKey {
        case events
    }

    /// Consumes one array element of any shape, so decoding can move past a
    /// row that `AutostradeEvent` rejects.
    private struct AnyRow: Decodable {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var rows = try container.nestedUnkeyedContainer(forKey: .events)

        var decoded: [AutostradeEvent] = []
        var dropped = 0
        while !rows.isAtEnd {
            if let event = try? rows.decode(AutostradeEvent.self) {
                // Without a road code we cannot tell whether a row belongs
                // to the A56. Treat it as unreadable, not as another road.
                if let code = event.roadCode, code == "A56" || !event.namesA56 {
                    decoded.append(event)
                } else {
                    dropped += 1
                }
            } else if (try? rows.decode(AnyRow.self)) != nil {
                dropped += 1
            } else {
                // The element cannot be consumed at all; stop rather than spin.
                dropped += 1
                break
            }
        }
        events = decoded
        undecodedEventCount = dropped
    }
}

/// One planned-event row. Only the fields we use are modelled, all optional
/// so a schema change doesn't fail the whole decode. JSON keys are snake_case,
/// decoded with `.convertFromSnakeCase`.
nonisolated struct AutostradeEvent: Decodable, Sendable {
    let cEle: String?          // stable id, e.g. "20260611_E23_SIV_P_00104_00001"
    let cStr: String?          // road code, e.g. "A56"
    let cDir: String?          // "N" -> Pozzuoli | "P" -> Capodichino | "B" -> both
    let cGrpTip: String?       // real-time group; "C" identifies active closures
    let tDesFraIt: String?     // type: "Tratto Chiuso" | "Entrata Chiusa" | "Uscita Chiusa" | …
    let tDesFraCauIt: String?  // cause, e.g. "Lavori"
    let tDesIt: String?        // full official notice text (Italian)
    let tDesDirIt: String?     // human direction text ("Pozzuoli", "Allacc. … Capodichino", …)
    let tDesAut: String?       // road name, "TANGENZIALE DI NAPOLI"
    let locpri: String?        // primary svincolo / segment endpoint
    let locsec: String?        // secondary svincolo / segment endpoint
    let cPntDtxPlsPri: Int?    // stable official point id for `locpri`
    let cPntDtxPlsSec: Int?    // stable official point id for `locsec`
    let nKmIni: Double?
    let nKmFin: Double?
    let dSta: Double?          // overall start, epoch milliseconds
    let dSto: Double?          // overall end, epoch milliseconds
    let dAgg: Double?          // real-time event activation/update, epoch milliseconds
    let finoAl: String?        // real-time end, e.g. "202607280400P02:303" (UTC + offset)
    let indisponibilita: [Window]?  // actual per-day closure windows

    var roadCode: String? {
        guard let code = cStr?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !code.isEmpty else { return nil }
        return code
    }

    var namesA56: Bool {
        let name = A56Line.normalize(tDesAut ?? "")
        return name == "tangenziale di napoli" || name == "tangenziale napoli"
    }

    struct Window: Decodable, Sendable {
        let dIni: Double?      // window start, epoch milliseconds
        let dFin: Double?      // window end, epoch milliseconds

        private enum CodingKeys: String, CodingKey { case dIni, dFin }

        init(from decoder: Decoder) throws {
            let fields = try? decoder.container(keyedBy: CodingKeys.self)
            dIni = try? fields?.decode(Double.self, forKey: .dIni)
            dFin = try? fields?.decode(Double.self, forKey: .dFin)
        }
    }
}
