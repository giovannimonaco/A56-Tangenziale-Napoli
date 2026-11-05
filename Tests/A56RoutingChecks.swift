import Foundation
import MapKit

/// Run with Tests/check-a56.sh. Pass snapshots of the two public feeds to
/// also audit which current A56 occurrences each mapper can locate.
@main
struct A56RoutingChecks {
    static func main() async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let now = Date(timeIntervalSince1970: 1_793_894_400)
        let start = now.addingTimeInterval(600)
        let end = now.addingTimeInterval(3600)

        func event(_ fields: [String: Any]) throws -> AutostradeEvent {
            try decoder.decode(AutostradeEvent.self, from: JSONSerialization.data(withJSONObject: fields))
        }

        let terminalFields: [String: Any] = [
            "c_str": "A56", "c_ele": "terminal-example", "c_dir": "N",
            "t_des_fra_it": "Tratto Chiuso", "t_des_dir_it": "Pozzuoli",
            "locpri": "Capodichino", "c_pnt_dtx_pls_pri": 11071, "c_pnt_dtx_pls_sec": 1117,
            "t_des_it": "Tratto Chiuso tra Fine Tangenziale Napoli e Capodichino Svincolo dalle ore 23:59 alle ore 06:00",
            "d_sta": start.timeIntervalSince1970 * 1000, "d_sto": end.timeIntervalSince1970 * 1000
        ]
        let planned = AutostradeClosureMapper.mappingReport(from: [try event(terminalFields)], now: now)
        precondition(planned.isComplete && planned.closures.count == 1)
        precondition(planned.closures.first?.fromExit == 1 && planned.closures.first?.toExit == 2)
        precondition(A56Line.resolveExit(named: "Doganella/Viale Umberto Maddalena") == 3)
        precondition(A56Line.resolveExit(pointID: 11228, named: "Pozzuoli") == 15)

        let opposing = terminalFields.merging(["c_dir": "P"]) { _, value in value }
        let conflicting = AutostradeClosureMapper.mappingReport(from: [try event(opposing)], now: now)
        precondition(!conflicting.isComplete && conflicting.closures.isEmpty)

        let daily = terminalFields.merging(["indisponibilita": [
            ["d_ini": start.timeIntervalSince1970 * 1000, "d_fin": end.timeIntervalSince1970 * 1000],
            ["d_ini": "campo illeggibile"]
        ]]) { _, value in value }
        let partlyRead = AutostradeClosureMapper.mappingReport(from: [try event(daily)], now: now)
        precondition(partlyRead.expectedOccurrences == 2 && partlyRead.mappedOccurrences == 1)

        let realtimeFields = terminalFields.merging([
            "c_grp_tip": "C", "fino_al": "202611090600P01",
            "d_sta": now.addingTimeInterval(-900).timeIntervalSince1970 * 1000,
            "d_agg": now.addingTimeInterval(-900).timeIntervalSince1970 * 1000
        ]) { _, value in value }
        let live = AutostradeRealtimeClosureMapper.mappingReport(from: [try event(realtimeFields)], now: now)
        precondition(live.isComplete && live.closures.first?.fromExit == 1 && live.closures.first?.toExit == 2)

        for direction in Direction.allCases {
            var line = A56RouteGeometry.segment(from: 5, to: 10, direction: direction)
            if (line[0].longitude > line.last!.longitude) != direction.goesUpTheLine {
                line.reverse()
            }
            guard case .withA56(let sections) = A56TripMatcher.usage(coordinates: line),
                  sections.allSatisfy({ $0.direction == direction }) else {
                preconditionFailure("A56 carriageway was not recognized: \(direction)")
            }

            precondition(sections.count == 1 && sections[0].entry == .onCarriageway
                && sections[0].exit == .onCarriageway)

            let opposite: Direction = direction == .towardPozzuoli ? .towardCapodichino : .towardPozzuoli
            let closures = [
                RoadClosure(id: "on-route", start: start, end: end, direction: direction,
                            fromExit: 8, toExit: 9, reason: "", isFullClosure: true),
                RoadClosure(id: "opposite", start: start, end: end, direction: opposite,
                            fromExit: 8, toExit: 9, reason: "", isFullClosure: true),
                RoadClosure(id: "outside", start: start, end: end, direction: direction,
                            fromExit: 12, toExit: 13, reason: "", isFullClosure: true),
                RoadClosure(id: "later", start: end, end: end.addingTimeInterval(3600), direction: direction,
                            fromExit: 8, toExit: 9, reason: "", isFullClosure: true),
                RoadClosure(id: "passing-closed-ramp", start: start, end: end, direction: direction,
                            fromExit: 8, toExit: 8,
                            rampImpacts: [.init(exitNumber: 8, kind: .exit, direction: direction)], reason: "")
            ]
            let impacts = A56TripMatcher.impacts(on: sections, closures: closures, departure: now, duration: 1200)
            precondition(impacts.map(\.closure.id) == ["on-route"] && impacts.first?.kind == .roadBlock)

            let startsInHalfHour = now.addingTimeInterval(1800)
            let scheduled = RoadClosure(id: "scheduled", start: startsInHalfHour, end: end,
                                        direction: direction, fromExit: 8, toExit: 9, reason: "", isFullClosure: true)
            let earlierOpposite = RoadClosure(id: "earlier-opposite", start: now.addingTimeInterval(1500), end: end,
                                              direction: opposite, fromExit: 8, toExit: 9, reason: "", isFullClosure: true)
            let upcoming = closures + [earlierOpposite, scheduled]
            precondition(A56TripMatcher.nextImpactAfterTrip(
                on: sections, closures: upcoming, departure: now, duration: 1200
            )?.closure.id == "scheduled")

            let longTrip = A56TripMatcher.impacts(on: sections, closures: upcoming, departure: now, duration: 2400)
            precondition(Set(longTrip.map(\.closure.id)) == ["on-route", "scheduled"])
            precondition(A56TripMatcher.nextImpactAfterTrip(
                on: sections, closures: upcoming, departure: now, duration: 2400
            )?.closure.id == "later")
        }

        let eastbound = Direction.towardCapodichino
        let ramp = RoadClosure(start: start, end: end, direction: eastbound, fromExit: 9, toExit: 9,
                               rampImpacts: [.init(exitNumber: 9, kind: .entrance, direction: eastbound)],
                               reason: "")
        var rampRoute = A56RouteGeometry.segment(from: 9, to: 8, direction: eastbound)
        if rampRoute[0].longitude > rampRoute.last!.longitude { rampRoute.reverse() }
        let entrance = rampRoute[0]
        rampRoute.insert(CLLocationCoordinate2D(latitude: entrance.latitude,
                                                longitude: entrance.longitude - 0.004), at: 0)
        guard case .withA56(let entering) = A56TripMatcher.usage(coordinates: rampRoute) else {
            preconditionFailure("Entrance route did not match A56")
        }
        precondition(A56TripMatcher.impacts(on: entering, closures: [ramp], departure: now, duration: 1200)
            .first?.kind == .ramp)
        precondition(entering.first?.entry == A56Line.exit(9).map(A56TripMatcher.Access.interchange)
            && entering.last?.exit == .onCarriageway)


        let point = A56RouteGeometry.coordinate(for: 10, direction: .towardPozzuoli)!
        let crossing = [-0.004, 0.004].map {
            CLLocationCoordinate2D(latitude: point.latitude + $0, longitude: point.longitude)
        }
        guard case .withoutA56 = A56TripMatcher.usage(coordinates: crossing),
              case .uncertain = A56TripMatcher.usage(coordinates: crossing, mentionsA56: true)
        else { preconditionFailure("A crossing is not a traversal, and conflicting route labels require verification") }
        // A short road beside a straight carriageway is neither a crossing
        // nor proof of motorway use (as at Capodichino's airport access).
        let mainline = A56RouteGeometry.coordinates(for: .towardPozzuoli).map(MKMapPoint.init)
        let straight = zip(mainline, mainline.dropFirst()).first { $0.distance(to: $1) > 200 }!
        let a = straight.0
        let b = straight.1
        let length = a.distance(to: b)
        let dx = (b.x - a.x) / length
        let dy = (b.y - a.y) / length
        func shortSegment(offset: Double) -> [CLLocationCoordinate2D] {
            [length / 2 - 34, length / 2 + 34].map {
                MKMapPoint(x: a.x + $0 * dx - offset * dy,
                           y: a.y + $0 * dy + offset * dx).coordinate
            }
        }
        guard case .withoutA56 = A56TripMatcher.usage(coordinates: shortSegment(offset: 18)),
              case .uncertain = A56TripMatcher.usage(coordinates: shortSegment(offset: 0))
        else { preconditionFailure("A brief adjacent street must be distinguished from a close A56 overlap") }
        checkNavigationLinks()
        print("A56 geometry, closure impact and feed regression checks passed.")
        try await FeedResilienceChecks.run()
        try await NoticeMatrixChecks.run()

        if CommandLine.arguments.count == 3 {
            let feeds = try CommandLine.arguments.dropFirst().map {
                try decoder.decode(AutostradeFeed.self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
            }
            let planned = AutostradeClosureMapper.mappingReport(from: feeds[0].events)
            let live = AutostradeRealtimeClosureMapper.mappingReport(from: feeds[1].events)
            print("Current snapshots: planned \(planned.mappedOccurrences)/\(planned.expectedOccurrences), live \(live.mappedEvents)/\(live.expectedEvents)")
            for issue in planned.issues + live.issues {
                print("\(issue.eventID): \(issue.summary)")
            }
            precondition(feeds.allSatisfy { $0.undecodedEventCount == 0 })
            precondition(planned.expectedOccurrences == planned.mappedOccurrences && live.expectedEvents == live.mappedEvents,
                         "The snapshot contains unmapped A56 closures")
        }
    }

    private static func checkNavigationLinks() {
        let origin = CLLocationCoordinate2D(latitude: 40.8783, longitude: 14.28157)
        let destination = CLLocationCoordinate2D(latitude: 40.82176, longitude: 14.12059)
        let stops = A56Line.exits.prefix(4).map(\.coordinate)
        let motorway = TripNavigationLinks(origin: origin, destination: destination, waypoints: stops, avoidsHighways: false)
        let bypass = TripNavigationLinks(origin: origin, destination: destination, waypoints: [], avoidsHighways: true)

        func query(_ url: URL?) -> [URLQueryItem] {
            url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        }

        let apple = query(motorway.appleMapsURL(supportsUnifiedURLs: true))
        precondition(apple.filter { $0.name == "waypoint" }.count == 4)
        precondition(apple.contains(.init(name: "source", value: "40.878300,14.281570")))
        precondition(!apple.contains { $0.name == "avoid" })
        let google = query(motorway.googleMapsURL)
        precondition(google.first { $0.name == "waypoints" }?.value?.split(separator: "|").count == 3)

        for url in [bypass.appleMapsURL(supportsUnifiedURLs: true), bypass.googleMapsURL] {
            let items = query(url)
            precondition(items.contains(.init(name: "avoid", value: "highways,tolls")))
            precondition(!items.contains { $0.name.hasPrefix("waypoint") })
        }
        let legacy = query(bypass.appleMapsURL(supportsUnifiedURLs: false))
        precondition(legacy.contains(.init(name: "daddr", value: "40.821760,14.120590")))
        precondition(!legacy.contains { $0.name == "avoid" })
    }

}
