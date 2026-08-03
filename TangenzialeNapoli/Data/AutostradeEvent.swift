//
//  AutostradeEvent.swift
//  TangenzialeNapoli
//
//  Decodable mirror of the public Autostrade "previsioni.json" feed.
//  Source: https://viabilita.autostrade.it/json/previsioni.json
//  (the same file the official viability site loads — public, no auth).
//

import Foundation

/// Root object of previsioni.json: `{ "events": [ … ] }`.
struct AutostradeFeed: Decodable, Sendable {
    let events: [AutostradeEvent]
}

/// One planned-event row. Only the fields we use are modelled, and all are
/// optional so a schema change degrades gracefully instead of failing the
/// whole decode. JSON keys are snake_case → decoded with `.convertFromSnakeCase`.
struct AutostradeEvent: Decodable, Sendable {
    let cEle: String?          // stable id, e.g. "20260611_E23_SIV_P_00104_00001"
    let cStr: String?          // road code, e.g. "A56"
    let cDir: String?          // "N" → Pozzuoli | "P" → Capodichino | "B" → both
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

    struct Window: Decodable, Sendable {
        let giorno: Int?
        let dIni: Double?      // window start, epoch milliseconds
        let dFin: Double?      // window end, epoch milliseconds
    }
}
