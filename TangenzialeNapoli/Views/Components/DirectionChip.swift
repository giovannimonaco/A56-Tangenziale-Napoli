import SwiftUI

struct DirectionChip: View {
    let direction: Direction
    var compact: Bool = false

    var body: some View {
        Label {
            Text(compact ? direction.shortName : direction.towardLabel)
        } icon: {
            Image(systemName: direction.systemImage)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }
}

#Preview {
    VStack {
        DirectionChip(direction: .towardPozzuoli)
        DirectionChip(direction: .towardCapodichino, compact: true)
    }
    .padding()
}
