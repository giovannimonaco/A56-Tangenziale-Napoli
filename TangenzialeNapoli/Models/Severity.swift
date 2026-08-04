//
//  Severity.swift
//  TangenzialeNapoli
//
//  How disruptive a closure is. Drives colour and ordering in the UI.
//

import SwiftUI

/// Severity of a closure. `rawValue` ordering is meaningful, so the type is
/// `Comparable` and can be used to sort or pick the most disruptive event.
nonisolated enum Severity: Int, Codable, Hashable, CaseIterable, Identifiable, Comparable, Sendable {
    case low = 0        // a single ramp closed
    case moderate = 1   // some ramps / partial impact
    case high = 2       // a full carriageway segment closed
    case critical = 3   // major / tunnel / long stretch closed

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .low:      "Bassa"
        case .moderate: "Media"
        case .high:     "Alta"
        case .critical: "Critica"
        }
    }

    /// Graduated for the badge: a "Bassa" pill in alarm red said the opposite
    /// of its own text. Map and schematic keep their single closure colour.
    var color: Color {
        switch self {
        case .low:            .secondary
        case .moderate:       .a56Caution
        case .high, .critical: .a56Block
        }
    }

    var systemImage: String {
        switch self {
        case .low:      "exclamationmark.circle"
        case .moderate: "exclamationmark.triangle"
        case .high:     "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Derivation

    /// Derive severity from the facts of a closure instead of hand-assigning it.
    ///
    /// The driver-facing logic is deliberately simple:
    /// - A blocked carriageway is always serious (`.high`), and `.critical`
    ///   when it is a tunnel or a long stretch.
    /// - A ramp-only closure is `.low` for one ramp, `.moderate` for several.
    ///
    /// - Parameters:
    ///   - isFullClosure: the carriageway itself is closed (not just ramps).
    ///   - spanExits: how many exits the closed stretch spans (`upper - lower`).
    ///   - closedRampCount: number of closed ramps.
    ///   - reason: the works description, e.g. "Lavori".
    ///   - noticeText: the full official notice; tunnels are only ever named
    ///     here, never in the short cause field.
    static func derived(
        isFullClosure: Bool,
        spanExits: Int,
        closedRampCount: Int,
        reason: String,
        noticeText: String = ""
    ) -> Severity {
        if isFullClosure {
            let mentionsTunnel = reason.lowercased().contains("galleria")
                || noticeText.lowercased().contains("galleria")
            let isMajor = mentionsTunnel || spanExits >= 5
            return isMajor ? .critical : .high
        } else {
            return closedRampCount >= 2 ? .moderate : .low
        }
    }
}
