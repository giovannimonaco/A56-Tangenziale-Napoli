import CoreLocation
import Foundation
import MapKit
import Testing
@testable import TangenzialeNapoli

@Suite("Routing boundaries and access evidence")
struct RoutingBoundaryTests {
    @Test(arguments: Direction.allCases)
    func `Endpoints on each mainline are not invented interchanges`(_ direction: Direction) throws {
        let runs = try traversals(A56RouteGeometry.coordinates(for: direction))
        #expect(runs.count == 1)
        #expect(runs.first?.direction == direction)
        #expect(runs.first?.entry == .onCarriageway)
        #expect(runs.last?.exit == .onCarriageway)
    }

    @Test(arguments: Direction.allCases)
    func `Continuous roads across both geometry ends are connections not ramps`(_ direction: Direction) throws {
        let line = A56RouteGeometry.coordinates(for: direction)
        let route = [extended(line[0], awayFrom: line[1], metres: 250)]
            + line + [extended(line.last!, awayFrom: line[line.count - 2], metres: 250)]
        let runs = try traversals(route)
        #expect(runs.count == 1)
        #expect(runs.first?.entry == .continuation(direction == .towardPozzuoli ? .capodichino : .domitiana))
        #expect(runs.last?.exit == .continuation(direction == .towardPozzuoli ? .domitiana : .capodichino))
    }

    @Test(arguments: Direction.allCases)
    func `A short exterior endpoint is not already on the mainline`(_ direction: Direction) throws {
        let line = A56RouteGeometry.coordinates(for: direction)
        let route = [extended(line[0], awayFrom: line[1], metres: 40)]
            + line + [extended(line.last!, awayFrom: line[line.count - 2], metres: 40)]
        let runs = try traversals(route)
        #expect(runs.first?.entry != .onCarriageway)
        #expect(runs.last?.exit != .onCarriageway)
        // Forty metres cannot prove continuation across a connection either.
        #expect(runs.first?.entry != .continuation(direction == .towardPozzuoli ? .capodichino : .domitiana))
        #expect(runs.last?.exit != .continuation(direction == .towardPozzuoli ? .domitiana : .capodichino))
    }

    @Test(arguments: Direction.allCases)
    func `Leaving in the final sampling interval is not arrival on A56`(_ direction: Direction) throws {
        let line = A56RouteGeometry.segment(from: 5, to: 10, direction: direction)
        let ordered = line
        let a = MKMapPoint(ordered[ordered.count - 2])
        let b = MKMapPoint(ordered.last!)
        let scale = MKMapPointsPerMeterAtLatitude(b.coordinate.latitude)
        let length = hypot(b.x - a.x, b.y - a.y)
        let offRoad = MKMapPoint(x: b.x - (b.y - a.y) / length * 35 * scale,
                                 y: b.y + (b.x - a.x) / length * 35 * scale).coordinate
        let runs = try traversals(ordered + [offRoad])
        #expect(runs.last?.exit != .onCarriageway)
        let start = MKMapPoint(ordered[0]), next = MKMapPoint(ordered[1])
        let startLength = hypot(next.x - start.x, next.y - start.y)
        let startScale = MKMapPointsPerMeterAtLatitude(start.coordinate.latitude)
        let beforeEntry = MKMapPoint(x: start.x - (next.y - start.y) / startLength * 35 * startScale,
                                     y: start.y + (next.x - start.x) / startLength * 35 * startScale).coordinate
        let entering = try traversals([beforeEntry] + ordered)
        #expect(entering.first?.entry != .onCarriageway)
    }

    @Test func `Public Capodichino routes cross the geometry boundary in both directions`() throws {
        let entering = try traversals(Self.eastEntry)
        #expect(entering.first?.direction == .towardPozzuoli)
        #expect(entering.first?.entry == .continuation(.capodichino))
        let leaving = try traversals(Self.eastExit)
        #expect(leaving.last?.direction == .towardCapodichino)
        #expect(leaving.last?.exit == .continuation(.capodichino))
    }

    @Test func `Public SS7 quater routes use connections rather than Arco Felice ramps`() throws {
        let runs = try traversals(Self.domitianaEntry)
        #expect(runs.first?.direction == .towardCapodichino)
        #expect(runs.first?.entry == .continuation(.domitiana))
        let leaving = try traversals(Self.domitianaExit)
        #expect(leaving.last?.direction == .towardPozzuoli)
        #expect(leaving.last?.exit == .continuation(.domitiana))
    }

    @Test func `A long Cuma instruction ends at the exit even when its start is far away`() throws {
        let end = CLLocationCoordinate2D(latitude: 40.8412434, longitude: 14.0927652)
        let maneuver = A56TripMatcher.Maneuver(
            instruction: "Take exit 13 toward Cuma",
            coordinate: .init(latitude: 40.8551004, longitude: 14.2207712), endCoordinate: end
        )
        let runs = try traversals(Self.cumaExit, maneuvers: [maneuver])
        #expect(runs.last?.exit == .signedInterchange(A56Line.exit(14)!))
        #expect(runs.last?.exit != .continuation(.domitiana))
        let withoutInstruction = try traversals(Self.cumaExit)
        #expect(withoutInstruction.last?.exit == .unidentified)
    }

    @Test func `Curved Capodimonte entry uses the merge rather than the next nearby exit`() throws {
        let maneuver = A56TripMatcher.Maneuver(
            instruction: "Keep right to merge onto A56",
            coordinate: .init(latitude: 40.8652925, longitude: 14.2484442),
            endCoordinate: .init(latitude: 40.8656865, longitude: 14.2470293)
        )
        let runs = try traversals(Self.capodimonteEntry, maneuvers: [maneuver])
        #expect(runs.first?.entry == .interchange(A56Line.exit(5)!))
        #expect(runs.first?.entry != .continuation(.capodichino))
        let noInstruction = try traversals(Self.capodimonteEntry)
        #expect(noInstruction.first?.entry == .unidentified)
    }

    @Test func `Via Campana public destination genuinely returns to the opposite mainline`() throws {
        let runs = try traversals(Self.viaCampanaReturn)
        #expect(runs.count == 2)
        #expect(runs.first?.direction == .towardPozzuoli)
        #expect(runs.last?.direction == .towardCapodichino)
        #expect(runs.last?.entry == .interchange(A56Line.exit(13)!))
        #expect(runs.last?.exit == .onCarriageway)
    }

    @Test(arguments: [
        ("At the roundabout, take a sharp right turn onto Via Oreste Salomone toward Secondigliano, Tangenziale", "Take a slight left turn to merge onto Tangenziale toward Ottaviano"),
        ("Alla rotatoria svolta a destra in Via Oreste Salomone verso Secondigliano", "Immettiti nella Tangenziale verso Ottaviano")
    ])
    func `Airport entrance ramp beside the opposite carriageway is not a second traversal`(_ localInstruction: String, _ mergeInstruction: String) throws {
        let local = A56TripMatcher.Maneuver(
            instruction: localInstruction,
            coordinate: .init(latitude: 40.8719583, longitude: 14.2843372),
            endCoordinate: .init(latitude: 40.873749, longitude: 14.28597)
        )
        let merge = A56TripMatcher.Maneuver(
            instruction: mergeInstruction,
            coordinate: .init(latitude: 40.873749, longitude: 14.28597),
            endCoordinate: .init(latitude: 40.8734531, longitude: 14.2853879)
        )
        let runs = try traversals(Self.airportApproach, maneuvers: [local, merge])
        #expect(runs.count == 1)
        #expect(runs.allSatisfy { $0.direction == .towardPozzuoli })
        #expect(runs.first?.entry == .interchange(A56Line.exit(1)!))
    }

    @Test(arguments: Direction.allCases)
    func `Overpasses and distant parallel roads do not become A56 traversals`(_ direction: Direction) throws {
        let line = A56RouteGeometry.coordinates(for: direction).map(MKMapPoint.init)
        let (a, b) = try #require(zip(line, line.dropFirst()).first { $0.distance(to: $1) > 300 })
        let dx = b.x - a.x, dy = b.y - a.y, magnitude = hypot(dx, dy)
        let scale = MKMapPointsPerMeterAtLatitude(a.coordinate.latitude)
        func point(_ along: Double, _ lateral: Double) -> CLLocationCoordinate2D {
            MKMapPoint(x: a.x + along * dx - lateral * scale * dy / magnitude,
                       y: a.y + along * dy + lateral * scale * dx / magnitude).coordinate
        }
        if case .withA56 = A56TripMatcher.usage(coordinates: [point(0.5, -150), point(0.5, 150)]) {
            Issue.record("An overpass was identified as A56")
        }
        if case .withA56 = A56TripMatcher.usage(coordinates: [point(0.1, 40), point(0.9, 40)]) {
            Issue.record("A parallel road outside the corridor was identified as A56")
        }
        if case .withA56 = A56TripMatcher.usage(coordinates: [point(0.1, 20), point(0.9, 20)]) {
            Issue.record("Weak parallel alignment was treated as proven motorway use")
        }
    }

    @Test(arguments: Direction.allCases)
    func `Connections do not trigger ramp closures but preserve mainline closures`(_ direction: Direction) throws {
        let line = A56RouteGeometry.coordinates(for: direction)
        let route = [extended(line[0], awayFrom: line[1], metres: 250)]
            + line + [extended(line.last!, awayFrom: line[line.count - 2], metres: 250)]
        let runs = try traversals(route)
        let now = Date(timeIntervalSince1970: 1_793_894_400)
        let rampNumber = direction == .towardPozzuoli ? 1 : 15
        let ramp = RoadClosure(id: "boundary-ramp", start: now, end: now.addingTimeInterval(3600),
                              direction: direction, fromExit: rampNumber, toExit: rampNumber,
                              rampImpacts: [.init(exitNumber: rampNumber, kind: .entrance, direction: direction)], reason: "")
        let road = RoadClosure(id: "mainline", start: now, end: now.addingTimeInterval(3600),
                              direction: direction, fromExit: 8, toExit: 9, reason: "", isFullClosure: true)
        let impacts = A56TripMatcher.impacts(on: runs, closures: [ramp, road], departure: now, duration: 1200)
        #expect(impacts.map(\.closure.id) == ["mainline"])
    }

    @Test(arguments: Direction.allCases)
    func `A closed eastern connection blocks a crossing but not an interior trip`(_ direction: Direction) throws {
        let crossing = try traversals(direction == .towardPozzuoli ? Self.eastEntry : Self.eastExit)
        let now = Date(timeIntervalSince1970: 1_793_894_400)
        // The feed's distinct terminal / airport IDs map to adjacent points
        // 1 and 2, rather than a fictitious zero-length 1-to-1 road closure.
        let connection = RoadClosure(
            id: "closed-eastern-connection", start: now, end: now.addingTimeInterval(3600),
            direction: direction, fromExit: direction == .towardPozzuoli ? 1 : 2,
            toExit: direction == .towardPozzuoli ? 2 : 1, reason: "", isFullClosure: true,
            reportedSegment: terminalSegment()
        )
        #expect(A56TripMatcher.impacts(on: crossing, closures: [connection], departure: now, duration: 1200)
            .first?.kind == .roadBlock)
        let interior = try traversals(A56RouteGeometry.segment(from: 5, to: 10, direction: direction))
        #expect(A56TripMatcher.impacts(on: interior, closures: [connection], departure: now, duration: 1200).isEmpty)
    }

    @Test(arguments: Direction.allCases, [false, true])
    func `Physical closure follows OSM connection and retains both published endpoints`(_ direction: Direction, _ reversed: Bool) throws {
        let closure = physicalClosure(direction, reversed: reversed)
        let resolved = try #require(A56RouteGeometry.resolvedReportedSegment(for: closure, direction: direction))
        let length = zip(resolved.coordinates, resolved.coordinates.dropFirst()).reduce(0.0) {
            $0 + MKMapPoint($1.0).distance(to: MKMapPoint($1.1))
        }
        #expect(length > 800 && length < 850)
        #expect(abs(length - (resolved.end - resolved.start)) < 0.1)
        let north = MKMapPoint(CLLocationCoordinate2D(latitude: 40.877, longitude: 14.28987))
        let south = MKMapPoint(CLLocationCoordinate2D(latitude: 40.87185, longitude: 14.28325))
        let northAnchor = direction == .towardPozzuoli ? resolved.startCoordinate : resolved.endCoordinate
        let southAnchor = direction == .towardPozzuoli ? resolved.endCoordinate : resolved.startCoordinate
        #expect(MKMapPoint(northAnchor).distance(to: north) < 15)
        #expect(MKMapPoint(southAnchor).distance(to: south) < 15)
        #expect(resolved.startLabel == (direction == .towardPozzuoli ? "Secondigliano-Aeroporto" : "Fine Tangenziale Napoli"))
        #expect(resolved.endLabel == (direction == .towardPozzuoli ? "Fine Tangenziale Napoli" : "Secondigliano-Aeroporto"))
        let mainline = A56RouteGeometry.coordinates(for: direction)
        let mainlineLength = zip(mainline, mainline.dropFirst()).reduce(0.0) {
            $0 + MKMapPoint($1.0).distance(to: MKMapPoint($1.1))
        }
        if direction == .towardPozzuoli {
            #expect(resolved.start < -400)
            #expect(resolved.end > 350)
        } else {
            #expect(resolved.end > mainlineLength + 400)
            #expect(resolved.start < mainlineLength - 350)
        }
        let drawn = A56RouteGeometry.closureSegment(for: closure, direction: direction)
        #expect(drawn.count == resolved.coordinates.count)
        #expect(MKMapPoint(try #require(drawn.first)).distance(to: MKMapPoint(resolved.startCoordinate)) < 0.01)
    }

    @Test(arguments: Direction.allCases)
    func `Starting on A56 beyond schematic anchor two still meets the physical closure`(_ direction: Direction) throws {
        let closure = physicalClosure(direction)
        let onA56 = try traversals(A56RouteGeometry.segment(from: 2, to: 3, direction: direction))
        #expect(onA56.first?.entry == .onCarriageway)
        #expect(A56TripMatcher.impacts(on: onA56, closures: [closure], departure: closure.start, duration: 600)
            .first?.blocksRoute == true)
        for (a, b) in [(3, 4), (5, 10)] {
            let open = try traversals(A56RouteGeometry.segment(from: a, to: b, direction: direction))
            #expect(A56TripMatcher.impacts(on: open, closures: [closure], departure: closure.start, duration: 600).isEmpty)
        }
    }

    @Test(arguments: Direction.allCases)
    func `Invalid reported coordinates cannot silently confirm schematic road blocking`(_ direction: Direction) throws {
        let closure = physicalClosure(direction, invalid: true)
        #expect(A56RouteGeometry.resolvedReportedSegment(for: closure, direction: direction) == nil)
        #expect(A56RouteGeometry.closureSegment(for: closure, direction: direction).isEmpty)
        let onA56 = try traversals(A56RouteGeometry.coordinates(for: direction))
        let impact = A56TripMatcher.impacts(on: onA56, closures: [closure], departure: closure.start, duration: 600)
        #expect(impact.first?.kind == .nearBoundary)
        #expect(impact.first?.blocksRoute == false)
    }

    @Test(arguments: Direction.allCases)
    func `A1 only stays outside A56 while its physical connection closure still applies`(_ direction: Direction) throws {
        let closure = physicalClosure(direction)
        let physical = try #require(A56RouteGeometry.resolvedReportedSegment(for: closure, direction: direction))
        let connection = direction == .towardPozzuoli
            ? Array(physical.connectionCoordinates.dropLast()) : Array(physical.connectionCoordinates.dropFirst())
        if case .withA56 = A56TripMatcher.usage(coordinates: connection) {
            Issue.record("A1 Ramo Capodichino must not become an A56 traversal")
        }
        let impacts = A56TripMatcher.impacts(on: [], closures: [closure], departure: closure.start,
                                             duration: 600, coordinates: connection)
        #expect(impacts.first?.kind == .roadBlock)
        #expect(A56TripMatcher.impacts(on: [], closures: [closure], departure: closure.start,
                                     duration: 600, coordinates: Array(connection.reversed())).isEmpty)
        let future = A56TripMatcher.nextImpactAfterTrip(on: [], closures: [closure],
                                                       departure: closure.start.addingTimeInterval(-1200),
                                                       duration: 600, coordinates: connection)
        #expect(future?.closure.id == closure.id)
        // Fresh MKDirections requests between public points on the A1 ramp,
        // 286 m westbound and 281 m eastbound, captured 2026-11-15.
        let live = Self.coordinates(direction == .towardPozzuoli ? [
            [40.8767072, 14.2896228], [40.8748695, 14.2883152],
            [40.8747577, 14.2882190], [40.8744877, 14.2879174]
        ] : [
            [40.8745955, 14.2882343], [40.8749699, 14.2885549],
            [40.8762218, 14.2894257], [40.8767987, 14.2898528]
        ])
        guard case .withoutA56 = A56TripMatcher.usage(coordinates: live) else {
            Issue.record("The public A1-only directions response must remain withoutA56")
            return
        }
        #expect(A56TripMatcher.impacts(on: [], closures: [closure], departure: closure.start,
                                     duration: 600, coordinates: live).first?.blocksRoute == true)
    }

    @Test(arguments: Direction.allCases)
    func `A connection overpass is not a closure crossing`(_ direction: Direction) throws {
        let closure = physicalClosure(direction)
        let physical = try #require(A56RouteGeometry.resolvedReportedSegment(for: closure, direction: direction))
        let road = physical.connectionCoordinates.map(MKMapPoint.init)
        let (a, b) = try #require(zip(road, road.dropFirst()).max(by: { $0.0.distance(to: $0.1) < $1.0.distance(to: $1.1) }))
        let dx = b.x - a.x, dy = b.y - a.y, magnitude = hypot(dx, dy)
        let scale = MKMapPointsPerMeterAtLatitude(a.coordinate.latitude)
        let crossing = [-200.0, 200.0].map {
            MKMapPoint(x: (a.x + b.x) / 2 - dy / magnitude * scale * $0,
                       y: (a.y + b.y) / 2 + dx / magnitude * scale * $0).coordinate
        }
        #expect(A56TripMatcher.impacts(on: [], closures: [closure], departure: closure.start,
                                     duration: 600, coordinates: crossing).isEmpty)
    }

    private func terminalSegment(reversed: Bool = false, invalid: Bool = false) -> RoadClosure.ReportedSegment {
        let first = RoadClosure.ReportedSegment.Point(latitude: 40.877, longitude: invalid ? 14.30 : 14.28987)
        let second = RoadClosure.ReportedSegment.Point(latitude: 40.87185, longitude: 14.28325)
        return .init(first: reversed ? second : first, second: reversed ? first : second,
                     firstLabel: reversed ? "Fine Tangenziale Napoli" : "Secondigliano-Aeroporto",
                     secondLabel: reversed ? "Secondigliano-Aeroporto" : "Fine Tangenziale Napoli")
    }

    private func physicalClosure(_ direction: Direction, reversed: Bool = false, invalid: Bool = false) -> RoadClosure {
        let now = Date(timeIntervalSince1970: 1_793_894_400)
        return RoadClosure(id: "physical-terminal", start: now, end: now.addingTimeInterval(3600), direction: direction,
                           fromExit: direction == .towardPozzuoli ? 1 : 2, toExit: direction == .towardPozzuoli ? 2 : 1,
                           reason: "", isFullClosure: true, reportedSegment: terminalSegment(reversed: reversed, invalid: invalid))
    }

    private func traversals(_ coordinates: [CLLocationCoordinate2D], maneuvers: [A56TripMatcher.Maneuver] = []) throws -> [A56TripMatcher.Traversal] {
        guard case .withA56(let runs) = A56TripMatcher.usage(coordinates: coordinates, maneuvers: maneuvers) else {
            Issue.record("Expected A56 traversal")
            return []
        }
        return runs
    }

    private func extended(_ endpoint: CLLocationCoordinate2D, awayFrom interior: CLLocationCoordinate2D, metres: Double) -> CLLocationCoordinate2D {
        let a = MKMapPoint(endpoint), b = MKMapPoint(interior)
        let factor = metres / a.distance(to: b)
        return MKMapPoint(x: a.x + (a.x - b.x) * factor, y: a.y + (a.y - b.y) * factor).coordinate
    }

    private static func coordinates(_ pairs: [[Double]]) -> [CLLocationCoordinate2D] {
        pairs.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }

    // Public MKDirections geometry captured on 2026-11-15. No live network
    // request or personal location is used by this suite. See route-boundary-fix.md.
    private static var eastEntry: [CLLocationCoordinate2D] { coordinates([
        [40.8772327, 14.2900298],
        [40.8763477, 14.2893542],
        [40.8748695, 14.2883152],
        [40.8747577, 14.2882190],
        [40.8745346, 14.2879796],
        [40.8743267, 14.2876883],
        [40.8741713, 14.2873979],
        [40.8736929, 14.2862167],
        [40.8734597, 14.2857051],
        [40.8732794, 14.2854017],
        [40.8731261, 14.2851871],
        [40.8724398, 14.2843647],
        [40.8723272, 14.2842104],
        [40.8722157, 14.2840314],
        [40.8720919, 14.2837793],
        [40.8720136, 14.2835697],
        [40.8719489, 14.2833226],
        [40.8719003, 14.2830454],
        [40.8718767, 14.2826853],
        [40.8719053, 14.2822263],
        [40.8723036, 14.2799011],
    ]) }

    private static var eastExit: [CLLocationCoordinate2D] { coordinates([
        [40.8720907, 14.2805422],
        [40.8718067, 14.2821676],
        [40.8717710, 14.2825217],
        [40.8717727, 14.2827523],
        [40.8718011, 14.2830987],
        [40.8718458, 14.2833521],
        [40.8719363, 14.2836804],
        [40.8720166, 14.2838852],
        [40.8721335, 14.2841199],
        [40.8722575, 14.2843150],
        [40.8723858, 14.2844914],
        [40.8729293, 14.2851304],
        [40.8731174, 14.2853752],
        [40.8732832, 14.2856317],
        [40.8735743, 14.2862254],
        [40.8740610, 14.2874318],
        [40.8742243, 14.2877479],
        [40.8744294, 14.2880400],
        [40.8746208, 14.2882639],
        [40.8749699, 14.2885549],
        [40.8762218, 14.2894257],
        [40.8767906, 14.2898464],
    ]) }

    private static var domitianaEntry: [CLLocationCoordinate2D] { coordinates([
        [40.8400011, 14.0850034],
        [40.8397670, 14.0852462],
        [40.8395278, 14.0856026],
        [40.8393693, 14.0859489],
        [40.8392942, 14.0861836],
        [40.8392039, 14.0866208],
        [40.8391783, 14.0868508],
        [40.8391628, 14.0873386],
        [40.8391755, 14.0876746],
        [40.8392252, 14.0882238],
        [40.8393312, 14.0888672],
        [40.8393987, 14.0891716],
        [40.8395570, 14.0897312],
        [40.8397457, 14.0902515],
        [40.8398979, 14.0906143],
        [40.8402119, 14.0912567],
        [40.8410315, 14.0927017],
        [40.8420275, 14.0944267],
        [40.8422581, 14.0948445],
        [40.8424382, 14.0952347],
        [40.8425198, 14.0954587],
    ]) }

    private static var cumaExit: [CLLocationCoordinate2D] { coordinates([
        [40.8415722, 14.1004164],
        [40.8423278, 14.0989519],
        [40.8425394, 14.0984748],
        [40.8426877, 14.0980024],
        [40.8427905, 14.0974663],
        [40.8428270, 14.0969715],
        [40.8428123, 14.0964565],
        [40.8427369, 14.0959274],
        [40.8426101, 14.0954392],
        [40.8425416, 14.0952428],
        [40.8423149, 14.0947161],
        [40.8422086, 14.0945089],
        [40.8415869, 14.0934497],
        [40.8413911, 14.0931470],
        [40.8412434, 14.0927652],
        [40.8406492, 14.0915511],
        [40.8405574, 14.0912858],
        [40.8405064, 14.0910592],
        [40.8404826, 14.0908828],
        [40.8404686, 14.0905663],
        [40.8405178, 14.0902800],
        [40.8406464, 14.0899823],
        [40.8410337, 14.0895847],
        [40.8410908, 14.0894666],
        [40.8411243, 14.0893312],
        [40.8411334, 14.0885889],
        [40.8411636, 14.0879073],
        [40.8411994, 14.0877101],
        [40.8413130, 14.0874406],
        [40.8413970, 14.0872991],
        [40.8414347, 14.0871869],
        [40.8414550, 14.0870429],
        [40.8414479, 14.0869219],
        [40.8413414, 14.0865766],
        [40.8413409, 14.0862741],
        [40.8414019, 14.0860468],
        [40.8415689, 14.0853944],
    ]) }

    private static var capodimonteEntry: [CLLocationCoordinate2D] { coordinates([
        [40.8652925, 14.2484442],
        [40.8653146, 14.2485548],
        [40.8653739, 14.2486326],
        [40.8654702, 14.2486987],
        [40.8656003, 14.2487369],
        [40.8656931, 14.2487329],
        [40.8658171, 14.2486903],
        [40.8659236, 14.2486192],
        [40.8660128, 14.2485257],
        [40.8660956, 14.2483717],
        [40.8661171, 14.2482594],
        [40.8660876, 14.2481227],
        [40.8658146, 14.2476124],
        [40.8653326, 14.2468278],
        [40.8653181, 14.2467782],
        [40.8653450, 14.2466803],
        [40.8654129, 14.2466360],
        [40.8654490, 14.2466438],
        [40.8654857, 14.2466820],
        [40.8656865, 14.2470293],
        [40.8656988, 14.2470848],
        [40.8657413, 14.2472489],
        [40.8657864, 14.2473455],
        [40.8658962, 14.2475265],
        [40.8660509, 14.2476801],
        [40.8661429, 14.2477260],
        [40.8662400, 14.2477485],
        [40.8663387, 14.2477441],
        [40.8664157, 14.2477113],
        [40.8665534, 14.2475738],
        [40.8666074, 14.2474665],
        [40.8666264, 14.2473431],
        [40.8665912, 14.2449570],
        [40.8666209, 14.2446683],
        [40.8666632, 14.2445131],
        [40.8667243, 14.2444101],
        [40.8668156, 14.2443260],
        [40.8669626, 14.2442432],
        [40.8671034, 14.2442147],
        [40.8672497, 14.2442164],
        [40.8674718, 14.2442804],
        [40.8675562, 14.2442643],
        [40.8676396, 14.2442194],
        [40.8677022, 14.2441580],
        [40.8677575, 14.2440615],
        [40.8677927, 14.2439511],
        [40.8678130, 14.2437922],
        [40.8678113, 14.2436702],
        [40.8677856, 14.2435428],
        [40.8677329, 14.2433966],
        [40.8676330, 14.2432387],
        [40.8670742, 14.2425507],
        [40.8668952, 14.2423626],
        [40.8667499, 14.2422805],
        [40.8666673, 14.2422721],
        [40.8664817, 14.2422064],
        [40.8662963, 14.2421407],
        [40.8661394, 14.2420609],
        [40.8661043, 14.2419910],
        [40.8660691, 14.2419211],
        [40.8659986, 14.2418439],
        [40.8653934, 14.2412575],
        [40.8649385, 14.2408991],
        [40.8648257, 14.2407533],
        [40.8644847, 14.2399583],
        [40.8641890, 14.2393072],
        [40.8640050, 14.2390249],
        [40.8626930, 14.2357496],
        [40.8620619, 14.2339331],
        [40.8617130, 14.2329823],
        [40.8611034, 14.2314668],
        [40.8576186, 14.2227999],
    ]) }

    private static var viaCampanaReturn: [CLLocationCoordinate2D] { coordinates([
        [40.8365631, 14.1230107],
        [40.8366681, 14.1226744],
        [40.8368099, 14.1223006],
        [40.8371381, 14.1216682],
        [40.8380254, 14.1202155],
        [40.8382083, 14.1198819],
        [40.8384244, 14.1194001],
        [40.8385700, 14.1189750],
        [40.8386502, 14.1186776],
        [40.8387529, 14.1181770],
        [40.8393231, 14.1145959],
        [40.8394010, 14.1144377],
        [40.8394482, 14.1142178],
        [40.8395025, 14.1140156],
        [40.8395415, 14.1139368],
        [40.8395991, 14.1138600],
        [40.8397036, 14.1137671],
        [40.8398190, 14.1137373],
        [40.8398878, 14.1137420],
        [40.8400204, 14.1137916],
        [40.8401718, 14.1139455],
        [40.8402479, 14.1140793],
        [40.8404775, 14.1148155],
        [40.8405523, 14.1149728],
        [40.8406594, 14.1151283],
        [40.8407585, 14.1152279],
        [40.8409224, 14.1153523],
        [40.8413959, 14.1156386],
        [40.8415684, 14.1156296],
        [40.8416417, 14.1156797],
        [40.8419073, 14.1158773],
        [40.8422190, 14.1162693],
        [40.8423400, 14.1165120],
        [40.8424204, 14.1167675],
        [40.8424011, 14.1168849],
        [40.8424295, 14.1170260],
        [40.8425079, 14.1171296],
        [40.8425645, 14.1171594],
        [40.8426251, 14.1171672],
        [40.8426943, 14.1171474],
        [40.8427471, 14.1171071],
        [40.8427948, 14.1170377],
        [40.8428209, 14.1169373],
        [40.8428285, 14.1168849],
        [40.8428168, 14.1167923],
        [40.8426727, 14.1164886],
        [40.8425728, 14.1163216],
        [40.8424658, 14.1161915],
        [40.8422183, 14.1160128],
        [40.8420455, 14.1159223],
        [40.8419073, 14.1158773],
        [40.8418110, 14.1158036],
        [40.8415684, 14.1156296],
        [40.8410713, 14.1153349],
        [40.8408311, 14.1151444],
        [40.8407332, 14.1150365],
        [40.8406500, 14.1148990],
        [40.8405267, 14.1146194],
        [40.8402921, 14.1138999],
        [40.8401320, 14.1135361],
        [40.8401866, 14.1134620],
        [40.8402030, 14.1133742],
        [40.8401866, 14.1132863],
        [40.8401320, 14.1132122],
        [40.8400609, 14.1131881],
        [40.8399902, 14.1132122],
        [40.8399042, 14.1131073],
        [40.8398558, 14.1129993],
        [40.8398311, 14.1127177],
        [40.8398089, 14.1124937],
        [40.8397338, 14.1122466],
        [40.8396204, 14.1121035],
        [40.8395032, 14.1120187],
        [40.8393548, 14.1119814],
        [40.8392706, 14.1119902],
        [40.8391641, 14.1120381],
        [40.8391004, 14.1120938],
        [40.8389896, 14.1122517],
        [40.8389429, 14.1123801],
        [40.8389201, 14.1125192],
        [40.8389224, 14.1126560],
        [40.8389505, 14.1127817],
        [40.8389987, 14.1128917],
        [40.8391681, 14.1131727],
        [40.8392169, 14.1132927],
        [40.8392541, 14.1134027],
        [40.8392749, 14.1137383],
        [40.8392671, 14.1138898],
        [40.8391862, 14.1144055],
        [40.8392146, 14.1145906],
        [40.8388295, 14.1170462],
    ]) }

    private static var domitianaExit: [CLLocationCoordinate2D] { coordinates([
        [40.8426101, 14.0954392],
        [40.8424572, 14.0950373],
        [40.8422086, 14.0945089],
        [40.8415869, 14.0934497],
        [40.8413911, 14.0931470],
        [40.8406994, 14.0919678],
        [40.8402974, 14.0912443],
        [40.8398992, 14.0904128],
        [40.8397954, 14.0901623],
        [40.8396070, 14.0896279],
        [40.8395187, 14.0893245],
        [40.8393832, 14.0887341],
        [40.8392843, 14.0880769],
        [40.8392554, 14.0877403],
        [40.8392397, 14.0871170],
        [40.8392526, 14.0868682],
        [40.8393063, 14.0864675],
    ]) }

    private static var airportApproach: [CLLocationCoordinate2D] { coordinates([
        [40.8719583, 14.2843372],
        [40.8722585, 14.2846956],
        [40.8724172, 14.2848213],
        [40.8726814, 14.2849648],
        [40.8729184, 14.2852008],
        [40.8732183, 14.2856377],
        [40.8733618, 14.2858952],
        [40.8734883, 14.2860689],
        [40.8735091, 14.2861530],
        [40.8735659, 14.2862201],
        [40.8736313, 14.2862392],
        [40.8736929, 14.2862167],
        [40.8737388, 14.2861638],
        [40.8737637, 14.2860748],
        [40.8737490, 14.2859700],
        [40.8736085, 14.2857711],
        [40.8734531, 14.2853879],
        [40.8734164, 14.2853442],
        [40.8729930, 14.2848465],
        [40.8725620, 14.2843335],
        [40.8723422, 14.2840317],
        [40.8722083, 14.2837746],
        [40.8719003, 14.2830454],
        [40.8718767, 14.2826853],
        [40.8719053, 14.2822263],
        [40.8723036, 14.2799011],
        [40.8723457, 14.2795203],
        [40.8723619, 14.2788574],
        [40.8723424, 14.2786137],
        [40.8722600, 14.2780813],
        [40.8721140, 14.2775881],
        [40.8719327, 14.2771388],
        [40.8714786, 14.2763351],
        [40.8705312, 14.2747526],
        [40.8703573, 14.2744197],
        [40.8701932, 14.2740630],
        [40.8699445, 14.2734528],
        [40.8697465, 14.2728828],
        [40.8695554, 14.2722106],
    ]) }

}
