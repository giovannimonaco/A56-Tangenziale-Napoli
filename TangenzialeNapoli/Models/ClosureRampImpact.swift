//
//  ClosureRampImpact.swift
//  TangenzialeNapoli
//
//  A single affected ramp (entrance or exit) at a given svincolo.
//

import Foundation

/// Describes how one ramp at a specific exit is affected by a closure.
/// A closure can affect several ramps across one or more exits.
nonisolated struct ClosureRampImpact: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// The line point this ramp belongs to (1...15).
    let exitNumber: Int
    /// Entrance (entrata) or exit (uscita) ramp.
    let kind: Kind
    /// Which carriageway the ramp feeds.
    let direction: Direction
    /// Whether the ramp is fully closed. `false` means open but impacted.
    let isClosed: Bool

    enum Kind: String, Codable, Hashable, Sendable {
        case entrance   // entrata / immissione
        case exit       // uscita

        var displayName: String {
            switch self {
            case .entrance: "Entrata"
            case .exit:     "Uscita"
            }
        }

        /// Driver-facing one-liner, e.g. "Non puoi uscire".
        var driverAction: String {
            switch self {
            case .entrance: "Non puoi entrare"
            case .exit:     "Non puoi uscire"
            }
        }

        var systemImage: String {
            switch self {
            case .entrance: "arrow.up.right"
            case .exit:     "arrow.down.right"
            }
        }
    }

    /// Short label for a chip, e.g. "Uscita chiusa".
    var shortLabel: String { "\(kind.displayName) chiusa" }

    init(
        id: UUID = UUID(),
        exitNumber: Int,
        kind: Kind,
        direction: Direction,
        isClosed: Bool = true
    ) {
        self.id = id
        self.exitNumber = exitNumber
        self.kind = kind
        self.direction = direction
        self.isClosed = isClosed
    }
}
