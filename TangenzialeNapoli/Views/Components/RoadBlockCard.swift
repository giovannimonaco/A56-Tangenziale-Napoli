//
//  RoadBlockCard.swift
//  TangenzialeNapoli
//
//  The serious one: the carriageway is closed and you cannot pass.
//

import SwiftUI

struct RoadBlockCard: View {
    let closure: RoadClosure
    /// When the closure is happening now, show "fino alle …" instead of the range.
    var isActive: Bool = false

    private var fromName: String { A56Line.driverLabel(for: closure.fromExit) }
    private var toName: String { A56Line.driverLabel(for: closure.toExit) }
    private var accent: Color { .a56Block }

    /// "Esci a …" comes only from an official "Uscita consigliata" hint that
    /// matches this carriageway. A re-entry hint or a hint for the opposite
    /// direction phrased this way would point the driver at a ramp they cannot
    /// use.
    private var alternativeText: String? {
        guard let alt = closure.recommendedExitBefore(for: closure.direction),
              let exit = A56Line.exit(alt) else { return nil }
        return "Esci a \(exit.shortLabel)"
    }

    var body: some View {
        ClosureCardLayout(
            glyph: "nosign",
            accent: accent,
            title: "Strada chiusa",
            time: isActive ? ClosureFormat.endLabel(closure) : ClosureFormat.timeRange(closure)
        ) {
            Text(
                closure.affectsBothDirections
                    ? "\(fromName) ↔ \(toName)"
                    : "\(fromName) → \(toName)"
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let alternativeText {
                Label(alternativeText, systemImage: "arrow.turn.up.right")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.a56Open)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Strada chiusa tra \(fromName) e \(toName), \(ClosureFormat.timeRange(closure))")
    }
}

#Preview {
    let blocked = SampleClosures.make().first { $0.kind == .roadBlocked }!
    RoadBlockCard(closure: blocked).padding()
}
