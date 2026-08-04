import SwiftUI

/// Card for a closed entrance/exit while the carriageway itself stays open.
struct RampClosureCard: View {
    let closure: RoadClosure
    /// When the closure is happening now, show "fino alle …" instead of the range.
    var isActive: Bool = false

    private var exitName: String { A56Line.name(for: closure.rampExitNumber) }

    /// U-turn glyph oriented by what is closed (entrance, exit, or both).
    private var glyph: String {
        let hasEntrance = !closure.closedEntrances.isEmpty
        let hasExit = !closure.closedExits.isEmpty
        switch (hasEntrance, hasExit) {
        case (true, true):  return "arrow.uturn.left"
        case (true, false): return "arrow.uturn.up"
        default:            return "arrow.uturn.down"
        }
    }

    var body: some View {
        ClosureCardLayout(
            glyph: glyph,
            accent: .a56Ramp,
            title: closure.headline,            // "Uscita chiusa" / "Entrata chiusa"
            time: isActive ? ClosureFormat.endLabel(closure) : ClosureFormat.timeRange(closure)
        ) {
            Text(A56Line.interchangeLabel(for: closure.rampExitNumber))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("La tangenziale resta aperta", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.a56Open)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(closure.headline) a \(exitName), \(ClosureFormat.timeRange(closure)). La tangenziale resta aperta.")
    }
}

#Preview {
    let ramp = SampleClosures.make().first { $0.kind == .rampsClosed }!
    RampClosureCard(closure: ramp).padding()
}
