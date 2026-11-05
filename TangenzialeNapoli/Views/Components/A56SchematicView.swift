import SwiftUI

/// Non-geographic schematic of the whole A56. Orientation is fixed:
/// Pozzuoli on the left, Capodichino on the right.
struct A56SchematicView: View {
    let closures: [RoadClosure]
    let direction: Direction
    var showsEndpointLabels = true
    var isStatusKnown = true

    /// Scaled with Dynamic Type; at fixed sizes, large system text left the
    /// exit numbers unreadable next to the card text.
    @ScaledMetric(relativeTo: .caption2) private var nodeDiameter: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var lineWidth: CGFloat = 5
    @ScaledMetric(relativeTo: .caption2) private var nodeFontSize: CGFloat = 9

    /// A56Line is stored east to west; this view reads west to east.
    private var orderedExits: [A56Exit] {
        Array(A56Line.exits.reversed())
    }

    private var relevantClosures: [RoadClosure] {
        closures.filter { $0.matches(direction: direction) }
    }

    private var openColor: Color {
        isStatusKnown ? .a56Open : .a56Unknown
    }

    var body: some View {
        VStack(spacing: 8) {
            if showsEndpointLabels {
                endpointLabels
            }

            GeometryReader { geometry in
                let step = (geometry.size.width - nodeDiameter)
                    / CGFloat(max(1, orderedExits.count - 1))

                ZStack(alignment: .topLeading) {
                    ForEach(0..<(orderedExits.count - 1), id: \.self) { index in
                        Capsule()
                            .fill(segmentHasIssue(at: index) ? Color.a56Block : openColor)
                            .frame(width: step + 1, height: lineWidth)
                            .offset(
                                x: nodeDiameter / 2 + CGFloat(index) * step,
                                y: (nodeDiameter - lineWidth) / 2
                            )
                    }

                    ForEach(Array(orderedExits.enumerated()), id: \.element.id) { index, exit in
                        exitNode(exit)
                            .offset(x: CGFloat(index) * step)
                    }
                }
            }
            .frame(height: nodeDiameter)

            Text("\(A56Line.italia90.markerLabel) · \(A56Line.italia90.interchangeLabel)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilitySummary) \(A56Line.italia90.name), solo ingresso in entrambe le direzioni.")
    }

    private var endpointLabels: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                Text("Pozzuoli")
            }
            .foregroundStyle(direction == .towardPozzuoli ? .primary : .secondary)

            Spacer()

            HStack(spacing: 4) {
                Text("Capodichino")
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(direction == .towardCapodichino ? .primary : .secondary)
        }
        .font(.caption.weight(.bold))
    }

    private func exitNode(_ exit: A56Exit) -> some View {
        let hasIssue = exitHasIssue(exit)
        return Text(exit.markerLabel)
            .font(.system(size: nodeFontSize, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
            .foregroundStyle(.a56OnStatus)
            .frame(width: nodeDiameter, height: nodeDiameter)
            .background(hasIssue ? Color.a56Block : openColor, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.a56MarkerBorder.opacity(0.9), lineWidth: hasIssue ? 1.5 : 1)
            }
            .shadow(
                color: (hasIssue ? Color.a56Block : openColor).opacity(0.28),
                radius: hasIssue ? 4 : 2,
                y: 1
            )
    }

    private func segmentHasIssue(at index: Int) -> Bool {
        let first = orderedExits[index]
        let second = orderedExits[index + 1]
        return relevantClosures.contains {
            $0.kind == .roadBlocked
                && $0.contains(exit: first.number)
                && $0.contains(exit: second.number)
        }
    }

    private func exitHasIssue(_ exit: A56Exit) -> Bool {
        relevantClosures.contains { closure in
            switch closure.kind {
            case .roadBlocked:
                closure.contains(exit: exit.number)
            case .rampsClosed:
                if closure.closedRamps.isEmpty {
                    closure.rampExitNumber == exit.number
                } else {
                    closure.closedRamps(for: direction).contains {
                        $0.exitNumber == exit.number
                    }
                }
            }
        }
    }

    private var accessibilitySummary: String {
        guard isStatusKnown else {
            guard !relevantClosures.isEmpty else {
                return "Schema A56 da Pozzuoli a Capodichino. Stato non confermato."
            }
            return "Schema A56 da Pozzuoli a Capodichino. "
                + "\(relevantClosures.count) limitazioni non aggiornate "
                + "\(direction.headingPhrase), da verificare."
        }
        guard !relevantClosures.isEmpty else {
            return "Schema A56 da Pozzuoli a Capodichino. Nessuna chiusura segnalata \(direction.headingPhrase)."
        }
        return "Schema A56 da Pozzuoli a Capodichino. "
            + "\(relevantClosures.count) limitazioni \(direction.headingPhrase)."
    }
}

#if DEBUG
#Preview("Aperta") {
    A56SchematicView(closures: [], direction: .towardPozzuoli)
        .padding()
}

#Preview("Con chiusure") {
    A56SchematicView(
        closures: SampleClosures.make(),
        direction: .towardCapodichino
    )
    .padding()
}
#endif
