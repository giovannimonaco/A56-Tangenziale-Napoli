//
//  A56Exit.swift
//  TangenzialeNapoli
//
//  A single numbered exit (svincolo) of the A56 Tangenziale di Napoli.
//

import Foundation
import CoreLocation

/// One line point on the A56. `number` is both the identity and the schematic
/// position (1 = Aeroporto … 15 = Arco Felice / Pozzuoli); it is not presented
/// as an operator-assigned motorway exit number.
nonisolated struct A56Exit: Identifiable, Codable, Hashable, Sendable {
    /// Stable app position, 1...15.
    let number: Int
    /// Number shown on road signage. Italia 90 is a distinct access point but
    /// is not one of the 14 commercially numbered exits.
    let commercialNumber: Int?
    /// Driver-facing sign name, e.g. "Capodimonte / Rione Sanità".
    let name: String
    let latitude: Double
    let longitude: Double

    var id: Int { number }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The individual destinations served by this exit, split from `name`.
    /// e.g. "Vomero / Soccavo / Pianura" -> ["Vomero", "Soccavo", "Pianura"].
    var destinations: [String] {
        name.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Compact label matching road signage.
    var shortLabel: String {
        if let commercialNumber {
            return "\(commercialNumber) · \(destinations.first ?? name)"
        }
        return name
    }

    init(
        number: Int,
        commercialNumber: Int?,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.number = number
        self.commercialNumber = commercialNumber
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
