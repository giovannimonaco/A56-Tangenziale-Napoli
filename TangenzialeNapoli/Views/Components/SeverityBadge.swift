import SwiftUI

struct SeverityBadge: View {
    let severity: Severity
    var showsLabel: Bool = true

    var body: some View {
        Label {
            if showsLabel {
                Text(severity.displayName)
            }
        } icon: {
            Image(systemName: severity.systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(severity.color)
        .padding(.horizontal, showsLabel ? 8 : 6)
        .padding(.vertical, 4)
        .background(severity.color.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HStack {
        ForEach(Severity.allCases) { SeverityBadge(severity: $0) }
    }
    .padding()
}
