import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class TripPlanner {
    struct Place {
        let name: String
        let subtitle: String?
        let item: MKMapItem
        let locationDetails: TripLocation.Details?

        init(name: String, subtitle: String?, item: MKMapItem, locationDetails: TripLocation.Details? = nil) {
            self.name = name
            self.subtitle = subtitle
            self.item = item
            self.locationDetails = locationDetails
        }

        var coordinate: CLLocationCoordinate2D {
            if #available(iOS 26.0, *) { return item.location.coordinate }
            return item.placemark.coordinate
        }
    }

    struct Option {
        let route: MKRoute
        let usage: A56TripMatcher.Usage

        var a56Traversals: [A56TripMatcher.Traversal] {
            guard case .withA56(let traversals) = usage else { return [] }
            return traversals
        }

        func impacts(closures: [RoadClosure], departure: Date) -> [A56TripMatcher.Impact] {
            guard case .withA56(let traversals) = usage else { return [] }
            return A56TripMatcher.impacts(
                on: traversals,
                closures: closures,
                departure: departure,
                duration: route.expectedTravelTime
            )
        }

        func nextImpactAfterTrip(closures: [RoadClosure], departure: Date) -> A56TripMatcher.Impact? {
            guard case .withA56(let traversals) = usage else { return nil }
            return A56TripMatcher.nextImpactAfterTrip(
                on: traversals,
                closures: closures,
                departure: departure,
                duration: route.expectedTravelTime
            )
        }
    }

    struct Result {
        let withA56: [Option]
        let withoutA56: Option?
        let uncertain: Option?
        let searchIncomplete: Bool

        func preferredA56(closures: [RoadClosure], departure: Date) -> Option? {
            withA56.first {
                $0.impacts(closures: closures, departure: departure).isEmpty
            } ?? withA56.first {
                !$0.impacts(closures: closures, departure: departure).contains(where: \.blocksRoute)
            } ?? withA56.first
        }
    }

    let origin: Place
    let destination: Place
    private(set) var result: Result?
    private(set) var error: String?
    @ObservationIgnored private var activeRequest: MKDirections?
    @ObservationIgnored private var revision = 0

    init(origin: Place, destination: Place) {
        self.origin = origin
        self.destination = destination
    }

    func calculate() async {
        guard !Task.isCancelled else { return }
        resetComparison()
        let currentRevision = revision
        defer { if revision == currentRevision { activeRequest = nil } }

        var options: [Option] = []
        var searchIncomplete = false
        for avoidsHighways in [false, true] {
            do {
                try Task.checkCancellation()
                guard currentRevision == revision else { return }
                let request = MKDirections.Request()
                request.source = origin.item
                request.destination = destination.item
                request.transportType = .automobile
                request.requestsAlternateRoutes = true
                if avoidsHighways {
                    request.highwayPreference = .avoid
                    request.tollPreference = .avoid
                }
                let directions = MKDirections(request: request)
                activeRequest = directions
                let response = try await withTaskCancellationHandler {
                    try await directions.calculate()
                } onCancel: {
                    Task { @MainActor in directions.cancel() }
                }
                guard currentRevision == revision, !Task.isCancelled else { return }
                activeRequest = nil
                options += response.routes.map { route in
                    let names = [route.name] + route.steps.map(\.instructions)
                    let mentionsA56 = names.contains { name in
                        let normalized = A56Line.normalize(name)
                        return normalized.split(separator: " ").contains("a56")
                            || normalized == "tangenziale"
                            || normalized.contains("tangenziale di napoli")
                            || normalized.contains("tangenziale est ovest di napoli")
                    }
                    return Option(
                        route: route,
                        usage: A56TripMatcher.usage(
                            coordinates: Array(UnsafeBufferPointer(
                                start: route.polyline.points(),
                                count: route.polyline.pointCount
                            )).map(\.coordinate),
                            mentionsA56: mentionsA56,
                            maneuvers: route.steps.compactMap { step in
                                guard step.polyline.pointCount > 0, !step.instructions.isEmpty else { return nil }
                                return A56TripMatcher.Maneuver(
                                    instruction: step.instructions,
                                    coordinate: step.polyline.points()[0].coordinate
                                )
                            }
                        )
                    )
                }
                if options.contains(where: { if case .withA56 = $0.usage { true } else { false } }),
                   options.contains(where: { if case .withoutA56 = $0.usage { true } else { false } }) {
                    break
                }
            } catch {
                guard currentRevision == revision, !Task.isCancelled else { return }
                activeRequest = nil
                searchIncomplete = true
            }
        }
        options.sort { $0.route.expectedTravelTime < $1.route.expectedTravelTime }
        guard !options.isEmpty else {
            error = "Mappe di Apple non ha trovato un percorso. Riprova o scegli un altro punto di partenza o di arrivo."
            return
        }
        result = Result(
            withA56: options.filter { if case .withA56 = $0.usage { true } else { false } },
            withoutA56: options.first { if case .withoutA56 = $0.usage { true } else { false } },
            uncertain: options.first { if case .uncertain = $0.usage { true } else { false } },
            searchIncomplete: searchIncomplete
        )
    }

    func resetComparison() {
        revision += 1
        activeRequest?.cancel()
        activeRequest = nil
        result = nil
        error = nil
    }
}

extension TripPlanner.Place {
    init(name: String, subtitle: String? = nil, location: CLLocation, locationDetails: TripLocation.Details? = nil) {
        let item: MKMapItem
        if #available(iOS 26.0, *) {
            item = MKMapItem(location: location, address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        }
        item.name = name
        self.init(name: name, subtitle: subtitle, item: item, locationDetails: locationDetails)
    }
}

@MainActor
@Observable
final class TripLocation: NSObject, CLLocationManagerDelegate {
    @MainActor
    @Observable
    final class Details: Hashable {
        let horizontalAccuracy: CLLocationAccuracy
        private(set) var address: String?
        private(set) var isResolvingAddress = true

        init(horizontalAccuracy: CLLocationAccuracy) {
            self.horizontalAccuracy = horizontalAccuracy
        }

        nonisolated static func == (lhs: Details, rhs: Details) -> Bool {
            lhs === rhs
        }

        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }

        func resolveAddress(for location: CLLocation) async {
            defer { isResolvingAddress = false }
            if #available(iOS 26.0, *) {
                guard let request = MKReverseGeocodingRequest(location: location) else { return }
                address = try? await request.mapItems.first?.address?.fullAddress
            } else {
                let geocoder = CLGeocoder()
                if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                    address = MKPlacemark(placemark: placemark).title
                }
            }
        }
    }

    private(set) var place: TripPlanner.Place?
    private(set) var isLocating = false
    private(set) var error: String?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var locationRequested = false
    /// Changes when a location attempt finishes, including errors.
    private(set) var revision = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func locate() {
        guard !isLocating else { return }
        error = nil
        place = nil
        isLocating = true
        requestWhenAuthorized()
    }

    func cancel() {
        isLocating = false
        error = nil
    }

    private func requestWhenAuthorized() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if !locationRequested {
                locationRequested = true
                manager.requestLocation()
            }
        case .denied, .restricted:
            isLocating = false
            error = "Posizione non disponibile. Scegli un indirizzo di partenza o abilita la posizione in Impostazioni."
            revision += 1
        @unknown default:
            finish(with: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if isLocating { requestWhenAuthorized() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in finish(with: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(with: nil) }
    }

    private func finish(with location: CLLocation?) {
        locationRequested = false
        guard isLocating else { return }
        defer { revision += 1 }
        isLocating = false
        guard let location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 200,
              abs(location.timestamp.timeIntervalSinceNow) < 60 else {
            error = "Non riesco a trovare una posizione precisa. Riprova o scegli un indirizzo di partenza."
            return
        }
        let details = Details(horizontalAccuracy: location.horizontalAccuracy)
        place = .init(name: "La mia posizione", location: location, locationDetails: details)
        Task { await details.resolveAddress(for: location) }
    }
}
