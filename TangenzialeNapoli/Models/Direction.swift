import SwiftUI

/// The two carriageways of the A56. The motorway runs roughly east–west:
/// exit 1 (Aeroporto / Capodichino) sits at the eastern end, line point 15
/// (Arco Felice / Pozzuoli) at the western end.
///
/// The app filters to a single `Direction` at a time.
///
/// - `towardPozzuoli` travels from low positions to high (1 -> 15).
/// - `towardCapodichino` travels from high positions to low (15 -> 1).
nonisolated enum Direction: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case towardCapodichino
    case towardPozzuoli

    var id: String { rawValue }

    /// Where you are heading, e.g. "Verso Pozzuoli".
    var towardLabel: String {
        switch self {
        case .towardPozzuoli:    "Verso Pozzuoli"
        case .towardCapodichino: "Verso Capodichino"
        }
    }

    /// Mid-sentence form that keeps the place name capitalized, e.g.
    /// "verso Pozzuoli"; use this instead of lowercasing `towardLabel`.
    var headingPhrase: String { "verso \(shortName)" }

    /// Destination-end name, used as the short label on the direction switch.
    var shortName: String {
        switch self {
        case .towardPozzuoli:    "Pozzuoli"
        case .towardCapodichino: "Capodichino"
        }
    }

    /// Horizontal arrow matching the switch layout: Pozzuoli sits on the left
    /// (points left), Capodichino on the right (points right).
    var systemImage: String {
        switch self {
        case .towardPozzuoli:    "arrow.left"
        case .towardCapodichino: "arrow.right"
        }
    }

    /// Chrome tint for direction UI. Closure urgency uses red/amber, so this
    /// stays neutral.
    var tint: Color {
        .a56Open
    }

    /// The exit number at the destination end of the line.
    var destinationExit: Int {
        self == .towardPozzuoli ? 15 : 1
    }

    /// Whether travel runs in the direction of increasing exit numbers.
    var goesUpTheLine: Bool { self == .towardPozzuoli }
}
