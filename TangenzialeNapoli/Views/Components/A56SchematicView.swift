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
                let minimumWidth = nodeDiameter * CGFloat(orderedExits.count)
                ScrollView(.horizontal) {
                    rail(width: max(geometry.size.width, minimumWidth))
                        .padding(.vertical, 5)
                }
            }
            .frame(height: nodeDiameter + 10)

            Text("\(A56Line.italia90.markerLabel) · \(A56Line.italia90.interchangeLabel)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilitySummary) \(A56Line.italia90.name), solo ingresso in entrambe le direzioni.")
    }

    private func rail(width: CGFloat) -> some View {
        let step = (width - nodeDiameter) / CGFloat(max(1, orderedExits.count - 1))
        return ZStack(alignment: .topLeading) {
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
        .frame(width: width, height: nodeDiameter, alignment: .topLeading)
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
            .font(.system(size: nodeFontSize, weight: .semibold))
            .minimumScaleFactor(0.6)
            .foregroundStyle(hasIssue ? Color.a56OnStatus : openColor)
            .frame(width: nodeDiameter, height: nodeDiameter)
            .background(hasIssue ? Color.a56Block : Color.a56Surface, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(hasIssue ? Color.a56Block : openColor, lineWidth: hasIssue ? 2 : 1.25)
            }
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
                + "\(relevantClosures.count) \(relevantClosures.count == 1 ? "limitazione non aggiornata" : "limitazioni non aggiornate") "
                + "\(direction.headingPhrase), da verificare."
        }
        guard !relevantClosures.isEmpty else {
            return "Schema A56 da Pozzuoli a Capodichino. Nessuna chiusura segnalata \(direction.headingPhrase)."
        }
        return "Schema A56 da Pozzuoli a Capodichino. "
            + "\(relevantClosures.count) \(relevantClosures.count == 1 ? "limitazione" : "limitazioni") \(direction.headingPhrase)."
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
