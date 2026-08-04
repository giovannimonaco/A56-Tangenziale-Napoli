import SwiftUI

struct ClosureDetailView: View {
    let closure: RoadClosure
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color { .a56Block }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                hero
                whenCard
                routeCard

                if !closure.suggestedAlternatives.isEmpty {
                    alternativesCard
                }

                sourceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color.a56Canvas)
        .navigationTitle("Dettaglio chiusura")
        .navigationBarTitleDisplayMode(.inline)
        .tint(accent)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroHeading

            Text(guidanceText)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .detailSurface(accent: accent)
    }

    @ViewBuilder
    private var heroHeading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                heroIcon
                heroTitle
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                heroIcon
                heroTitle
                Spacer(minLength: 0)
            }
        }
    }

    private var heroIcon: some View {
        Image(systemName: closure.kind == .roadBlocked ? "nosign" : closureIcon)
            .font(.title3.weight(.bold))
            .foregroundStyle(.a56OnStatus)
            .frame(width: 44, height: 44)
            .background(accent, in: RoundedRectangle(cornerRadius: 13))
            .accessibilityHidden(true)
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(closure.headline)
                .font(.title2.weight(.bold))
                .tracking(-0.35)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 7) {
                        directionText
                        SeverityBadge(severity: closure.severity)
                    }
                } else {
                    HStack(spacing: 8) {
                        directionText
                        SeverityBadge(severity: closure.severity)
                    }
                }
            }
        }
    }

    private var directionText: some View {
        Text(directionLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Quando", systemImage: "clock")

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        valueColumn(
                            label: "Giorno",
                            value: ClosureFormat.dayLabel(closure.start)
                        )
                        Divider()
                        valueColumn(
                            label: "Orario",
                            value: displayedTime,
                            monospaced: true
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        valueColumn(
                            label: "Giorno",
                            value: ClosureFormat.dayLabel(closure.start)
                        )

                        Divider()
                            .frame(height: 42)
                            .padding(.horizontal, 14)

                        valueColumn(
                            label: "Orario",
                            value: displayedTime,
                            monospaced: true
                        )
                    }
                }
            }
        }
        .detailSurface()
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                closure.kind == .roadBlocked ? "Tratto interessato" : "Svincoli interessati",
                systemImage: "road.lanes"
            )

            A56SchematicView(closures: [closure], direction: closure.direction)

            Divider()

            VStack(spacing: 0) {
                if closure.kind == .roadBlocked {
                    ForEach(Array(roadBoundaryExits.enumerated()), id: \.element.id) { index, exit in
                        locationRow(
                            icon: "road.lanes",
                            title: A56Line.interchangeLabel(for: exit.number),
                            subtitle: roadExitRole(at: index)
                        )
                        if index < roadBoundaryExits.count - 1 {
                            rowDivider
                        }
                    }
                } else {
                    ForEach(Array(orderedRampImpacts.enumerated()), id: \.element.id) { index, ramp in
                        locationRow(
                            icon: ramp.kind.systemImage,
                            title: A56Line.interchangeLabel(for: ramp.exitNumber),
                            subtitle: ramp.shortLabel
                        )
                        if index < orderedRampImpacts.count - 1 {
                            rowDivider
                        }
                    }
                }
            }
        }
        .detailSurface()
    }

    private var alternativesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Alternativa consigliata", systemImage: "arrow.turn.up.right")

            if let suggestions = relevantSuggestions {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                    alternativeRow(
                        icon: suggestion.kind == .exitBefore
                            ? "arrow.turn.down.right"
                            : "arrow.turn.up.right",
                        title: A56Line.interchangeLabel(for: suggestion.exitNumber),
                        subtitle: suggestion.kind == .exitBefore
                            ? "Esci qui prima della chiusura"
                            : "Rientra da qui dopo la chiusura"
                    )
                }
            } else {
                // Archives saved by older builds carry only the exit numbers.
                ForEach(closure.suggestedAlternatives, id: \.self) { number in
                    alternativeRow(
                        icon: "arrow.turn.up.right",
                        title: A56Line.interchangeLabel(for: number),
                        subtitle: nil
                    )
                }
            }
        }
        .detailSurface()
    }

    /// The official notice can carry hints for both carriageways; keep only
    /// those valid for this closure's direction (all, when it affects both).
    private var relevantSuggestions: [AlternativeSuggestion]? {
        guard let all = closure.alternativeSuggestions else { return nil }
        let relevant = all.filter {
            closure.affectsBothDirections
                || $0.direction == nil
                || $0.direction == closure.direction
        }
        return relevant.isEmpty ? nil : relevant
    }

    private func alternativeRow(
        icon: String,
        title: String,
        subtitle: String?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.a56Open)
                .frame(width: 28, height: 28)
                .background(Color.a56Open.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Fonte del dato", systemImage: evidenceIcon)

            Text(evidenceText)
                .font(.subheadline)
                .foregroundStyle(evidenceColor)

            if !closure.reason.isEmpty {
                LabeledContent("Motivo") {
                    Text(closure.reason)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }

            if !closure.sourceText.isEmpty {
                Divider()

                DisclosureGroup("Comunicato ufficiale") {
                    Text(closure.sourceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
                .font(.subheadline.weight(.semibold))
                .tint(.secondary)
            }
        }
        .detailSurface()
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func valueColumn(
        label: String,
        value: String,
        monospaced: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(
                    monospaced
                        ? .subheadline.monospacedDigit().weight(.semibold)
                        : .subheadline.weight(.semibold)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func locationRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 39)
    }

    private var orderedRoadExits: [A56Exit] {
        let exits = A56Line.exits(from: closure.fromExit, to: closure.toExit)
        return closure.direction.goesUpTheLine ? exits : Array(exits.reversed())
    }

    private var roadBoundaryExits: [A56Exit] {
        guard let first = orderedRoadExits.first,
              let last = orderedRoadExits.last,
              first.id != last.id
        else { return Array(orderedRoadExits.prefix(1)) }
        return [first, last]
    }

    private var orderedRampImpacts: [ClosureRampImpact] {
        closure.closedRamps.sorted {
            if $0.exitNumber == $1.exitNumber {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return closure.direction.goesUpTheLine
                ? $0.exitNumber < $1.exitNumber
                : $0.exitNumber > $1.exitNumber
        }
    }

    private func roadExitRole(at index: Int) -> String {
        if roadBoundaryExits.count == 1 { return "Tratto chiuso" }
        return index == 0 ? "Inizio del tratto chiuso" : "Fine del tratto chiuso"
    }

    private var directionLabel: String {
        closure.affectsBothDirections ? "Entrambe le direzioni" : closure.direction.towardLabel
    }

    private var closureIcon: String {
        switch (!closure.closedEntrances.isEmpty, !closure.closedExits.isEmpty) {
        case (true, true): "arrow.up.and.down"
        case (true, false): "arrow.up.right"
        default: "arrow.down.right"
        }
    }

    private var guidanceText: String {
        switch closure.kind {
        case .roadBlocked:
            return "Non puoi percorrere la tangenziale tra \(A56Line.driverLabel(for: closure.fromExit)) e \(A56Line.driverLabel(for: closure.toExit))."
        case .rampsClosed:
            let exitName = A56Line.driverLabel(for: closure.rampExitNumber)
            let action: String
            if !closure.closedEntrances.isEmpty && !closure.closedExits.isEmpty {
                action = "non puoi né entrare né uscire"
            } else if !closure.closedEntrances.isEmpty {
                action = "non puoi entrare"
            } else {
                action = "non puoi uscire"
            }
            return "La tangenziale resta percorribile, ma a \(exitName) \(action)."
        }
    }

    private var displayedTime: String {
        closure.evidence == .realtime
            ? ClosureFormat.endLabel(closure)
            : ClosureFormat.timeRange(closure)
    }

    private var evidenceText: String {
        switch closure.evidence {
        case .realtimeConfirmed:
            "Programmazione confermata anche in tempo reale"
        case .realtime:
            "Presente nel feed ufficiale in tempo reale"
        case .scheduled, .none:
            "Presente nella programmazione ufficiale"
        }
    }

    private var evidenceIcon: String {
        closure.evidence == .realtimeConfirmed ? "checkmark.seal.fill" : "doc.text.fill"
    }

    private var evidenceColor: Color {
        closure.evidence == .realtimeConfirmed ? .a56Open : .secondary
    }
}

private extension View {
    func detailSurface(accent: Color? = nil) -> some View {
        a56Surface(accent: accent)
    }
}

#if DEBUG
#Preview("Strada chiusa") {
    NavigationStack {
        ClosureDetailView(closure: SampleClosures.make().first { $0.kind == .roadBlocked }!)
    }
}

#Preview("Svincoli chiusi") {
    NavigationStack {
        ClosureDetailView(closure: SampleClosures.make().first { $0.kind == .rampsClosed }!)
    }
}
#endif
