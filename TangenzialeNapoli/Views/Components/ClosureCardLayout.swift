import SwiftUI

/// Shared card chrome: tinted status chip, headline, trailing time and
/// free-form detail. Color only tints the chip, never the card background.
struct ClosureCardLayout<Content: View>: View {
    let glyph: String
    let accent: Color
    let title: String
    let time: String
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(systemName: glyph, color: accent)

            VStack(alignment: .leading, spacing: 5) {
                let headingLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                headingLayout {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 4)
                    }
                    Text(time)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
        }
        .a56Surface(accent: accent, radius: 18)
        .contentShape(.rect)
    }
}
