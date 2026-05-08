import Foundation
import CoreLocation

struct Track: Identifiable, Codable {
    let id: UUID
    let name: String
    let points: [TrackPoint]
    let segments: [[TrackPoint]]
    let startDate: Date?
    let endDate: Date?
    let summary: TrackSummary
    let importedAt: Date

    init(id: UUID = .init(), name: String, points: [TrackPoint], importedAt: Date = Date()) {
        self.init(id: id, name: name, segments: [points], importedAt: importedAt)
    }

    init(id: UUID = .init(), name: String, segments: [[TrackPoint]], importedAt: Date = Date()) {
        let cleanedSegments = TrackCleaner.clean(segments: segments)
        let nonEmptySegments = cleanedSegments.filter { !$0.isEmpty }
        let flattenedPoints = nonEmptySegments.flatMap { $0 }

        self.id = id
        self.name = name
        self.segments = nonEmptySegments
        self.points = flattenedPoints
        self.startDate = flattenedPoints.first?.timestamp
        self.endDate = flattenedPoints.last?.timestamp
        self.summary = TrackSummary(segments: nonEmptySegments)
        self.importedAt = importedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case points
        case segments
        case importedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt) ?? Date()
        let segments = try container.decodeIfPresent([[TrackPoint]].self, forKey: .segments)
        let points = try container.decodeIfPresent([TrackPoint].self, forKey: .points) ?? []

        self.init(id: id, name: name, segments: segments ?? [points], importedAt: importedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(points, forKey: .points)
        try container.encode(segments, forKey: .segments)
        try container.encode(importedAt, forKey: .importedAt)
    }
}

struct TrackPoint: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let timestamp: Date?

    init(id: UUID = .init(), latitude: Double, longitude: Double, elevation: Double?, timestamp: Date?) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.timestamp = timestamp
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TrackSummary: Codable {
    let distanceMeters: Double
    let totalAscent: Double
    let totalDescent: Double
    let minElevation: Double?
    let maxElevation: Double?
    let averageSlope: Double?
    let pointCount: Int

    private static let defaultActivityMode: TrackActivityMode = .hiking

    init(points: [TrackPoint]) {
        self.init(segments: [points], activityMode: Self.defaultActivityMode)
    }

    init(segments: [[TrackPoint]]) {
        self.init(segments: segments, activityMode: Self.defaultActivityMode)
    }

    init(segments: [[TrackPoint]], activityMode: TrackActivityMode) {
        let flattenedPoints = segments.flatMap { $0 }
        self.pointCount = flattenedPoints.count

        guard flattenedPoints.count > 1 else {
            self.distanceMeters = 0
            self.totalAscent = 0
            self.totalDescent = 0
            self.minElevation = flattenedPoints.compactMap(\.elevation).min()
            self.maxElevation = flattenedPoints.compactMap(\.elevation).max()
            self.averageSlope = 0
            return
        }

        let metrics = Self.computeMetrics(
            for: segments,
            configuration: TrackStatisticsConfiguration.forActivityMode(activityMode)
        )

        self.distanceMeters = metrics.distanceMeters
        self.totalAscent = metrics.totalAscent
        self.totalDescent = metrics.totalDescent
        self.minElevation = flattenedPoints.compactMap(\.elevation).min()
        self.maxElevation = flattenedPoints.compactMap(\.elevation).max()
        self.averageSlope = metrics.averageSlope
    }

    private static func computeMetrics(
        for segments: [[TrackPoint]],
        configuration: TrackStatisticsConfiguration
    ) -> TrackMetrics {
        var distance = 0.0
        var ascent = 0.0
        var descent = 0.0
        var slopes = [Double]()

        for segment in segments where segment.count > 1 {
            let smoothedElevations = smoothedElevations(for: segment, configuration: configuration)
            let distanceSamples = segmentDistanceSamples(for: segment, configuration: configuration)
            let elevationTotals = elevationTotals(
                for: segment,
                smoothedElevations: smoothedElevations,
                configuration: configuration
            )

            distance += distanceSamples.totalDistance
            ascent += elevationTotals.ascent
            descent += elevationTotals.descent

            for sample in distanceSamples.samples where sample.distance >= configuration.minimumSlopeDistance {
                guard
                    let startElevation = smoothedElevations[sample.startIndex],
                    let endElevation = smoothedElevations[sample.endIndex]
                else {
                    continue
                }
                slopes.append(((endElevation - startElevation) / sample.distance) * 100)
            }
        }

        return TrackMetrics(
            distanceMeters: distance,
            totalAscent: ascent,
            totalDescent: descent,
            averageSlope: slopes.isEmpty ? 0 : slopes.reduce(0, +) / Double(slopes.count)
        )
    }

    private static func segmentDistanceSamples(
        for points: [TrackPoint],
        configuration: TrackStatisticsConfiguration
    ) -> SegmentDistanceResult {
        guard points.count > 1 else {
            return SegmentDistanceResult(totalDistance: 0, samples: [])
        }

        var totalDistance = 0.0
        var samples = [DistanceSample]()
        var pendingStationaryDistance = 0.0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let deltaDistance = locationDistance(from: previous, to: current)
            let timeDelta = current.timestamp.flatMap { currentTime in
                previous.timestamp.map { currentTime.timeIntervalSince($0) }
            }

            let speed = timeDelta.flatMap { $0 > 0 ? deltaDistance / $0 : nil }
            let isStationaryJitter = deltaDistance < configuration.stationaryNoiseDistanceMeters
            let isSlowMovement = speed.map { $0 < configuration.minimumMovingSpeedMetersPerSecond } ?? false
            let hasLongPause = timeDelta.map { $0 >= configuration.pauseTimeInterval } ?? false

            if isStationaryJitter || isSlowMovement || hasLongPause {
                pendingStationaryDistance += deltaDistance
                continue
            }

            let acceptedDistance: Double
            if pendingStationaryDistance <= configuration.maximumBridgedPauseDistanceMeters {
                acceptedDistance = deltaDistance
            } else {
                acceptedDistance = max(0, deltaDistance - min(pendingStationaryDistance, configuration.pauseDistancePenaltyMeters))
            }
            pendingStationaryDistance = 0

            guard acceptedDistance >= configuration.minimumRecordedDistanceMeters else {
                continue
            }

            totalDistance += acceptedDistance
            samples.append(
                DistanceSample(
                    startIndex: index - 1,
                    endIndex: index,
                    distance: acceptedDistance
                )
            )
        }

        return SegmentDistanceResult(totalDistance: totalDistance, samples: samples)
    }

    private static func elevationTotals(
        for points: [TrackPoint],
        smoothedElevations: [Double?],
        configuration: TrackStatisticsConfiguration
    ) -> ElevationTotals {
        guard points.count > 1 else {
            return ElevationTotals(ascent: 0, descent: 0)
        }

        var ascent = 0.0
        var descent = 0.0
        var trendDirection = 0
        var trendDelta = 0.0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let deltaDistance = locationDistance(from: previous, to: current)
            guard deltaDistance >= configuration.minimumElevationDistanceMeters else { continue }
            guard let previousElevation = smoothedElevations[index - 1], let currentElevation = smoothedElevations[index] else {
                continue
            }

            let deltaElevation = currentElevation - previousElevation
            guard abs(deltaElevation) >= configuration.minimumElevationSampleChange else { continue }

            let direction = deltaElevation > 0 ? 1 : -1
            if trendDirection == 0 {
                trendDirection = direction
                trendDelta = deltaElevation
                continue
            }

            if direction == trendDirection {
                trendDelta += deltaElevation
                continue
            }

            if trendDirection > 0, trendDelta >= configuration.minimumTrendElevationGain {
                ascent += trendDelta
            } else if trendDirection < 0, -trendDelta >= configuration.minimumTrendElevationLoss {
                descent += -trendDelta
            }

            trendDirection = direction
            trendDelta = deltaElevation
        }

        if trendDirection > 0, trendDelta >= configuration.minimumTrendElevationGain {
            ascent += trendDelta
        } else if trendDirection < 0, -trendDelta >= configuration.minimumTrendElevationLoss {
            descent += -trendDelta
        }

        return ElevationTotals(ascent: ascent, descent: descent)
    }

    private static func smoothedElevations(
        for points: [TrackPoint],
        configuration: TrackStatisticsConfiguration
    ) -> [Double?] {
        points.indices.map { index in
            let lowerBound = max(0, index - configuration.elevationSmoothingWindowRadius)
            let upperBound = min(points.count - 1, index + configuration.elevationSmoothingWindowRadius)
            let samples = points[lowerBound...upperBound].compactMap(\.elevation)
            guard !samples.isEmpty else { return points[index].elevation }
            return samples.reduce(0, +) / Double(samples.count)
        }
    }

    private static func locationDistance(from start: TrackPoint, to end: TrackPoint) -> Double {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }
}

enum TrackActivityMode: String, Codable {
    case hiking
    case running
    case cycling
}

private struct TrackStatisticsConfiguration {
    let minimumMovingSpeedMetersPerSecond: Double
    let stationaryNoiseDistanceMeters: Double
    let minimumRecordedDistanceMeters: Double
    let maximumBridgedPauseDistanceMeters: Double
    let pauseDistancePenaltyMeters: Double
    let pauseTimeInterval: TimeInterval
    let minimumElevationDistanceMeters: Double
    let minimumElevationSampleChange: Double
    let minimumTrendElevationGain: Double
    let minimumTrendElevationLoss: Double
    let minimumSlopeDistance: Double
    let elevationSmoothingWindowRadius: Int

    static func forActivityMode(_ mode: TrackActivityMode) -> TrackStatisticsConfiguration {
        switch mode {
        case .hiking:
            return TrackStatisticsConfiguration(
                minimumMovingSpeedMetersPerSecond: 0.32,
                stationaryNoiseDistanceMeters: 5,
                minimumRecordedDistanceMeters: 4,
                maximumBridgedPauseDistanceMeters: 20,
                pauseDistancePenaltyMeters: 15,
                pauseTimeInterval: 210,
                minimumElevationDistanceMeters: 10,
                minimumElevationSampleChange: 1.2,
                minimumTrendElevationGain: 5,
                minimumTrendElevationLoss: 5,
                minimumSlopeDistance: 24,
                elevationSmoothingWindowRadius: 2
            )
        case .running:
            return TrackStatisticsConfiguration(
                minimumMovingSpeedMetersPerSecond: 1.2,
                stationaryNoiseDistanceMeters: 4,
                minimumRecordedDistanceMeters: 3,
                maximumBridgedPauseDistanceMeters: 12,
                pauseDistancePenaltyMeters: 8,
                pauseTimeInterval: 90,
                minimumElevationDistanceMeters: 8,
                minimumElevationSampleChange: 0.8,
                minimumTrendElevationGain: 3,
                minimumTrendElevationLoss: 3,
                minimumSlopeDistance: 18,
                elevationSmoothingWindowRadius: 2
            )
        case .cycling:
            return TrackStatisticsConfiguration(
                minimumMovingSpeedMetersPerSecond: 2.5,
                stationaryNoiseDistanceMeters: 6,
                minimumRecordedDistanceMeters: 6,
                maximumBridgedPauseDistanceMeters: 30,
                pauseDistancePenaltyMeters: 20,
                pauseTimeInterval: 120,
                minimumElevationDistanceMeters: 15,
                minimumElevationSampleChange: 1.5,
                minimumTrendElevationGain: 6,
                minimumTrendElevationLoss: 6,
                minimumSlopeDistance: 30,
                elevationSmoothingWindowRadius: 3
            )
        }
    }
}

private struct TrackMetrics {
    let distanceMeters: Double
    let totalAscent: Double
    let totalDescent: Double
    let averageSlope: Double?
}

private struct DistanceSample {
    let startIndex: Int
    let endIndex: Int
    let distance: Double
}

private struct SegmentDistanceResult {
    let totalDistance: Double
    let samples: [DistanceSample]
}

private struct ElevationTotals {
    let ascent: Double
    let descent: Double
}
