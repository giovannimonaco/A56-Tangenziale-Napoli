import SwiftUI

/// Shared card chrome: tinted status chip, headline, trailing time and
/// free-form detail. Color only tints the chip, never the card background.
struct ClosureCardLayout<Content: View>: View {
    let glyph: String
    let accent: Color
    let title: String
    let time: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(systemName: glyph, color: accent)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(time)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                content
            }
        }
        .a56Surface(accent: accent, radius: 18)
        .contentShape(.rect)
    }
}
