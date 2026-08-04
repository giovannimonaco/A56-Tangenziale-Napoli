import Foundation
import CoreLocation

/// Fixed topology of the A56 Tangenziale di Napoli. The exit list is static
/// reference data, not something the closure feed provides.
nonisolated enum A56Line {

    /// The 15 line points ordered east to west: 14 numbered exits plus the
    /// unnumbered Italia 90 access. `number` is the position on the schematic
    /// map, not the operator's exit number.
    static let exits: [A56Exit] = [
        A56Exit(number: 1,  commercialNumber: 1,  name: "Aeroporto",                         latitude: 40.877416, longitude: 14.290162),
        A56Exit(number: 2,  commercialNumber: 2,  name: "Capodichino / Secondigliano",       latitude: 40.873481, longitude: 14.285730),
        A56Exit(number: 3,  commercialNumber: 3,  name: "Doganella / Piazza Carlo III / Centro storico", latitude: 40.872238, longitude: 14.279487),
        A56Exit(number: 4,  commercialNumber: 4,  name: "Corso Malta / Centro Direzionale / Stazione / Porto", latitude: 40.868987, longitude: 14.268787),
        A56Exit(number: 5,  commercialNumber: 5,  name: "Capodimonte / Rione Sanità",        latitude: 40.866842, longitude: 14.244290),
        A56Exit(number: 6,  commercialNumber: 6,  name: "Arenella / Centro storico / Quartieri Spagnoli", latitude: 40.862922, longitude: 14.236329),
        A56Exit(number: 7,  commercialNumber: 7,  name: "Zona Ospedaliera",                   latitude: 40.861861, longitude: 14.233349),
        A56Exit(number: 8,  commercialNumber: 8,  name: "Camaldoli",                          latitude: 40.853916, longitude: 14.218658),
        A56Exit(number: 9,  commercialNumber: 9,  name: "Vomero / Posillipo",                 latitude: 40.846223, longitude: 14.216086),
        A56Exit(number: 10, commercialNumber: 10, name: "Fuorigrotta / Stadio / Edenlandia", latitude: 40.836695, longitude: 14.198734),
        A56Exit(number: 11, commercialNumber: nil, name: "Italia 90",                         latitude: 40.835500, longitude: 14.178520),
        A56Exit(number: 12, commercialNumber: 11, name: "Agnano / Ippodromo / Edenlandia",   latitude: 40.838462, longitude: 14.161218),
        A56Exit(number: 13, commercialNumber: 12, name: "Via Campana / Pozzuoli",             latitude: 40.839342, longitude: 14.114465),
        A56Exit(number: 14, commercialNumber: 13, name: "Cuma",                               latitude: 40.841446, longitude: 14.093234),
        A56Exit(number: 15, commercialNumber: 14, name: "Arco Felice / Pozzuoli / Bacoli",   latitude: 40.839333, longitude: 14.088862),
    ]

    static func exit(_ number: Int) -> A56Exit? {
        exits.first { $0.number == number }
    }

    static func name(for number: Int) -> String {
        exit(number)?.name ?? "Posizione non riconosciuta"
    }

    static func driverLabel(for number: Int) -> String {
        exit(number)?.shortLabel ?? "Posizione non riconosciuta"
    }

    /// Full driver-facing interchange label for ramp closures.
    static func interchangeLabel(for number: Int) -> String {
        guard let exit = exit(number) else { return "Svincolo non riconosciuto" }
        if let commercialNumber = exit.commercialNumber {
            return "Uscita \(commercialNumber) · \(exit.name)"
        }
        return "Accesso · \(exit.name)"
    }

    static var coordinates: [CLLocationCoordinate2D] {
        exits.map(\.coordinate)
    }

    /// Exits between the two endpoints, inclusive.
    static func exits(from lower: Int, to upper: Int) -> [A56Exit] {
        exits.filter { ($0.number >= min(lower, upper)) && ($0.number <= max(lower, upper)) }
    }

    // MARK: - Resolving official API names

    /// Stable point identifiers published in `c_pnt_dtx_pls_pri/sec`. These
    /// don't depend on spelling, so they resolve first; name aliases are the
    /// fallback for old/incomplete rows and places parsed from the notice text.
    private static let officialPointIDs: [Int: Int] = [
        11222: 1,     // Secondigliano-Aeroporto
        11071: 2,     // Capodichino
        1117: 2,      // Capodichino (variant id used by eventi.json)
        11224: 3,     // Doganella
        1124: 5,      // Capodimonte
        11044: 6,     // Arenella
        1125: 7,      // Zona Ospedaliera
        1126: 8,      // Camaldoli
        1127: 9,      // Vomero
        1129: 10,     // Fuorigrotta
        11221: 11,    // Italia 90
        1133: 12,     // Agnano
        11226: 13,    // Via Campana
        11223: 14,    // Cuma
        11227: 15,    // Pozzuoli / Arco Felice
    ]

    /// Maps official names (which can differ from our labels) to line points.
    /// Keys are normalized (lowercased, accents stripped).
    private static let nameAliases: [String: Int] = [
        "aeroporto": 1, "secondigliano-aeroporto": 1,
        "capodichino": 2, "secondigliano": 2,
        "doganella": 3,
        "corso malta": 4, "viale maddalena": 4,   // Viale Maddalena: entrance near Corso Malta
        "capodimonte": 5, "rione sanita": 5,
        "arenella": 6, "quartieri spagnoli": 6,
        "zona ospedaliera": 7, "colli aminei": 7,
        "camaldoli": 8,
        "vomero": 9, "soccavo": 9, "pianura": 9,
        "fuorigrotta": 10, "stadio": 10, "bagnoli": 10,
        "italia 90": 11,
        "agnano": 12,
        "via campana": 13,
        "cuma": 14,
        "arco felice": 15, "pozzuoli": 15, "bacoli": 15,
        // Terminal labels follow the official kilometre axis, which runs
        // west to east: km 0 ("Inizio") at Arco Felice, km ~20 ("Fine") at
        // the Capodichino junction. Confirmed against n_km_ini in real rows.
        "inizio tangenziale": 15,
        "fine tangenziale": 1,
    ]

    /// Resolve an official location using its stable id first, then its label.
    static func resolveExit(pointID: Int?, named rawName: String?) -> Int? {
        if let pointID, pointID != 0, let exact = officialPointIDs[pointID] {
            return exact
        }
        guard let rawName else { return nil }
        return resolveExit(named: rawName)
    }

    /// True when the official numeric id and the accompanying label resolve
    /// to two different places.
    static func hasResolutionConflict(pointID: Int?, named rawName: String?) -> Bool {
        guard let pointID,
              pointID != 0,
              let byID = officialPointIDs[pointID],
              let rawName,
              !rawName.isEmpty,
              let byName = resolveExit(named: rawName)
        else { return false }
        return byID != byName
    }

    /// Resolve an official feed name to an exit number. Exact matches win;
    /// the contains fallback only succeeds when every matching alias points
    /// at the same line point.
    static func resolveExit(named rawName: String) -> Int? {
        let key = normalize(rawName)
        guard !key.isEmpty else { return nil }

        if let exact = nameAliases[key] { return exact }

        let matches = Set(
            nameAliases
                .filter { alias, _ in alias.count >= 4 && key.contains(alias) }
                .map(\.value)
        )
        return matches.count == 1 ? matches.first : nil
    }

    /// Order two endpoints in travel direction; the `locpri`/`locsec` order
    /// in the JSON row is arbitrary.
    static func orderedEndpoints(_ first: Int, _ second: Int, direction: Direction) -> (Int, Int) {
        if direction.goesUpTheLine {
            return (min(first, second), max(first, second))
        }
        return (max(first, second), min(first, second))
    }

    /// Internal consistency checks included in the live quality report.
    static var validationIssues: [String] {
        var issues: [String] = []
        if exits.map(\.number) != Array(1...exits.count) {
            issues.append("Le posizioni della linea A56 non sono consecutive.")
        }
        if Set(exits.map(\.number)).count != exits.count {
            issues.append("La linea A56 contiene posizioni duplicate.")
        }
        if officialPointIDs.values.contains(where: { exit($0) == nil }) {
            issues.append("Un identificativo ufficiale punta a una posizione inesistente.")
        }
        return issues
    }

    /// Lowercase, strip accents and punctuation, collapse whitespace.
    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
