import SwiftUI

struct TrackDetailView: View {
    let track: Track
    @State private var showFullScreenMap = false
    @State private var showMapPreview = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.background, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    TrackSummaryCard(summary: track.summary)

                    mapSection

                    ElevationProfileView(points: track.points)
                        .frame(height: 220)

                    detailSection
                }
                .padding(.horizontal, AppDesign.horizontalPadding)
                .padding(.vertical, 18)
            }
        }
        .navigationBarTitle(Text(track.name), displayMode: .large)
        .sheet(isPresented: $showFullScreenMap) {
            FullScreenTrackMapView(track: track)
        }
        .onAppear {
            guard !showMapPreview else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showMapPreview = true
            }
        }
    }

    private var mapSection: some View {
        VStack(spacing: 0) {
            Button(action: { showFullScreenMap = true }) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if showMapPreview {
                            TrackMapView(segments: track.segments, maxRenderPointCount: 250)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "map")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppDesign.secondaryInk)
                                Text("正在加载轨迹地图")
                                    .font(.appCaption)
                                    .foregroundColor(AppDesign.secondaryInk)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppDesign.elevatedSurface)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("全屏")
                    }
                    .font(.appCaption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppDesign.panel)
                    .foregroundColor(AppDesign.ink)
                    .overlay(
                        Capsule()
                            .stroke(AppDesign.line, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                    .padding(12)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .appCardStyle()
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("路线细节")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Group {
                detailRow(icon: "waveform.path", title: "点数", value: "\(track.summary.pointCount)")
                detailRow(icon: "mountain.2", title: "最高海拔", value: track.summary.maxElevation.map { String(format: "%.0f m", $0) } ?? "未知")
                detailRow(icon: "arrow.down", title: "最低海拔", value: track.summary.minElevation.map { String(format: "%.0f m", $0) } ?? "未知")
                detailRow(icon: "triangle.fill", title: "平均坡度", value: track.summary.averageSlope.map { String(format: "%.1f%%", $0) } ?? "0%")
            }
        }
        .padding(22)
        .appCardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(AppDesign.accentDeep)
                Text(title)
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            }
            Spacer()
            Text(value)
                .font(.appBody.weight(.semibold))
                .foregroundColor(AppDesign.ink)
        }
    }
}

struct TrackSummaryCard: View {
    let summary: TrackSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("轨迹概览")
                    .font(.appSection)
                    .foregroundColor(AppDesign.ink)
                Spacer()
            }
            HStack(spacing: 12) {
                summaryLabel(title: "里程", value: Formatter.distance(summary.distanceMeters))
                summaryLabel(title: "爬升", value: Formatter.meters(summary.totalAscent))
            }
            HStack(spacing: 12) {
                summaryLabel(title: "下降", value: Formatter.meters(summary.totalDescent))
                summaryLabel(title: "点数", value: "\(summary.pointCount)")
            }
        }
        .padding(22)
        .appCardStyle()
    }

    private func summaryLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(AppDesign.secondaryInk)
            Text(value)
                .font(.appSection)
                .foregroundColor(AppDesign.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
