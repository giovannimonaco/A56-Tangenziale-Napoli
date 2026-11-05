import MapKit
import Observation

@MainActor
@Observable
final class TripPlaceSuggestions: NSObject, MKLocalSearchCompleterDelegate {
    static let searchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.853, longitude: 14.195),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.50)
    )

    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var isUnavailable = false
    @ObservationIgnored private var completer: MKLocalSearchCompleter?

    func update(_ query: String) {
        let fragment = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fragment.count >= 2 else {
            cancel()
            return
        }

        let current: MKLocalSearchCompleter
        if let completer {
            current = completer
        } else {
            current = MKLocalSearchCompleter()
            current.region = Self.searchRegion
            current.resultTypes = [.address, .pointOfInterest]
            current.delegate = self
            completer = current
        }

        guard current.queryFragment != fragment else { return }
        results = []
        isUnavailable = false
        current.queryFragment = fragment
    }

    func cancel() {
        completer?.cancel()
        completer = nil
        results = []
        isUnavailable = false
    }

    nonisolated func completerDidUpdateResults(_ sender: MKLocalSearchCompleter) {
        let id = ObjectIdentifier(sender)
        Task { @MainActor [weak self] in
            guard let self, let completer, ObjectIdentifier(completer) == id, !completer.isSearching else { return }
            results = completer.results
            isUnavailable = false
        }
    }

    nonisolated func completer(_ sender: MKLocalSearchCompleter, didFailWithError error: Error) {
        let id = ObjectIdentifier(sender)
        Task { @MainActor [weak self] in
            guard let self, let completer, ObjectIdentifier(completer) == id, !completer.isSearching else { return }
            results = []
            isUnavailable = true
        }
    }
}
