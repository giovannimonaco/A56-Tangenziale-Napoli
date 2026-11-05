import MapKit

struct TripFavorite: Codable, Identifiable {
    let id: UUID
    let name: String
    let subtitle: String?
    let latitude: Double
    let longitude: Double

    init(place: TripPlanner.Place) {
        id = UUID()
        name = place.name
        subtitle = place.subtitle
        let coordinate = place.coordinate
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var place: TripPlanner.Place {
        TripPlanner.Place(
            name: name,
            subtitle: subtitle,
            location: CLLocation(latitude: latitude, longitude: longitude)
        )
    }

    func matches(_ place: TripPlanner.Place) -> Bool {
        let coordinate = place.coordinate
        return name == place.name && subtitle == place.subtitle
            && abs(latitude - coordinate.latitude) < 0.00001
            && abs(longitude - coordinate.longitude) < 0.00001
    }
}
