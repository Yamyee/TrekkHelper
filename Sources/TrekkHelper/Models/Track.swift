import Foundation
import CoreLocation

struct Track: Identifiable, Codable {
    let id: UUID
    let name: String
    let points: [TrackPoint]
    let startDate: Date?
    let endDate: Date?
    let summary: TrackSummary
    let importedAt: Date

    init(id: UUID = .init(), name: String, points: [TrackPoint], importedAt: Date = .now) {
        self.id = id
        self.name = name
        self.points = points
        self.startDate = points.first?.timestamp
        self.endDate = points.last?.timestamp
        self.summary = TrackSummary(points: points)
        self.importedAt = importedAt
    }
}

struct TrackPoint: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let timestamp: Date?

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

    init(points: [TrackPoint]) {
        self.pointCount = points.count
        guard points.count > 1 else {
            self.distanceMeters = 0
            self.totalAscent = 0
            self.totalDescent = 0
            self.minElevation = points.compactMap(\.elevation).min()
            self.maxElevation = points.compactMap(\.elevation).max()
            self.averageSlope = 0
            return
        }

        var distance = 0.0
        var ascent = 0.0
        var descent = 0.0
        var slopes = [Double]()
        var lastPoint = points[0]

        for point in points.dropFirst() {
            let lastLocation = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let currentLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
            let delta = currentLocation.distance(from: lastLocation)
            distance += delta

            if let lastElev = lastPoint.elevation, let elev = point.elevation {
                let diff = elev - lastElev
                if diff > 0 {
                    ascent += diff
                } else {
                    descent -= diff
                }
                if delta > 0 {
                    slopes.append((diff / delta) * 100)
                }
            }
            lastPoint = point
        }

        self.distanceMeters = distance
        self.totalAscent = ascent
        self.totalDescent = descent
        self.minElevation = points.compactMap(\.elevation).min()
        self.maxElevation = points.compactMap(\.elevation).max()
        self.averageSlope = slopes.isEmpty ? 0 : slopes.reduce(0, +) / Double(slopes.count)
    }
}
