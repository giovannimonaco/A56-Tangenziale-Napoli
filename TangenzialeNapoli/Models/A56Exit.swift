import Foundation
import CoreLocation

/// One line point (svincolo) on the A56. `number` is both the identity and the schematic
/// position (1 = Aeroporto … 15 = Arco Felice / Pozzuoli); it is not presented
/// as an operator-assigned motorway exit number.
nonisolated struct A56Exit: Identifiable, Codable, Hashable, Sendable {
    /// Stable app position, 1...15.
    let number: Int
    /// Number shown on road signage, when present.
    let commercialNumber: Int?
    let isEntranceOnly: Bool
    /// Driver-facing sign name, e.g. "Capodimonte / Rione Sanità".
    let name: String
    let latitude: Double
    let longitude: Double

    var id: Int { number }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Destinations split from `name`, e.g.
    /// "Vomero / Soccavo / Pianura" -> ["Vomero", "Soccavo", "Pianura"].
    var destinations: [String] {
        name.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var markerLabel: String { commercialNumber.map(String.init) ?? "I90" }

    var kindLabel: String {
        if isEntranceOnly { return "Solo ingresso" }
        return commercialNumber.map { "Uscita \($0)" } ?? "Svincolo"
    }

    var interchangeLabel: String {
        isEntranceOnly ? "Ingresso \(name)" : "\(kindLabel) · \(name)"
    }

    /// Compact label matching road signage.
    var shortLabel: String {
        if isEntranceOnly { return interchangeLabel }
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
        longitude: Double,
        isEntranceOnly: Bool = false
    ) {
        self.number = number
        self.commercialNumber = commercialNumber
        self.isEntranceOnly = isEntranceOnly
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
}
