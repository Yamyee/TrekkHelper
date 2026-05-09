import Foundation
import Testing
@testable import TrailLog

@Test func cleanerDropsSpikePoint() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let points = [
        TrackPoint(latitude: 39.9000, longitude: 116.3900, elevation: nil, timestamp: start),
        TrackPoint(latitude: 39.9005, longitude: 116.3905, elevation: nil, timestamp: start.addingTimeInterval(10)),
        TrackPoint(latitude: 39.9900, longitude: 116.4900, elevation: nil, timestamp: start.addingTimeInterval(20)),
        TrackPoint(latitude: 39.9010, longitude: 116.3910, elevation: nil, timestamp: start.addingTimeInterval(30)),
        TrackPoint(latitude: 39.9015, longitude: 116.3915, elevation: nil, timestamp: start.addingTimeInterval(40))
    ]

    let cleaned = TrackCleaner.clean(points: points)

    #expect(cleaned.count == 4)
    #expect(cleaned.contains(where: { $0.latitude == 39.9900 && $0.longitude == 116.4900 }) == false)
}

@Test func cleanerSplitsLargeGapIntoSegments() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let segments = TrackCleaner.clean(segments: [[
        TrackPoint(latitude: 39.9000, longitude: 116.3900, elevation: nil, timestamp: start),
        TrackPoint(latitude: 39.9004, longitude: 116.3904, elevation: nil, timestamp: start.addingTimeInterval(20)),
        TrackPoint(latitude: 39.9800, longitude: 116.4800, elevation: nil, timestamp: start.addingTimeInterval(2_000)),
        TrackPoint(latitude: 39.9804, longitude: 116.4804, elevation: nil, timestamp: start.addingTimeInterval(2_020))
    ]])

    #expect(segments.count == 2)
    #expect(segments[0].count == 2)
    #expect(segments[1].count == 2)
}

@Test func trackDecodingFallsBackToFlatPointsWhenSegmentsMissing() async throws {
    let json = """
    {
      "id": "8D7D674C-7D77-4A4E-B013-F9714E3950A4",
      "name": "legacy",
      "points": [
        {
          "id": "0F4833B3-D615-42D4-8F8F-2D7AF8D608C4",
          "latitude": 39.9,
          "longitude": 116.39,
          "elevation": 10,
          "timestamp": "2024-01-01T00:00:00Z"
        }
      ],
      "importedAt": "2024-01-01T00:00:00Z"
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let track = try decoder.decode(Track.self, from: json)

    #expect(track.points.count == 1)
    #expect(track.segments.count == 1)
    #expect(track.segments[0].count == 1)
}

@Test func summaryIgnoresStationaryJitterDistance() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let points = [
        TrackPoint(latitude: 39.900000, longitude: 116.390000, elevation: 100, timestamp: start),
        TrackPoint(latitude: 39.900010, longitude: 116.390010, elevation: 100.3, timestamp: start.addingTimeInterval(20)),
        TrackPoint(latitude: 39.900020, longitude: 116.390015, elevation: 100.4, timestamp: start.addingTimeInterval(40)),
        TrackPoint(latitude: 39.900600, longitude: 116.390600, elevation: 101, timestamp: start.addingTimeInterval(80))
    ]

    let summary = TrackSummary(points: points)

    #expect(summary.distanceMeters > 60)
    #expect(summary.distanceMeters < 100)
}

@Test func summaryCountsOnlyMeaningfulElevationGain() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let points = [
        TrackPoint(latitude: 39.9000, longitude: 116.3900, elevation: 100.0, timestamp: start),
        TrackPoint(latitude: 39.9002, longitude: 116.3902, elevation: 101.2, timestamp: start.addingTimeInterval(30)),
        TrackPoint(latitude: 39.9004, longitude: 116.3904, elevation: 102.1, timestamp: start.addingTimeInterval(60)),
        TrackPoint(latitude: 39.9006, longitude: 116.3906, elevation: 104.8, timestamp: start.addingTimeInterval(90)),
        TrackPoint(latitude: 39.9008, longitude: 116.3908, elevation: 105.2, timestamp: start.addingTimeInterval(120)),
        TrackPoint(latitude: 39.9010, longitude: 116.3910, elevation: 104.6, timestamp: start.addingTimeInterval(150)),
        TrackPoint(latitude: 39.9012, longitude: 116.3912, elevation: 106.7, timestamp: start.addingTimeInterval(180))
    ]

    let summary = TrackSummary(points: points)

    #expect(summary.totalAscent >= 4)
    #expect(summary.totalAscent < 9)
    #expect(summary.totalDescent == 0)
}

@Test func summarySplitsSegmentsWithoutAddingCrossGapDistance() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let firstSegment = [
        TrackPoint(latitude: 39.9000, longitude: 116.3900, elevation: 100, timestamp: start),
        TrackPoint(latitude: 39.9005, longitude: 116.3905, elevation: 104, timestamp: start.addingTimeInterval(60))
    ]
    let secondSegment = [
        TrackPoint(latitude: 39.9500, longitude: 116.4400, elevation: 120, timestamp: start.addingTimeInterval(1_200)),
        TrackPoint(latitude: 39.9505, longitude: 116.4405, elevation: 126, timestamp: start.addingTimeInterval(1_260))
    ]

    let summary = TrackSummary(segments: [firstSegment, secondSegment])

    #expect(summary.distanceMeters > 100)
    #expect(summary.distanceMeters < 200)
    #expect(summary.totalAscent >= 6)
    #expect(summary.totalAscent < 12)
}

@Test func hikingModeKeepsSlowButRealMovement() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let segment = [
        TrackPoint(latitude: 39.9000, longitude: 116.3900, elevation: 100, timestamp: start),
        TrackPoint(latitude: 39.9001, longitude: 116.3901, elevation: 102, timestamp: start.addingTimeInterval(45)),
        TrackPoint(latitude: 39.9002, longitude: 116.3902, elevation: 105, timestamp: start.addingTimeInterval(90))
    ]

    let hikingSummary = TrackSummary(segments: [segment], activityMode: .hiking)
    let runningSummary = TrackSummary(segments: [segment], activityMode: .running)

    #expect(hikingSummary.distanceMeters > 20)
    #expect(runningSummary.distanceMeters == 0)
    #expect(hikingSummary.totalAscent >= 4)
}

@Test func cleanerThinsDensePointsAndKeepsEndpoints() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let points = [
        TrackPoint(latitude: 39.900000, longitude: 116.390000, elevation: 100, timestamp: start),
        TrackPoint(latitude: 39.900010, longitude: 116.390010, elevation: 100.2, timestamp: start.addingTimeInterval(10)),
        TrackPoint(latitude: 39.900020, longitude: 116.390020, elevation: 100.3, timestamp: start.addingTimeInterval(20)),
        TrackPoint(latitude: 39.900030, longitude: 116.390030, elevation: 100.4, timestamp: start.addingTimeInterval(30)),
        TrackPoint(latitude: 39.900300, longitude: 116.390300, elevation: 101.0, timestamp: start.addingTimeInterval(40))
    ]

    var configuration = TrackCleanerConfiguration()
    configuration.enableThinning = true
    configuration.minimumPointCountForThinning = 3

    let cleaned = TrackCleaner.clean(points: points, configuration: configuration)

    #expect(cleaned.count < points.count)
    #expect(cleaned.first?.latitude == points.first?.latitude)
    #expect(cleaned.last?.latitude == points.last?.latitude)
}

@Test func trackCleaningReducesPauseNoiseInflation() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let rawPoints = [
        TrackPoint(latitude: 39.900000, longitude: 116.390000, elevation: 100.0, timestamp: start),
        TrackPoint(latitude: 39.900005, longitude: 116.390004, elevation: 101.5, timestamp: start.addingTimeInterval(60)),
        TrackPoint(latitude: 39.900003, longitude: 116.389999, elevation: 99.8, timestamp: start.addingTimeInterval(120)),
        TrackPoint(latitude: 39.900006, longitude: 116.390006, elevation: 102.0, timestamp: start.addingTimeInterval(180)),
        TrackPoint(latitude: 39.900400, longitude: 116.390400, elevation: 103.5, timestamp: start.addingTimeInterval(240)),
        TrackPoint(latitude: 39.900800, longitude: 116.390800, elevation: 108.6, timestamp: start.addingTimeInterval(300))
    ]

    let rawSummary = TrackSummary(points: rawPoints)
    let cleanedTrack = Track(name: "cleaned", points: rawPoints)

    #expect(cleanedTrack.points.count < rawPoints.count)
    #expect(cleanedTrack.summary.totalAscent < rawSummary.totalAscent)
    #expect(cleanedTrack.summary.distanceMeters <= rawSummary.distanceMeters)
}

@Test func defaultCleanerPreservesModerateRealMovement() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let points = [
        TrackPoint(latitude: 39.900000, longitude: 116.390000, elevation: 100.0, timestamp: start),
        TrackPoint(latitude: 39.900080, longitude: 116.390080, elevation: 101.4, timestamp: start.addingTimeInterval(40)),
        TrackPoint(latitude: 39.900160, longitude: 116.390160, elevation: 103.0, timestamp: start.addingTimeInterval(80)),
        TrackPoint(latitude: 39.900240, longitude: 116.390240, elevation: 104.8, timestamp: start.addingTimeInterval(120))
    ]

    let cleaned = TrackCleaner.clean(points: points)

    #expect(cleaned.count == points.count)
}

@Test func cleanerSplitsSuspiciousLongStraightJump() async throws {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let segments = TrackCleaner.clean(segments: [[
        TrackPoint(latitude: 39.900000, longitude: 116.390000, elevation: 100, timestamp: start),
        TrackPoint(latitude: 39.900120, longitude: 116.390120, elevation: 101, timestamp: start.addingTimeInterval(60)),
        TrackPoint(latitude: 39.905500, longitude: 116.395500, elevation: 120, timestamp: start.addingTimeInterval(120)),
        TrackPoint(latitude: 39.905650, longitude: 116.395650, elevation: 121, timestamp: start.addingTimeInterval(180))
    ]])

    #expect(segments.count == 2)
    #expect(segments[0].count == 2)
    #expect(segments[1].count == 2)
}
