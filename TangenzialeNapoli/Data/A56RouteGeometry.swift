import Foundation
import CoreLocation

/// Static geometry of both A56 carriageways, decoded from embedded polylines.
/// A live directions request would reroute onto local roads while the motorway
/// is closed, so it cannot be used to draw the closures themselves.
nonisolated enum A56RouteGeometry {
    static let attributionURL = URL(string: "https://www.openstreetmap.org/copyright")!

    /// Snapshot of OpenStreetMap relation 1577415 and its A56 member ways,
    /// simplified to a maximum five-metre visual deviation (27 July 2026).
    /// ODbL attribution is shown directly on the map.
    private static let towardPozzuoliPolyline =
        "senxFylevAjB~F`FjHhA~CNnA?bCuAzOEnCLlCdAzElGhMfBzE~AfHt@jGdBf^JlFa@zJuB~R@lFt@jIBzBwBbOQvFd@vDvCtJbBvKpAhFbG|L~FpJ~AdDtL~`@xDpOhOph@zHzVjC|FxCpEvKnJhOrThDpBpBVhBMdSwGtBYxBFtDrAzK~HfCt@bHf@`Bx@nA|AxIbVr@rDD|EaA~LKdFJlHz@nJlMbn@fAxDvExLn@dDHfJQxFY|BwPvd@kD`HsHxKeBjDg@vAm@jDWvEIfj@\\lInA~G~AtEhLxSrBxFfApFd@bFNpFVfj@M`QiCngAWhWaA`Zs@dEe@zAuF|KeBzF{I~bAoAp^kBfK{FtN]hBUvCFtDv@vE|MvY~AdFn@zD"

    private static let towardCapodichinoPolyline =
        "ylgxFkv~tA{@wEkAsDeNkZq@gEGwDl@gF~F_OlBsJtAg_@nIuaAr@aD`AeCbG{L~@yEp@kNzDm}APuOa@c{@Q}G{@_HsAsFuC_HeJ_PaBwE}@wEa@{EGqDLok@b@kFjAgErAiCfJaMvCuFhOob@n@sCV_EFwIIeCk@}C{EeMuAqEqMun@s@{IKyGR{Hz@oJGiF}@yEaJgV_B{Ay@a@}Hm@{Bo@mMaJ}C{@yBCqBVsSzG}ADkBWwBgAgAgA_MeRsLsKsCqEwC_HqVe{@aV{w@kM{UmBoEeAwE{AmKoDoLOcCDmD~AmKNgCCiC{@qK?qDvBaS`@eJKmGiB__@aAkHaBwG}FqMuCgHM{@UcFzA{RBuAWaC}@mC}EaHyB{G"

    private static let towardPozzuoli = decode(towardPozzuoliPolyline)
    private static let towardCapodichino = decode(towardCapodichinoPolyline)

    static func coordinates(for direction: Direction) -> [CLLocationCoordinate2D] {
        switch direction {
        case .towardPozzuoli:
            towardPozzuoli
        case .towardCapodichino:
            towardCapodichino
        }
    }

    /// Mainline anchor for an exit in the selected carriageway. Labels may be
    /// visually offset at overview zoom, but this coordinate remains the exact
    /// shared junction between the route and every closure segment.
    static func coordinate(
        for exitNumber: Int,
        direction: Direction
    ) -> CLLocationCoordinate2D? {
        let route = coordinates(for: direction)
        guard let exit = A56Line.exit(exitNumber),
              let projection = nearestProjection(to: exit.coordinate, in: route)
        else { return nil }
        return projection.coordinate
    }

    /// Returns the real carriageway geometry between two app line points.
    /// Each exit is projected onto its closest point on the selected carriageway.
    static func segment(
        from firstExit: Int,
        to secondExit: Int,
        direction: Direction
    ) -> [CLLocationCoordinate2D] {
        let route = coordinates(for: direction)
        guard !route.isEmpty,
              let first = A56Line.exit(firstExit),
              let second = A56Line.exit(secondExit),
              let firstProjection = nearestProjection(to: first.coordinate, in: route),
              let secondProjection = nearestProjection(to: second.coordinate, in: route)
        else {
            return A56Line.exits(from: firstExit, to: secondExit).map(\.coordinate)
        }

        let lower: RouteProjection
        let upper: RouteProjection
        if firstProjection.position <= secondProjection.position {
            lower = firstProjection
            upper = secondProjection
        } else {
            lower = secondProjection
            upper = firstProjection
        }

        var segment = [lower.coordinate]
        let firstVertex = lower.segmentIndex + 1
        let lastVertex = upper.segmentIndex
        if firstVertex <= lastVertex {
            segment.append(contentsOf: route[firstVertex...lastVertex])
        }
        segment.append(upper.coordinate)
        return deduplicated(segment)
    }

    private struct RouteProjection {
        let coordinate: CLLocationCoordinate2D
        let segmentIndex: Int
        let fraction: Double

        var position: Double {
            Double(segmentIndex) + fraction
        }
    }

    /// Projects a point onto the nearest line segment, rather than selecting
    /// the nearest simplified vertex. Two nearby exits can legitimately lie
    /// on the same long simplified segment (6 and 7 toward Capodichino); using
    /// vertices made both annotations collapse onto one coordinate.
    private static func nearestProjection(
        to coordinate: CLLocationCoordinate2D,
        in route: [CLLocationCoordinate2D]
    ) -> RouteProjection? {
        guard route.count >= 2 else {
            guard let only = route.first else { return nil }
            return RouteProjection(coordinate: only, segmentIndex: 0, fraction: 0)
        }

        let longitudeScale = cos(coordinate.latitude * .pi / 180)
        var best: (projection: RouteProjection, distance: Double)?

        for index in 0..<(route.count - 1) {
            let start = route[index]
            let end = route[index + 1]
            let startX = (start.longitude - coordinate.longitude) * longitudeScale
            let startY = start.latitude - coordinate.latitude
            let deltaX = (end.longitude - start.longitude) * longitudeScale
            let deltaY = end.latitude - start.latitude
            let lengthSquared = deltaX * deltaX + deltaY * deltaY
            let fraction: Double
            if lengthSquared == 0 {
                fraction = 0
            } else {
                fraction = min(
                    1,
                    max(0, -(startX * deltaX + startY * deltaY) / lengthSquared)
                )
            }

            let projectedX = startX + fraction * deltaX
            let projectedY = startY + fraction * deltaY
            let distance = projectedX * projectedX + projectedY * projectedY
            let projected = CLLocationCoordinate2D(
                latitude: start.latitude + fraction * (end.latitude - start.latitude),
                longitude: start.longitude + fraction * (end.longitude - start.longitude)
            )
            let candidate = RouteProjection(
                coordinate: projected,
                segmentIndex: index,
                fraction: fraction
            )
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        return best?.projection
    }

    private static func deduplicated(
        _ coordinates: [CLLocationCoordinate2D]
    ) -> [CLLocationCoordinate2D] {
        coordinates.reduce(into: []) { result, coordinate in
            guard let last = result.last else {
                result.append(coordinate)
                return
            }
            if abs(last.latitude - coordinate.latitude) > 0.0000001
                || abs(last.longitude - coordinate.longitude) > 0.0000001 {
                result.append(coordinate)
            }
        }
    }

    /// Decodes a standard encoded polyline with 1e-5 degree precision.
    private static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        var latitude = 0
        var longitude = 0

        func nextValue() -> Int? {
            var result = 0
            var shift = 0

            while index < bytes.count {
                let value = Int(bytes[index]) - 63
                index += 1
                result |= (value & 0x1F) << shift
                shift += 5
                if value < 0x20 {
                    return (result & 1) == 1 ? ~(result >> 1) : (result >> 1)
                }
            }
            return nil
        }

        while let latitudeDelta = nextValue(),
              let longitudeDelta = nextValue() {
            latitude += latitudeDelta
            longitude += longitudeDelta
            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(latitude) / 100_000,
                    longitude: Double(longitude) / 100_000
                )
            )
        }
        return coordinates
    }
}
