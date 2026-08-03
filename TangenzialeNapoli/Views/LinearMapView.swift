//
//  LinearMapView.swift
//  TangenzialeNapoli
//
//  Vertical schematic of the A56, oriented in the driver's travel direction
//  (top = behind you, bottom = ahead). Shows a blocked stretch and/or closed
//  ramps for one carriageway only.
//

import SwiftUI

struct LinearMapView: View {
    /// When set, highlights this closure's stretch / ramps. Its direction wins.
    var closure: RoadClosure? = nil
    /// Used when there is no closure (full-line overview) to orient the map.
    var direction: Direction = .towardPozzuoli
    /// Hide exit names to render a denser rail.
    var showsNames: Bool = true

    private let rowHeight: CGFloat = 64
    private let railWidth: CGFloat = 44
    private let lineWidth: CGFloat = 5
    private let nodeSize: CGFloat = 28

    private var roadColor: Color { .a56Open }
    // Teal means open; every restriction is red. Its shape and text explain
    // whether the problem affects the carriageway, an entrance, or an exit.
    private var highlight: Color {
        closure == nil ? .a56Open : .a56Issue
    }
    private var travelDirection: Direction { closure?.direction ?? direction }

    /// Exits ordered so the driver's travel direction reads top → bottom.
    private var orderedExits: [A56Exit] {
        if closure?.affectsBothDirections == true { return A56Line.exits }
        return travelDirection.goesUpTheLine ? A56Line.exits : Array(A56Line.exits.reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            directionHeader
            ForEach(Array(orderedExits.enumerated()), id: \.element.id) { index, exit in
                row(at: index)
            }
        }
    }

    // MARK: - Header

    private var directionHeader: some View {
        HStack(spacing: 6) {
            if closure?.affectsBothDirections == true {
                Image(systemName: "arrow.up.arrow.down")
                Text("Entrambe le direzioni")
            } else {
                Image(systemName: "arrow.down")
                Text("Senso di marcia · \(travelDirection.shortName)")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(travelDirection.tint)
        .padding(.leading, railWidth)
        .padding(.bottom, 6)
    }

    // MARK: - Row

    private func row(at index: Int) -> some View {
        let exit = orderedExits[index]
        let upNumber = index > 0 ? orderedExits[index - 1].number : nil
        let downNumber = index < orderedExits.count - 1 ? orderedExits[index + 1].number : nil

        let within = isWithin(exit.number)
        let isEndpoint = closure.map { $0.lowerExit == exit.number || $0.upperExit == exit.number } ?? false
        // A rail half is "closed" when the edge to the adjacent node lies inside
        // the closed stretch (both endpoints within). Works for either ordering.
        let topClosed = within && (upNumber.map(isWithin) ?? false)
        let bottomClosed = within && (downNumber.map(isWithin) ?? false)
        let ramps = closure?.closedRamps.filter { $0.exitNumber == exit.number } ?? []

        return HStack(alignment: .center, spacing: 12) {
            rail(isFirst: index == 0,
                 isLast: index == orderedExits.count - 1,
                 topClosed: topClosed, bottomClosed: bottomClosed,
                 within: within, isEndpoint: isEndpoint, exit: exit)

            if showsNames {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exit.name)
                        .font(.subheadline.weight(within ? .semibold : .regular))
                        .foregroundStyle(within ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !ramps.isEmpty {
                        rampMarkers(ramps)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: rowHeight)
    }

    /// `true` if the exit number is inside the highlighted closed stretch.
    private func isWithin(_ number: Int) -> Bool {
        closure?.contains(exit: number) ?? false
    }

    private func rail(
        isFirst: Bool, isLast: Bool,
        topClosed: Bool, bottomClosed: Bool,
        within: Bool, isEndpoint: Bool, exit: A56Exit
    ) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? .clear : (topClosed ? highlight : roadColor))
                    .frame(width: lineWidth)
                Rectangle()
                    .fill(isLast ? .clear : (bottomClosed ? highlight : roadColor))
                    .frame(width: lineWidth)
            }

            Circle()
                .fill(within ? highlight : roadColor)
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Circle().strokeBorder(
                        Color.a56MarkerBorder.opacity(0.9),
                        lineWidth: isEndpoint ? 3 : 1.5
                    )
                }
                .overlay {
                    Text(exit.commercialNumber.map(String.init) ?? "I90")
                        .font(.caption2.weight(.bold))
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.a56OnStatus)
                }
                .shadow(color: (within ? highlight : roadColor).opacity(0.35), radius: 4)
        }
        .frame(width: railWidth)
    }

    private func rampMarkers(_ ramps: [ClosureRampImpact]) -> some View {
        HStack(spacing: 6) {
            ForEach(ramps) { ramp in
                Label(ramp.shortLabel, systemImage: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(highlight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(highlight.opacity(0.14), in: Capsule())
            }
        }
    }
}

#Preview("Toward Pozzuoli") {
    ScrollView { LinearMapView(direction: .towardPozzuoli).padding() }
}

#Preview("Road blocked") {
    ScrollView {
        LinearMapView(closure: SampleClosures.make().first { $0.kind == .roadBlocked }).padding()
    }
}
