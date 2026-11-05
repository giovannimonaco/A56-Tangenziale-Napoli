import CoreLocation
import Foundation

nonisolated struct TripNavigationLinks {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let waypoints: [CLLocationCoordinate2D]
    let avoidsHighways: Bool

    func appleMapsURL(supportsUnifiedURLs: Bool) -> URL? {
        let source = Self.queryCoordinate(origin)
        let target = Self.queryCoordinate(destination)
        if supportsUnifiedURLs {
            let stops = waypoints.map { URLQueryItem(name: "waypoint", value: Self.queryCoordinate($0)) }
            return Self.url(host: "maps.apple.com", path: "/directions", query: [
                .init(name: "source", value: source),
                .init(name: "destination", value: target),
                .init(name: "mode", value: "driving")
            ] + stops + avoidance)
        }
        return Self.url(host: "maps.apple.com", path: "/", query: [
            .init(name: "saddr", value: source),
            .init(name: "daddr", value: target),
            .init(name: "dirflg", value: "d")
        ])
    }

    var googleMapsURL: URL? {
        var query: [URLQueryItem] = [
            .init(name: "api", value: "1"),
            .init(name: "origin", value: Self.queryCoordinate(origin)),
            .init(name: "destination", value: Self.queryCoordinate(destination)),
            .init(name: "travelmode", value: "driving")
        ]
        if !waypoints.isEmpty {
            // Google Maps in a mobile browser accepts up to three stops.
            query.append(.init(name: "waypoints", value: waypoints.prefix(3).map(Self.queryCoordinate).joined(separator: "|")))
        }
        return Self.url(host: "www.google.com", path: "/maps/dir/", query: query + avoidance)
    }

    private var avoidance: [URLQueryItem] {
        avoidsHighways ? [.init(name: "avoid", value: "highways,tolls")] : []
    }

    private static func queryCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), coordinate.latitude, coordinate.longitude)
    }

    private static func url(host: String, path: String, query: [URLQueryItem]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query
        return components.url
    }
}
