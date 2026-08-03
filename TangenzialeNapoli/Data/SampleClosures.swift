//
//  SampleClosures.swift
//  TangenzialeNapoli
//
//  Seeded, realistic closures used until a live feed is connected.
//  Each closure keeps a plausible Italian `sourceText` so the future
//  parser has representative input to work against.
//

import Foundation

enum SampleClosures {

    /// Build the sample set anchored to the current date so the Home screen's
    /// Today / Tomorrow / Next-days sections are always populated.
    static func make(reference: Date = .now) -> [RoadClosure] {
        let cal = Calendar.current

        // Helper: a Date at `dayOffset` days from today, at hour:minute.
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: reference)!
            return cal.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) ?? day
        }

        return [

            // MARK: Today

            // Full carriageway segment closed overnight — Vomero → Capodimonte.
            RoadClosure(
                start: at(0, 22, 0),
                end: at(1, 6, 0),
                direction: .towardCapodichino,
                fromExit: 9,   // Vomero
                toExit: 5,     // Capodimonte
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 9, kind: .entrance, direction: .towardCapodichino),
                    ClosureRampImpact(exitNumber: 7, kind: .entrance, direction: .towardCapodichino),
                    ClosureRampImpact(exitNumber: 5, kind: .exit, direction: .towardCapodichino),
                ],
                reason: "Lavori di pavimentazione",
                suggestedAlternatives: [4, 10],
                isFullClosure: true,
                sourceText: """
                A56 Tangenziale di Napoli: per lavori di pavimentazione sarà \
                chiuso il tratto compreso tra Vomero (svincolo 9) e Capodimonte \
                (svincolo 5), in direzione Capodichino, dalle 22:00 di oggi alle \
                06:00 di domani. Chiuse le entrate di Vomero e Zona Ospedaliera \
                e l'uscita di Capodimonte verso Capodichino.
                """
            ),

            // Single ramp closed — Corso Malta entrance toward Pozzuoli.
            RoadClosure(
                start: at(0, 21, 0),
                end: at(1, 5, 0),
                direction: .towardPozzuoli,
                fromExit: 4,   // Corso Malta
                toExit: 4,
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 4, kind: .entrance, direction: .towardPozzuoli),
                ],
                reason: "Chiusura entrata per lavori di manutenzione",
                suggestedAlternatives: [5, 3],
                isFullClosure: false,
                sourceText: """
                A56 Tangenziale di Napoli: chiusa l'entrata di Corso Malta \
                (svincolo 4) in direzione Pozzuoli, dalle 21:00 alle 05:00, per \
                lavori di manutenzione. In alternativa si consiglia l'entrata di \
                Capodimonte o Doganella.
                """
            ),

            // MARK: Tomorrow

            // Tunnel works, full closure Fuorigrotta → Agnano.
            RoadClosure(
                start: at(1, 23, 0),
                end: at(2, 6, 0),
                direction: .towardPozzuoli,
                fromExit: 10,  // Fuorigrotta
                toExit: 12,    // Agnano
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 10, kind: .exit, direction: .towardPozzuoli),
                    ClosureRampImpact(exitNumber: 12, kind: .entrance, direction: .towardPozzuoli),
                ],
                reason: "Lavori in galleria",
                suggestedAlternatives: [13],
                isFullClosure: true,
                sourceText: """
                A56 Tangenziale di Napoli: per lavori in galleria sarà chiuso il \
                tratto Fuorigrotta – Agnano in \
                direzione Pozzuoli, dalle 23:00 alle 06:00. Chiusa l'uscita di \
                Fuorigrotta e l'entrata di Agnano verso Pozzuoli. Uscita \
                consigliata: Via Campana.
                """
            ),

            // Ramp maintenance at Capodimonte (entrance + exit).
            RoadClosure(
                start: at(1, 22, 0),
                end: at(2, 6, 0),
                direction: .towardCapodichino,
                fromExit: 5,   // Capodimonte
                toExit: 5,
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 5, kind: .entrance, direction: .towardCapodichino),
                    ClosureRampImpact(exitNumber: 5, kind: .exit, direction: .towardCapodichino),
                ],
                reason: "Manutenzione dello svincolo",
                suggestedAlternatives: [4, 6],
                isFullClosure: false,
                sourceText: """
                A56 Tangenziale di Napoli: per manutenzione dello svincolo \
                saranno chiuse l'entrata e l'uscita di Capodimonte (svincolo 5) \
                in direzione Capodichino, dalle 22:00 alle 06:00.
                """
            ),

            // MARK: Next days

            // Viaduct inspection, long stretch Corso Malta → Vomero (in 2 days).
            RoadClosure(
                start: at(2, 22, 30),
                end: at(3, 5, 30),
                direction: .towardPozzuoli,
                fromExit: 4,   // Corso Malta
                toExit: 9,     // Vomero
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 4, kind: .entrance, direction: .towardPozzuoli),
                    ClosureRampImpact(exitNumber: 5, kind: .entrance, direction: .towardPozzuoli),
                    ClosureRampImpact(exitNumber: 7, kind: .exit, direction: .towardPozzuoli),
                    ClosureRampImpact(exitNumber: 9, kind: .exit, direction: .towardPozzuoli),
                ],
                reason: "Ispezione dei viadotti",
                suggestedAlternatives: [10],
                isFullClosure: true,
                sourceText: """
                A56 Tangenziale di Napoli: per ispezione dei viadotti sarà chiuso \
                il tratto Corso Malta (svincolo 4) – Vomero (svincolo 9) in \
                direzione Pozzuoli, dalle 22:30 alle 05:30.
                """
            ),

            // Daytime urgent works Agnano → Fuorigrotta (in 3 days).
            RoadClosure(
                start: at(3, 9, 0),
                end: at(3, 17, 0),
                direction: .towardCapodichino,
                fromExit: 12,  // Agnano
                toExit: 10,    // Fuorigrotta
                rampImpacts: [
                    ClosureRampImpact(exitNumber: 12, kind: .exit, direction: .towardCapodichino),
                ],
                reason: "Lavori urgenti di ripristino",
                suggestedAlternatives: [13, 9],
                isFullClosure: true,
                sourceText: """
                A56 Tangenziale di Napoli: per lavori urgenti di ripristino sarà \
                chiuso il tratto Agnano – Fuorigrotta \
                in direzione Capodichino, dalle 09:00 alle 17:00.
                """
            ),
        ]
    }
}
