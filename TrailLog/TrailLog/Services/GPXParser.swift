import CoreGPX
import Foundation

enum GPXParserError: LocalizedError {
    case invalidData
    case parseFailed
    case emptyTrack

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "文件内容为空或不可读取。"
        case .parseFailed:
            return "GPX 文件解析失败。"
        case .emptyTrack:
            return "未在 GPX 文件中找到可用轨迹点。"
        }
    }
}

struct GPXParser {
    static func parse(url: URL) throws -> Track {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw GPXParserError.invalidData
        }

        guard let root = CoreGPX.GPXParser(withData: data).parsedData() else {
            throw GPXParserError.parseFailed
        }

        let rawSegments = makeSegments(from: root)
        let trackName = resolvedName(for: root, fallbackURL: url)

        guard !rawSegments.flatMap({ $0 }).isEmpty else {
            throw GPXParserError.emptyTrack
        }

        return Track(name: trackName, segments: rawSegments)
    }

    private static func makeSegments(from root: GPXRoot) -> [[TrackPoint]] {
        let trackSegments = root.tracks
            .flatMap(\.segments)
            .map { segment in
                segment.points.compactMap(TrackPoint.init(gpxPoint:))
            }
            .filter { !$0.isEmpty }

        if !trackSegments.isEmpty {
            return trackSegments
        }

        let routeSegments = root.routes
            .map { route in
                route.points.compactMap(TrackPoint.init(gpxPoint:))
            }
            .filter { !$0.isEmpty }

        if !routeSegments.isEmpty {
            return routeSegments
        }

        let waypoints = root.waypoints.compactMap(TrackPoint.init(gpxPoint:))
        return waypoints.isEmpty ? [] : [waypoints]
    }

    private static func resolvedName(for root: GPXRoot, fallbackURL url: URL) -> String {
        let candidates = root.tracks.compactMap(\.name)
            + root.routes.compactMap(\.name)
            + [root.metadata?.name].compactMap { $0 }
        return candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            ?? url.deletingPathExtension().lastPathComponent
    }
}

private extension TrackPoint {
    init?(gpxPoint: GPXWaypoint) {
        guard let latitude = gpxPoint.latitude, let longitude = gpxPoint.longitude else {
            return nil
        }

        self.init(
            latitude: latitude,
            longitude: longitude,
            elevation: gpxPoint.elevation,
            timestamp: gpxPoint.time
        )
    }
}
