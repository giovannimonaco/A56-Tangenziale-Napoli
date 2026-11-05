import MapKit

/// Matches a route to directed stretches of the A56, rather than treating
/// crossing a line on the map or passing an exit as using that road.
nonisolated enum A56TripMatcher {
    enum Usage {
        case withA56([Traversal])
        case withoutA56
        case uncertain
    }

    struct Traversal {
        let direction: Direction
        let start: Double // metres along this carriageway in travel order
        let end: Double
        let entry: Access
        let exit: Access
    }

    enum Access: Equatable {
        case signedInterchange(A56Exit)
        case interchange(A56Exit)
        case onCarriageway
        case unidentified
    }

    struct Maneuver {
        let instruction: String
        let coordinate: CLLocationCoordinate2D
    }

    struct Impact {
        enum Kind: Int {
            case roadBlock, closedRamp, ramp, nearBoundary
        }

        let closure: RoadClosure
        let kind: Kind
        let ramp: ClosureRampImpact?

        var blocksRoute: Bool { kind == .roadBlock || kind == .closedRamp }
    }

    private struct Projection {
        let distance: Double
        let position: Double
    }

    private struct Segment {
        let from: MKMapPoint
        let dx: Double
        let dy: Double
        let length: Double
        let start: Double

        init?(_ from: MKMapPoint, _ to: MKMapPoint, start: Double) {
            let length = from.distance(to: to)
            guard length > 0 else { return nil }
            self.from = from
            self.dx = to.x - from.x
            self.dy = to.y - from.y
            self.length = length
            self.start = start
        }

        func project(_ point: MKMapPoint, heading: Segment?) -> Projection? {
            let squared = dx * dx + dy * dy
            if let heading {
                let dot = dx * heading.dx + dy * heading.dy
                let otherSquared = heading.dx * heading.dx + heading.dy * heading.dy
                guard dot > 0, dot * dot >= 0.75 * squared * otherSquared else { return nil }
            }
            let offsetX = point.x - from.x
            let offsetY = point.y - from.y
            let fraction = max(0, min(1, (offsetX * dx + offsetY * dy) / squared))
            let nearest = MKMapPoint(x: from.x + fraction * dx, y: from.y + fraction * dy)
            let distance = point.distance(to: nearest)
            return Projection(distance: distance, position: start + fraction * length)
        }
    }

    private struct Carriageway {
        let direction: Direction
        let byLongitude: [Int: [Segment]]
        let exits: [Int: Double]

        init(direction: Direction) {
            self.direction = direction
            var coordinates = A56RouteGeometry.coordinates(for: direction)
            // The stored geometry's order is independent of the travel direction.
            if let first = coordinates.first, let last = coordinates.last,
               (first.longitude > last.longitude) != direction.goesUpTheLine {
                coordinates.reverse()
            }
            let segments = A56TripMatcher.segments(coordinates.map(MKMapPoint.init))
            var buckets: [Int: [Segment]] = [:]
            for segment in segments {
                let first = Self.bucket(segment.from.x)
                let last = Self.bucket(segment.from.x + segment.dx)
                for cell in min(first, last)...max(first, last) {
                    buckets[cell, default: []].append(segment)
                }
            }
            byLongitude = buckets
            exits = Dictionary(uniqueKeysWithValues: A56Line.exits.compactMap { exit in
                let point = MKMapPoint(exit.coordinate)
                guard let nearest = segments.compactMap({ $0.project(point, heading: nil) })
                    .min(by: { $0.distance < $1.distance }) else { return nil }
                return (exit.number, nearest.position)
            })
        }

        static func bucket(_ x: Double) -> Int { Int(x / 4096) }
    }

    private struct Match {
        let direction: Direction
        let position: Double
        let routePosition: Double
        let distance: Double
        let point: MKMapPoint
    }

    private struct Run {
        let first: Match
        var last: Match
        var samples = 0
        var closeSamples = 0

        mutating func append(_ match: Match) {
            last = match
            samples += 1
            if match.distance <= 12 { closeSamples += 1 }
        }
    }

    private static let carriageways = Direction.allCases.map(Carriageway.init)

    private static let sampleSpacing = 22.0
    private static let corridorWidth = 25.0
    private static let minimumRun = 125.0
    private static let boundaryTolerance = 100.0
    // Entry/exit geometry is inferred from the mainline. Near a closed ramp
    // we report possible impact, never a positive match from proximity alone.
    private static let rampTolerance = 600.0

    private static func segments(_ points: [MKMapPoint]) -> [Segment] {
        var distance = 0.0
        return zip(points, points.dropFirst()).compactMap { from, to in
            guard let segment = Segment(from, to, start: distance) else { return nil }
            distance += segment.length
            return segment
        }
    }

    static func usage(
        coordinates: [CLLocationCoordinate2D],
        mentionsA56: Bool = false,
        maneuvers: [Maneuver] = []
    ) -> Usage {
        let route = segments(coordinates.map(MKMapPoint.init))
        guard let last = route.last else { return .uncertain }
        let length = last.start + last.length
        var runs: [Run] = []
        var run: Run?
        var hasShortMatch = false

        func finishRun() {
            guard let current = run else { return }
            run = nil
            let covered = current.last.routePosition - current.first.routePosition
            let progress = current.last.position - current.first.position
            if covered >= minimumRun, progress >= minimumRun * 0.75,
               current.closeSamples >= 3, current.closeSamples * 3 >= current.samples {
                if let previous = runs.last,
                   staysOnCarriageway(from: previous.last, to: current.first, route: route, maneuvers: maneuvers) {
                    runs[runs.count - 1].last = current.last
                } else {
                    runs.append(current)
                }
            } else if (current.closeSamples >= 3 && progress >= 28)
                        || (covered >= 88 && progress >= 66) {
                // A brief near-parallel stretch on a frontage road is common
                // around Capodichino. Treat weak alignment as ambiguous only
                // when sustained, or when several samples are close.
                hasShortMatch = true
            }
        }

        // Sample at regular distances across the entire route. Sparse vertices
        // and diagonal crossings must not turn into long false overlaps.
        var segmentIndex = 0
        var offset = min(sampleSpacing / 2, length / 2)
        while offset < length {
            while segmentIndex < route.count - 1,
                  offset >= route[segmentIndex].start + route[segmentIndex].length {
                segmentIndex += 1
            }
            let segment = route[segmentIndex]
            let fraction = (offset - segment.start) / segment.length
            let point = MKMapPoint(x: segment.from.x + fraction * segment.dx,
                                   y: segment.from.y + fraction * segment.dy)
            offset += sampleSpacing
            let match = bestMatch(point, heading: segment, routePosition: offset - sampleSpacing)
            guard let match else {
                // Allow a single gap where the source geometries differ near ramps.
                if let run, offset - sampleSpacing - run.last.routePosition > 1.5 * sampleSpacing {
                    finishRun()
                }
                continue
            }
            if let previous = run?.last {
                let advance = match.position - previous.position
                if previous.direction != match.direction || advance < -8
                    || advance > (match.routePosition - previous.routePosition) + 40 {
                    finishRun()
                }
            }
            if run == nil {
                run = Run(first: match, last: match)
            }
            run?.append(match)
        }
        finishRun()

        if !runs.isEmpty {
            return .withA56(runs.map {
                Traversal(
                    direction: $0.first.direction,
                    start: $0.first.position,
                    end: $0.last.position,
                    entry: $0.first.routePosition <= 55 ? .onCarriageway : access(at: $0.first, entering: true, maneuvers: maneuvers),
                    exit: length - $0.last.routePosition <= 55 ? .onCarriageway : access(at: $0.last, entering: false, maneuvers: maneuvers)
                )
            })
        }
        return hasShortMatch || mentionsA56 ? .uncertain : .withoutA56
    }

    /// A brief loss of alignment in the two map sources, for example in a
    /// tunnel, is not an exit followed by a new entrance.
    private static func staysOnCarriageway(
        from first: Match, to next: Match, route: [Segment], maneuvers: [Maneuver]
    ) -> Bool {
        let routeGap = next.routePosition - first.routePosition
        let carriagewayGap = next.position - first.position
        guard first.direction == next.direction, routeGap > 0, routeGap <= 650,
              carriagewayGap > 0, abs(routeGap - carriagewayGap) <= max(45, routeGap * 0.15)
        else { return false }

        let gap = first.routePosition...next.routePosition
        let gapSegments = route.filter { $0.start <= gap.upperBound && $0.start + $0.length >= gap.lowerBound }
        for maneuver in maneuvers where isExitInstruction(A56Line.normalize(maneuver.instruction)) {
            let point = MKMapPoint(maneuver.coordinate)
            if gapSegments.contains(where: {
                guard let projection = $0.project(point, heading: nil) else { return false }
                return projection.distance < 25 && gap.contains(projection.position)
            }) { return false }
        }

        // Short gaps with near-identical progress can occur on curves, where
        // Apple's heading briefly differs from the stored carriageway.
        if routeGap <= 180 { return true }

        return [0.25, 0.5, 0.75].allSatisfy { fraction in
            let offset = first.routePosition + routeGap * fraction
            guard let segment = gapSegments.first(where: { offset >= $0.start && offset <= $0.start + $0.length })
            else { return false }
            let t = (offset - segment.start) / segment.length
            let point = MKMapPoint(x: segment.from.x + t * segment.dx, y: segment.from.y + t * segment.dy)
            guard let match = bestMatch(point, heading: segment, routePosition: offset, maxDistance: 90)
            else { return false }
            return match.direction == first.direction
                && abs(match.position - (first.position + carriagewayGap * fraction)) <= 100
        }
    }

    private static func access(at match: Match, entering: Bool, maneuvers: [Maneuver]) -> Access {
        guard let way = carriageways.first(where: { $0.direction == match.direction }) else {
            return .unidentified
        }
        let candidates = A56Line.exits.compactMap { junction -> (junction: A56Exit, distance: Double)? in
            guard entering || !junction.isEntranceOnly, let position = way.exits[junction.number] else { return nil }
            let distance = abs(position - match.position)
            return distance <= rampTolerance ? (junction, distance) : nil
        }.sorted { $0.distance < $1.distance }

        var signs = Set<A56Exit>()
        var numberedSigns = Set<A56Exit>()
        for maneuver in maneuvers {
            let distance = match.point.distance(to: MKMapPoint(maneuver.coordinate))
            guard distance <= 900 else { continue }
            let text = A56Line.normalize(maneuver.instruction)
            if entering, distance <= 500 {
                // Via Oreste Salomone serves the Capodichino Aeroporto
                // entrance, beside the distinct Secondigliano exit.
                if text.contains("oreste salomone"), let airport = candidates.first(where: { $0.junction.number == 1 }) {
                    signs.insert(airport.junction)
                }
            } else if !entering, isExitInstruction(text) {
                if let number = signedExitNumber(in: text) {
                    if let signed = candidates.first(where: { $0.junction.commercialNumber == number }) {
                        numberedSigns.insert(signed.junction)
                    }
                    continue
                }
                guard distance <= 500 else { continue }
                for candidate in candidates {
                    guard let name = candidate.junction.destinations.first else { continue }
                    if " \(text) ".contains(" \(A56Line.normalize(name)) ") {
                        signs.insert(candidate.junction)
                    }
                }
            }
        }

        if numberedSigns.count == 1, let signed = numberedSigns.first {
            return candidates.first?.junction == signed ? .signedInterchange(signed) : .interchange(signed)
        }
        guard numberedSigns.isEmpty else { return .unidentified }
        if signs.count == 1, let signed = signs.first { return .interchange(signed) }
        guard signs.isEmpty, let closest = candidates.first,
              candidates.dropFirst().first.map({ $0.distance - closest.distance >= 150 }) ?? true
        else { return .unidentified }
        return .interchange(closest.junction)
    }

    private static func isExitInstruction(_ normalized: String) -> Bool {
        let words = normalized.split(separator: " ")
        return words.contains("exit") || words.contains("uscita") || words.contains("esci")
    }

    private static func signedExitNumber(in normalized: String) -> Int? {
        let words = normalized.split(separator: " ")
        return zip(words, words.dropFirst()).first { word, next in
            (word == "exit" || word == "uscita") && Int(next) != nil
        }.flatMap { Int($0.1) }
    }

    private static func bestMatch(
        _ point: MKMapPoint, heading: Segment, routePosition: Double, maxDistance: Double = corridorWidth
    ) -> Match? {
        let radius = maxDistance * MKMapPointsPerMeterAtLatitude(point.coordinate.latitude)
        var best: Projection?
        var direction: Direction?
        for way in carriageways {
            let minCell = Carriageway.bucket(point.x - radius)
            let maxCell = Carriageway.bucket(point.x + radius)
            for cell in minCell...maxCell {
                for segment in way.byLongitude[cell] ?? [] {
                    guard point.x >= min(segment.from.x, segment.from.x + segment.dx) - radius,
                          point.x <= max(segment.from.x, segment.from.x + segment.dx) + radius,
                          point.y >= min(segment.from.y, segment.from.y + segment.dy) - radius,
                          point.y <= max(segment.from.y, segment.from.y + segment.dy) + radius,
                          let projection = segment.project(point, heading: heading),
                          projection.distance <= maxDistance,
                          projection.distance < (best?.distance ?? .infinity)
                    else { continue }
                    best = projection
                    direction = way.direction
                }
            }
        }
        guard let best, let direction else { return nil }
        return Match(direction: direction, position: best.position, routePosition: routePosition, distance: best.distance, point: point)
    }

    static func impacts(
        on traversals: [Traversal],
        closures: [RoadClosure],
        departure: Date,
        duration: TimeInterval
    ) -> [Impact] {
        let arrival = departure.addingTimeInterval(max(60, duration))
        return matchingImpacts(on: traversals, closures: closures.filter {
            $0.start < arrival && departure < $0.end
        })
    }

    /// A closure starting at or after the estimated arrival belongs in the
    /// upcoming notice, rather than changing the assessment for leaving now.
    static func nextImpactAfterTrip(
        on traversals: [Traversal],
        closures: [RoadClosure],
        departure: Date,
        duration: TimeInterval
    ) -> Impact? {
        let arrival = departure.addingTimeInterval(max(60, duration))
        return matchingImpacts(on: traversals, closures: closures.filter {
            $0.start >= arrival
        }).min { $0.closure.start < $1.closure.start }
    }

    private static func matchingImpacts(on traversals: [Traversal], closures: [RoadClosure]) -> [Impact] {
        closures.compactMap { closure in
            var possible: Impact?
            for traversal in traversals where closure.matches(direction: traversal.direction) {
                guard let way = carriageways.first(where: { $0.direction == traversal.direction }) else {
                    continue
                }
                if closure.kind == .roadBlocked,
                   let first = way.exits[closure.fromExit], let second = way.exits[closure.toExit] {
                    let low = min(first, second)
                    let high = max(first, second)
                    let overlap = min(high, traversal.end) - max(low, traversal.start)
                    if overlap > boundaryTolerance {
                        return Impact(closure: closure, kind: .roadBlock, ramp: nil)
                    }
                    if overlap >= -boundaryTolerance {
                        possible = Impact(closure: closure, kind: .nearBoundary, ramp: nil)
                    }
                } else {
                    for ramp in closure.closedRamps(for: traversal.direction) {
                        guard let position = way.exits[ramp.exitNumber] else { continue }
                        let isEntrance = ramp.kind == .entrance
                        let access = isEntrance ? traversal.entry : traversal.exit
                        let transition = isEntrance ? traversal.start : traversal.end
                        switch access {
                        case .signedInterchange(let junction):
                            if junction.number == ramp.exitNumber {
                                return Impact(closure: closure, kind: .closedRamp, ramp: ramp)
                            }
                        case .interchange, .unidentified:
                            if abs(position - transition) <= rampTolerance {
                                possible = Impact(closure: closure, kind: .ramp, ramp: ramp)
                            }
                        case .onCarriageway:
                            break
                        }
                    }
                }
            }
            return possible
        }
        .sorted { $0.kind.rawValue < $1.kind.rawValue }
    }
}
