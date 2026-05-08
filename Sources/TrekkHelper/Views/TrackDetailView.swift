import SwiftUI
import MapKit

struct TrackDetailView: View {
    let track: Track

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TrackSummaryCard(summary: track.summary)

                TrackMapView(points: track.points)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                ElevationProfileView(points: track.points)
                    .frame(height: 200)
                    .padding(.horizontal)

                detailSection
            }
            .padding()
        }
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                Label("点数：\(track.summary.pointCount)", systemImage: "waveform.path")
                Label("最高海拔：\(track.summary.maxElevation.map { String(format: "%.0f m", $0) } ?? "未知")", systemImage: "mountain")
                Label("最低海拔：\(track.summary.minElevation.map { String(format: "%.0f m", $0) } ?? "未知")", systemImage: "arrow.down")
                Label("平均坡度：\(track.summary.averageSlope.map { String(format: "%.1f%%", $0) } ?? "0%")", systemImage: "triangle.fill")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrackSummaryCard: View {
    let summary: TrackSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("轨迹概览")
                    .font(.headline)
                Spacer()
            }
            HStack {
                summaryLabel(title: "里程", value: Formatter.distance(summary.distanceMeters))
                summaryLabel(title: "爬升", value: Formatter.meters(summary.totalAscent))
            }
            HStack {
                summaryLabel(title: "下降", value: Formatter.meters(summary.totalDescent))
                summaryLabel(title: "点数", value: "\(summary.pointCount)")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func summaryLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrackMapView: View {
    let points: [TrackPoint]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotationPoints) { point in
            MapMarker(coordinate: point.coordinate)
        }
        .onAppear(perform: updateRegion)
    }

    private var annotationPoints: [TrackPoint] {
        guard !points.isEmpty else { return [] }
        return [points.first!, points.last!]
    }

    private func updateRegion() {
        guard let first = points.first else { return }
        region.center = first.coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    }
}
