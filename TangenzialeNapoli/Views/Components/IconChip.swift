//
//  IconChip.swift
//  TangenzialeNapoli
//
//  The small tinted SF Symbol chip used on closure cards — reused for other
//  rows (history, empty states) so icons stay the same size and style.
//

import SwiftUI

struct IconChip: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}
