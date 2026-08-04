//
//  DirectionSwitch.swift
//  TangenzialeNapoli
//
//  The primary control: pick the carriageway you are driving on. Everything
//  else in the app is scoped to this choice.
//

import SwiftUI

struct DirectionSwitch: View {
    @Binding var selection: Direction
    var status: ((Direction) -> (label: String, color: Color))? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    segment(.towardPozzuoli)
                    segment(.towardCapodichino)
                }
            } else {
                HStack(spacing: 4) {
                    segment(.towardPozzuoli)
                    segment(.towardCapodichino)
                }
            }
        }
        .padding(4)
        .background(Color.a56ControlFill, in: RoundedRectangle(cornerRadius: 17))
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func segment(_ direction: Direction) -> some View {
        let isOn = selection == direction
        let alignment: HorizontalAlignment = direction == .towardCapodichino
            ? .trailing
            : .leading
        let frameAlignment: Alignment = direction == .towardCapodichino
            ? .trailing
            : .leading
        let directionStatus = status?(direction)

        return Button {
            guard selection != direction else { return }
            withAnimation(reduceMotion ? nil : .snappy) { selection = direction }
        } label: {
            VStack(alignment: alignment, spacing: 5) {
                HStack(spacing: 5) {
                    if direction == .towardPozzuoli {
                        Image(systemName: direction.systemImage)
                    }
                    Text(direction.shortName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if direction == .towardCapodichino {
                        Image(systemName: direction.systemImage)
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? .primary : .secondary)

                if let directionStatus {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(directionStatus.color)
                            .frame(width: 7, height: 7)
                        Text(directionStatus.label)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(directionStatus.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 11)
            .padding(.vertical, directionStatus == nil ? 11 : 9)
            .frame(minHeight: directionStatus == nil ? 44 : 58)
            .background {
                 if isOn {
                     RoundedRectangle(cornerRadius: 13, style: .continuous)
                         .fill(Color.a56Selection.opacity(0.88))
                         .overlay {
                             RoundedRectangle(cornerRadius: 13, style: .continuous)
                                 .strokeBorder(Color.a56Open.opacity(0.18), lineWidth: 0.75)
                         }
                         .shadow(color: Color.a56Open.opacity(0.09), radius: 4, y: 2)
                 }
             }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(A56PressButtonStyle())
        .accessibilityLabel(
            directionStatus.map { "\(direction.towardLabel), \($0.label)" }
                ?? direction.towardLabel
        )
        // Selection is conveyed by the trait alone; a spoken "Selezionata"
        // value on top made VoiceOver announce it twice.
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityHint(isOn ? "" : "Mostra le chiusure \(direction.headingPhrase)")
    }
}

#Preview {
    struct Demo: View {
        @State var dir: Direction = .towardPozzuoli
        var body: some View {
            VStack(spacing: 24) {
                DirectionSwitch(selection: $dir)
                Text(dir.towardLabel)
            }
            .padding()
        }
    }
    return Demo()
}
