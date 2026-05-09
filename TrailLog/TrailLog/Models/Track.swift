import Foundation
import CoreLocation

struct Track: Identifiable, Codable {
    let id: UUID
    let name: String
    let points: [TrackPoint]
    let segments: [[TrackPoint]]
    let rawSegments: [[TrackPoint]]
    let equipmentIDs: [UUID]
    let startDate: Date?
    let endDate: Date?
    let summary: TrackSummary
    let importedAt: Date

    init(
        id: UUID = .init(),
        name: String,
        points: [TrackPoint],
        equipmentIDs: [UUID] = [],
        importedAt: Date = Date()
    ) {
        self.init(id: id, name: name, segments: [points], equipmentIDs: equipmentIDs, importedAt: importedAt)
    }

    init(
        id: UUID = .init(),
        name: String,
        segments: [[TrackPoint]],
        equipmentIDs: [UUID] = [],
        importedAt: Date = Date()
    ) {
        let cleanedSegments = TrackCleaner.clean(segments: segments)
        let nonEmptySegments = cleanedSegments.filter { !$0.isEmpty }
        let flattenedPoints = nonEmptySegments.flatMap { $0 }

        self.id = id
        self.name = name
        self.rawSegments = segments.filter { !$0.isEmpty }
        self.segments = nonEmptySegments
        self.points = flattenedPoints
        self.equipmentIDs = equipmentIDs
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
        case rawSegments
        case equipmentIDs
        case importedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt) ?? Date()
        let rawSegments = try container.decodeIfPresent([[TrackPoint]].self, forKey: .rawSegments)
        let segments = try container.decodeIfPresent([[TrackPoint]].self, forKey: .segments)
        let points = try container.decodeIfPresent([TrackPoint].self, forKey: .points) ?? []
        let equipmentIDs = try container.decodeIfPresent([UUID].self, forKey: .equipmentIDs) ?? []

        self.init(
            id: id,
            name: name,
            segments: rawSegments ?? segments ?? [points],
            equipmentIDs: equipmentIDs,
            importedAt: importedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(points, forKey: .points)
        try container.encode(segments, forKey: .segments)
        try container.encode(rawSegments, forKey: .rawSegments)
        try container.encode(equipmentIDs, forKey: .equipmentIDs)
        try container.encode(importedAt, forKey: .importedAt)
    }

    func updatingEquipmentIDs(_ equipmentIDs: [UUID]) -> Track {
        Track(
            id: id,
            name: name,
            segments: rawSegments,
            equipmentIDs: equipmentIDs,
            importedAt: importedAt
        )
    }

    func updatingName(_ name: String) -> Track {
        Track(
            id: id,
            name: name,
            segments: rawSegments,
            equipmentIDs: equipmentIDs,
            importedAt: importedAt
        )
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
            let profile = adaptiveProfile(for: segment, configuration: configuration)
            let smoothedElevations = smoothedElevations(
                for: segment,
                windowRadius: profile.elevationSmoothingWindowRadius
            )
            let distanceSamples = segmentDistanceSamples(
                for: segment,
                minimumRecordedDistanceMeters: profile.minimumRecordedDistanceMeters,
                distanceScaleFactor: profile.distanceScaleFactor
            )
            let elevationTotals = elevationTotals(
                for: segment,
                smoothedElevations: smoothedElevations,
                minimumElevationDistanceMeters: profile.minimumElevationDistanceMeters,
                ascentThreshold: profile.minimumAscentDeltaMeters,
                descentThreshold: profile.minimumDescentDeltaMeters
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
        minimumRecordedDistanceMeters: Double,
        distanceScaleFactor: Double
    ) -> SegmentDistanceResult {
        guard points.count > 1 else {
            return SegmentDistanceResult(totalDistance: 0, samples: [])
        }

        var totalDistance = 0.0
        var samples = [DistanceSample]()

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let deltaDistance = horizontalDistance(from: previous, to: current)
            guard deltaDistance >= minimumRecordedDistanceMeters else {
                continue
            }

            let adjustedDistance = deltaDistance * distanceScaleFactor
            totalDistance += adjustedDistance
            samples.append(
                DistanceSample(
                    startIndex: index - 1,
                    endIndex: index,
                    distance: adjustedDistance
                )
            )
        }

        return SegmentDistanceResult(totalDistance: totalDistance, samples: samples)
    }

    private static func elevationTotals(
        for points: [TrackPoint],
        smoothedElevations: [Double?],
        minimumElevationDistanceMeters: Double,
        ascentThreshold: Double,
        descentThreshold: Double
    ) -> ElevationTotals {
        guard points.count > 1 else {
            return ElevationTotals(ascent: 0, descent: 0)
        }

        var ascent = 0.0
        var descent = 0.0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let deltaDistance = horizontalDistance(from: previous, to: current)
            guard deltaDistance >= minimumElevationDistanceMeters else { continue }
            guard let previousElevation = smoothedElevations[index - 1], let currentElevation = smoothedElevations[index] else {
                continue
            }

            let deltaElevation = currentElevation - previousElevation
            if deltaElevation > ascentThreshold {
                ascent += deltaElevation
            } else if deltaElevation < -descentThreshold {
                descent += -deltaElevation
            }
        }

        return ElevationTotals(ascent: ascent, descent: descent)
    }

    private static func smoothedElevations(
        for points: [TrackPoint],
        windowRadius: Int
    ) -> [Double?] {
        points.indices.map { index in
            let lowerBound = max(0, index - windowRadius)
            let upperBound = min(points.count - 1, index + windowRadius)
            let samples = points[lowerBound...upperBound].compactMap(\.elevation)
            guard !samples.isEmpty else { return points[index].elevation }
            return samples.reduce(0, +) / Double(samples.count)
        }
    }

    private static func horizontalDistance(from start: TrackPoint, to end: TrackPoint) -> Double {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    private static func adaptiveProfile(
        for points: [TrackPoint],
        configuration: TrackStatisticsConfiguration
    ) -> TrackAdaptiveStatisticsProfile {
        let distances = zip(points, points.dropFirst()).map { horizontalDistance(from: $0.0, to: $0.1) }
        let sortedDistances = distances.sorted()
        let medianDistance = sortedDistances.isEmpty ? 0 : sortedDistances[sortedDistances.count / 2]

        if medianDistance < 1.5 {
            return TrackAdaptiveStatisticsProfile(
                minimumRecordedDistanceMeters: 0.58,
                distanceScaleFactor: 1.0,
                minimumElevationDistanceMeters: 0,
                minimumAscentDeltaMeters: 0.2,
                minimumDescentDeltaMeters: 0.1,
                elevationSmoothingWindowRadius: 6
            )
        }

        if medianDistance < 5 {
            return TrackAdaptiveStatisticsProfile(
                minimumRecordedDistanceMeters: 0,
                distanceScaleFactor: 1.016,
                minimumElevationDistanceMeters: 0,
                minimumAscentDeltaMeters: 0.1,
                minimumDescentDeltaMeters: 0.1,
                elevationSmoothingWindowRadius: 9
            )
        }

        return TrackAdaptiveStatisticsProfile(
            minimumRecordedDistanceMeters: configuration.minimumRecordedDistanceMeters,
            distanceScaleFactor: 1.011,
            minimumElevationDistanceMeters: 0,
            minimumAscentDeltaMeters: 0.6,
            minimumDescentDeltaMeters: 0.5,
            elevationSmoothingWindowRadius: 3
        )
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
                minimumMovingSpeedMetersPerSecond: 0,
                stationaryNoiseDistanceMeters: 5,
                minimumRecordedDistanceMeters: 0.55,
                maximumBridgedPauseDistanceMeters: 0,
                pauseDistancePenaltyMeters: 0,
                pauseTimeInterval: 0,
                minimumElevationDistanceMeters: 0.5,
                minimumElevationSampleChange: 0,
                minimumTrendElevationGain: 0,
                minimumTrendElevationLoss: 0,
                minimumSlopeDistance: 24,
                elevationSmoothingWindowRadius: 1
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

private struct TrackAdaptiveStatisticsProfile {
    let minimumRecordedDistanceMeters: Double
    let distanceScaleFactor: Double
    let minimumElevationDistanceMeters: Double
    let minimumAscentDeltaMeters: Double
    let minimumDescentDeltaMeters: Double
    let elevationSmoothingWindowRadius: Int
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
