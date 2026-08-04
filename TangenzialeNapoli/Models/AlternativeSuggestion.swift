import Foundation

/// A detour hint published in the official notice text. The operator
/// distinguishes where to leave the road ("Uscita consigliata") from where to
/// rejoin it ("Entrata consigliata"), and both can be qualified by direction.
nonisolated struct AlternativeSuggestion: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        /// "Uscita consigliata": leave the carriageway at this exit.
        case exitBefore
        /// "Entrata consigliata": rejoin the carriageway at this exit.
        case reentryAfter
    }

    let exitNumber: Int
    let kind: Kind
    /// Travel direction the suggestion applies to, when the notice states one.
    let direction: Direction?
}
