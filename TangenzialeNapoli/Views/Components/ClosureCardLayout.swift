//
//  ClosureCardLayout.swift
//  TangenzialeNapoli
//
//  Shared native card chrome: a neutral grouped-background card with a tinted
//  SF Symbol status chip, a headline, a trailing time, and free-form detail.
//  Color is used as an accent (chip), not as a filled background — per HIG.
//

import SwiftUI

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
