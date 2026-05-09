import CoreLocation
import Foundation

struct TrackCleanerConfiguration {
    var maximumSpeedMetersPerSecond: Double = 3.33
    var maximumAccelerationMetersPerSecondSquared: Double = 8
    var driftDistanceThresholdMeters: Double = 25
    var spikeDistanceMeters: Double = 60
    var spikeReturnDistanceMeters: Double = 50
    var hardJumpDistanceMeters: Double = 800
    var gapSplitDistanceMeters: Double = 600
    var gapSplitTimeInterval: TimeInterval = 15 * 60
    var suspiciousGapDistanceMeters: Double = 180
    var suspiciousGapSpeedMetersPerSecond: Double = 3.2
    var untimedGapDistanceMeters: Double = 800
    var pauseClusterSpeedMetersPerSecond: Double = 0.18
    var pauseClusterRadiusMeters: Double = 6
    var pauseClusterMinimumDuration: TimeInterval = 180
    var clusterExitDistanceMeters: Double = 12
    var thinningDistanceMeters: Double = 8
    var thinningElevationDeltaMeters: Double = 8
    var thinningMaximumTimeInterval: TimeInterval = 45
    var minimumPointCountForThinning: Int = 1_800
    var maximumClusterNetDisplacementMeters: Double = 3
    var enableThinning: Bool = false
}

enum TrackCleaner {
    static func clean(
        segments: [[TrackPoint]],
        configuration: TrackCleanerConfiguration = TrackCleanerConfiguration()
    ) -> [[TrackPoint]] {
        segments
            .map { clean(segment: $0, configuration: configuration) }
            .flatMap { splitOnGaps(segment: $0, configuration: configuration) }
            .map { compressPauseClusters(in: $0, configuration: configuration) }
            .map { configuration.enableThinning ? thin(segment: $0, configuration: configuration) : $0 }
            .filter { !$0.isEmpty }
    }

    static func clean(
        points: [TrackPoint],
        configuration: TrackCleanerConfiguration = TrackCleanerConfiguration()
    ) -> [TrackPoint] {
        clean(segment: points, configuration: configuration)
    }

    private static func clean(
        segment: [TrackPoint],
        configuration: TrackCleanerConfiguration
    ) -> [TrackPoint] {
        let validPoints = segment.filter(isCoordinateValid)
        guard validPoints.count > 2 else {
            return deduplicated(validPoints)
        }

        let deduplicatedPoints = deduplicated(validPoints)
        guard deduplicatedPoints.count > 2 else {
            return deduplicatedPoints
        }

        var cleaned = [deduplicatedPoints[0]]

        for index in 1..<(deduplicatedPoints.count - 1) {
            let previous = cleaned.last ?? deduplicatedPoints[index - 1]
            let current = deduplicatedPoints[index]
            let next = deduplicatedPoints[index + 1]

            if shouldDrop(current, previous: previous, next: next, configuration: configuration) {
                continue
            }

            cleaned.append(current)
        }

        cleaned.append(deduplicatedPoints[deduplicatedPoints.count - 1])
        return deduplicated(cleaned)
    }

    private static func compressPauseClusters(
        in segment: [TrackPoint],
        configuration: TrackCleanerConfiguration
    ) -> [TrackPoint] {
        guard segment.count > 2 else { return segment }

        var compressed = [TrackPoint]()
        var cluster = [segment[0]]

        for point in segment.dropFirst() {
            let reference = cluster[cluster.count - 1]
            let deltaDistance = distance(from: reference, to: point)
            let deltaSpeed = speed(from: reference, to: point) ?? 0

            if deltaDistance <= configuration.clusterExitDistanceMeters,
               deltaSpeed <= configuration.pauseClusterSpeedMetersPerSecond {
                cluster.append(point)
                continue
            }

            compressed.append(contentsOf: reducedCluster(cluster, configuration: configuration))
            cluster = [point]
        }

        compressed.append(contentsOf: reducedCluster(cluster, configuration: configuration))
        return deduplicated(compressed)
    }

    private static func reducedCluster(
        _ cluster: [TrackPoint],
        configuration: TrackCleanerConfiguration
    ) -> [TrackPoint] {
        guard cluster.count > 1 else { return cluster }

        let duration = timeInterval(from: cluster[0], to: cluster[cluster.count - 1]) ?? 0
        let spread = cluster
            .dropFirst()
            .map { distance(from: cluster[0], to: $0) }
            .max() ?? 0
        let netDisplacement = distance(from: cluster[0], to: cluster[cluster.count - 1])

        guard duration >= configuration.pauseClusterMinimumDuration,
              spread <= configuration.pauseClusterRadiusMeters,
              netDisplacement <= configuration.maximumClusterNetDisplacementMeters else {
            return cluster
        }

        let averagedLatitude = cluster.map(\.latitude).reduce(0, +) / Double(cluster.count)
        let averagedLongitude = cluster.map(\.longitude).reduce(0, +) / Double(cluster.count)
        let elevations = cluster.compactMap(\.elevation)
        let averagedElevation = elevations.isEmpty ? nil : elevations.reduce(0, +) / Double(elevations.count)

        return [
            TrackPoint(
                latitude: averagedLatitude,
                longitude: averagedLongitude,
                elevation: averagedElevation,
                timestamp: cluster[0].timestamp
            ),
            TrackPoint(
                latitude: averagedLatitude,
                longitude: averagedLongitude,
                elevation: averagedElevation,
                timestamp: cluster[cluster.count - 1].timestamp
            )
        ]
    }

    private static func thin(
        segment: [TrackPoint],
        configuration: TrackCleanerConfiguration
    ) -> [TrackPoint] {
        guard segment.count > max(2, configuration.minimumPointCountForThinning) else { return segment }

        var thinned = [segment[0]]
        var lastKept = segment[0]

        for index in 1..<(segment.count - 1) {
            let point = segment[index]
            let deltaDistance = distance(from: lastKept, to: point)
            let deltaTime = timeInterval(from: lastKept, to: point) ?? 0
            let deltaElevation = abs((point.elevation ?? 0) - (lastKept.elevation ?? 0))

            let shouldKeepForShape = deltaDistance >= configuration.thinningDistanceMeters
            let shouldKeepForElevation = deltaElevation >= configuration.thinningElevationDeltaMeters
            let shouldKeepForTime = deltaTime >= configuration.thinningMaximumTimeInterval

            if shouldKeepForShape || shouldKeepForElevation || shouldKeepForTime {
                thinned.append(point)
                lastKept = point
            }
        }

        thinned.append(segment[segment.count - 1])
        return deduplicated(thinned)
    }

    private static func splitOnGaps(
        segment: [TrackPoint],
        configuration: TrackCleanerConfiguration
    ) -> [[TrackPoint]] {
        guard !segment.isEmpty else { return [] }

        var segments = [[TrackPoint]]()
        var currentSegment = [segment[0]]

        for point in segment.dropFirst() {
            let previous = currentSegment[currentSegment.count - 1]
            if isGap(from: previous, to: point, configuration: configuration) {
                if !currentSegment.isEmpty {
                    segments.append(currentSegment)
                }
                currentSegment = [point]
            } else {
                currentSegment.append(point)
            }
        }

        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }

        return segments
    }

    private static func shouldDrop(
        _ current: TrackPoint,
        previous: TrackPoint,
        next: TrackPoint,
        configuration: TrackCleanerConfiguration
    ) -> Bool {
        let previousDistance = distance(from: previous, to: current)
        let nextDistance = distance(from: current, to: next)
        let bypassDistance = distance(from: previous, to: next)

        if previousDistance > configuration.hardJumpDistanceMeters,
           nextDistance > configuration.hardJumpDistanceMeters,
           bypassDistance < configuration.spikeReturnDistanceMeters {
            return true
        }

        if previousDistance > configuration.spikeDistanceMeters,
           nextDistance > configuration.spikeDistanceMeters,
           bypassDistance < configuration.spikeReturnDistanceMeters {
            return true
        }

        if previousDistance >= configuration.driftDistanceThresholdMeters,
           nextDistance >= configuration.driftDistanceThresholdMeters,
           bypassDistance < configuration.driftDistanceThresholdMeters * 0.6 {
            return true
        }

        if let previousSpeed = speed(from: previous, to: current),
           previousSpeed > configuration.maximumSpeedMetersPerSecond {
            if let nextSpeed = speed(from: current, to: next),
               nextSpeed > configuration.maximumSpeedMetersPerSecond {
                return true
            }

            if bypassDistance < previousDistance * 0.35 {
                return true
            }
        }

        if let previousSpeed = speed(from: previous, to: current),
           let nextSpeed = speed(from: current, to: next),
           let timeInterval = timeInterval(from: previous, to: current),
           timeInterval > 0 {
            let acceleration = abs(nextSpeed - previousSpeed) / timeInterval
            if acceleration > configuration.maximumAccelerationMetersPerSecondSquared,
               bypassDistance < min(previousDistance, nextDistance) {
                return true
            }
        }

        if previous.timestamp != nil,
           next.timestamp != nil,
           previousDistance >= configuration.driftDistanceThresholdMeters,
           nextDistance >= configuration.driftDistanceThresholdMeters {
            let previousSpeed = speed(from: previous, to: current) ?? 0
            let nextSpeed = speed(from: current, to: next) ?? 0
            if previousSpeed > configuration.maximumSpeedMetersPerSecond || nextSpeed > configuration.maximumSpeedMetersPerSecond {
                return true
            }
        }

        return false
    }

    private static func isGap(
        from previous: TrackPoint,
        to current: TrackPoint,
        configuration: TrackCleanerConfiguration
    ) -> Bool {
        let distanceDelta = distance(from: previous, to: current)
        if distanceDelta >= configuration.gapSplitDistanceMeters {
            return true
        }

        if let timeDelta = timeInterval(from: previous, to: current) {
            if timeDelta >= configuration.gapSplitTimeInterval {
                return true
            }

            if timeDelta > 0 {
                let impliedSpeed = distanceDelta / timeDelta
                if distanceDelta >= configuration.suspiciousGapDistanceMeters,
                   impliedSpeed >= configuration.suspiciousGapSpeedMetersPerSecond {
                    return true
                }
            }

            return false
        }

        if distanceDelta >= configuration.untimedGapDistanceMeters {
            return true
        }

        return false
    }

    private static func deduplicated(_ points: [TrackPoint]) -> [TrackPoint] {
        guard !points.isEmpty else { return [] }

        var result = [points[0]]
        for point in points.dropFirst() {
            let last = result[result.count - 1]
            let isSameCoordinate = point.latitude == last.latitude && point.longitude == last.longitude
            let isSameTimestamp = point.timestamp == last.timestamp
            if isSameCoordinate && isSameTimestamp {
                continue
            }
            result.append(point)
        }
        return result
    }

    private static func isCoordinateValid(_ point: TrackPoint) -> Bool {
        (-90...90).contains(point.latitude) && (-180...180).contains(point.longitude)
    }

    private static func distance(from start: TrackPoint, to end: TrackPoint) -> Double {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    private static func timeInterval(from start: TrackPoint, to end: TrackPoint) -> TimeInterval? {
        guard let startTime = start.timestamp, let endTime = end.timestamp else {
            return nil
        }
        return endTime.timeIntervalSince(startTime)
    }

    private static func speed(from start: TrackPoint, to end: TrackPoint) -> Double? {
        guard let timeDelta = timeInterval(from: start, to: end), timeDelta > 0 else {
            return nil
        }
        return distance(from: start, to: end) / timeDelta
    }
}
