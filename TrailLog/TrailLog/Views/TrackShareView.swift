import SwiftUI
import UIKit

struct TrackSharePreviewView: View {
    let track: Track
    let equipmentCost: Double

    @Environment(\.presentationMode) private var presentationMode
    @State private var sharePayload: SharePayload?
    @State private var isPreviewReady = false
    @State private var isMapReady = false
    @State private var isExporting = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        colors: [AppDesign.background, AppDesign.backgroundAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 0) {
                        shareHeader(geometry: geometry)
                        Spacer()
                    }

                    Group {
                        if isPreviewReady {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 18) {
                                    TrackShareCardView(track: track, equipmentCost: equipmentCost, rendersMap: isMapReady)
                                        .frame(height: 620)

                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("分享预览")
                                            .font(.appSection)
                                            .foregroundColor(AppDesign.ink)
                                        Text("导出后会生成一张简洁图片，包含轨迹图、里程、爬升和装备成本，适合发到微信或社交平台。")
                                            .font(.appBody)
                                            .foregroundColor(AppDesign.secondaryInk)
                                    }
                                    .padding(22)
                                    .appCardStyle()

                                    Button(action: prepareShareImage) {
                                        Text("导出并分享")
                                    }
                                    .buttonStyle(AppPrimaryButtonStyle())
                                    .disabled(isExporting)
                                }
                                .padding(.horizontal, AppDesign.horizontalPadding)
                                .padding(.top, contentTopInset(for: geometry))
                                .padding(.bottom, 18)
                            }
                        } else {
                            SharePreviewLoadingView(
                                title: "正在加载分享预览",
                                message: "正在准备轨迹图和分享卡片。"
                            )
                            .padding(.top, contentTopInset(for: geometry))
                        }
                    }

                    if isExporting {
                        SharePreviewLoadingView(
                            title: "正在生成分享图片",
                            message: "请稍候，正在导出高分辨率图片。"
                        )
                        .padding(.top, contentTopInset(for: geometry))
                        .background(Color.black.opacity(0.08).edgesIgnoringSafeArea(.all))
                    }
                }
            }
            .navigationBarTitle(Text(""), displayMode: .inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.image])
        }
        .onAppear {
            guard isPreviewReady == false else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isPreviewReady = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                isMapReady = true
            }
        }
    }

    private func contentTopInset(for geometry: GeometryProxy) -> CGFloat {
        max(44, geometry.safeAreaInsets.top + 84)
    }

    private func shareHeader(geometry: GeometryProxy) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("分享轨迹")
                    .font(.appSection)
                    .foregroundColor(AppDesign.ink)

                Text("导出路线卡片")
                    .font(.appCaption)
                    .foregroundColor(AppDesign.secondaryInk)
            }

            Spacer()

            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("关闭")
                }
                .font(.appCaption)
                .foregroundColor(AppDesign.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppDesign.elevatedSurface)
                .overlay(
                    Capsule()
                        .stroke(AppDesign.line, lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppDesign.surface.opacity(0.98))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppDesign.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppDesign.shadow, radius: 14, x: 0, y: 8)
        .padding(.horizontal, AppDesign.horizontalPadding)
        .padding(.top, geometry.safeAreaInsets.top + 8)
    }

    private func prepareShareImage() {
        guard isExporting == false else { return }
        isExporting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let card = TrackShareCardView(track: track, equipmentCost: equipmentCost, rendersMap: true)
                .frame(width: 1080, height: 1600)
            sharePayload = SharePayload(image: card.snapshot(size: CGSize(width: 1080, height: 1600)))
            isExporting = false
        }
    }
}

private struct SharePreviewLoadingView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            AppLoadingIndicator()
                .scaleEffect(1.1)

            Text(title)
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Text(message)
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .appCardStyle()
        .padding(.horizontal, 28)
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct TrackShareCardView: View {
    let track: Track
    let equipmentCost: Double
    var rendersMap: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                AppStatusPill(text: "TrailLog 徒步记录", tint: AppDesign.accentDeep)

                Text(track.name)
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .foregroundColor(AppDesign.ink)
                    .lineLimit(3)

                Text(track.startDate.map(Formatter.dateTime) ?? "未记录时间")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(AppDesign.secondaryInk)
            }

            Group {
                if rendersMap {
                    TrackSharePathMap(segments: track.segments)
                } else {
                    ShareMapPlaceholderView()
                }
            }
            .frame(height: 290)

            HStack(spacing: 14) {
                shareMetric(title: "里程", value: Formatter.distance(track.summary.distanceMeters))
                shareMetric(title: "爬升", value: Formatter.meters(track.summary.totalAscent))
            }

            HStack(spacing: 14) {
                shareMetric(title: "下降", value: Formatter.meters(track.summary.totalDescent))
                shareMetric(title: "装备成本", value: String(format: "¥%.2f", equipmentCost))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("路线摘要")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(AppDesign.ink)

                HStack(spacing: 10) {
                    routeTag(text: "点数 \(track.summary.pointCount)")
                    routeTag(text: track.summary.maxElevation.map { "最高 \((Int($0)))m" } ?? "最高未知")
                    routeTag(text: track.summary.averageSlope.map { String(format: "坡度 %.1f%%", $0) } ?? "坡度 --")
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("由 TrailLog 生成")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppDesign.secondaryInk)
                Spacer()
                Text("徒步 / 登山 / GPX")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppDesign.accentDeep)
            }
        }
        .padding(34)
        .background(
            LinearGradient(
                colors: [AppDesign.surface, AppDesign.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(AppDesign.line, lineWidth: 1)
        )
        .shadow(color: AppDesign.shadow, radius: 22, x: 0, y: 12)
    }

    private func shareMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(AppDesign.secondaryInk)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(AppDesign.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
        .padding(20)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func routeTag(text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundColor(AppDesign.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppDesign.elevatedSurface)
            .clipShape(Capsule())
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TrackSharePathMap: View {
    let segments: [[TrackPoint]]

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            let projectedSegments = projectSegments(in: rect.insetBy(dx: 20, dy: 20))

            ZStack {
                LinearGradient(
                    colors: [AppDesign.elevatedSurface, AppDesign.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppDesign.line, lineWidth: 1)

                ForEach(0..<projectedSegments.count, id: \.self) { index in
                    sharePath(for: projectedSegments[index])
                        .stroke(AppDesign.accentDeep, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                if let start = projectedSegments.first?.first {
                    Circle()
                        .fill(AppDesign.success)
                        .frame(width: 14, height: 14)
                        .position(start)
                }

                if let end = projectedSegments.last?.last {
                    Circle()
                        .fill(AppDesign.error)
                        .frame(width: 14, height: 14)
                        .position(end)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .drawingGroup()
        }
    }

    private func sharePath(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func projectSegments(in rect: CGRect) -> [[CGPoint]] {
        let simplifiedSegments = segments.map { simplifiedPoints($0, maxPoints: 280) }
        let coordinates = simplifiedSegments.flatMap { $0 }
        guard coordinates.isEmpty == false else { return [] }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return []
        }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.0001)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.0001)

        return simplifiedSegments.compactMap { segment in
            let mapped = segment.map { point -> CGPoint in
                let xRatio = (point.longitude - minLongitude) / longitudeSpan
                let yRatio = (point.latitude - minLatitude) / latitudeSpan
                return CGPoint(
                    x: rect.minX + rect.width * CGFloat(xRatio),
                    y: rect.maxY - rect.height * CGFloat(yRatio)
                )
            }
            return mapped.count > 1 ? mapped : nil
        }
    }

    private func simplifiedPoints(_ points: [TrackPoint], maxPoints: Int) -> [TrackPoint] {
        guard points.count > maxPoints, maxPoints > 2 else { return points }

        let strideLength = max(1, Int(ceil(Double(points.count) / Double(maxPoints))))
        var result = [TrackPoint]()
        result.reserveCapacity(maxPoints)

        for index in stride(from: 0, to: points.count, by: strideLength) {
            result.append(points[index])
        }

        if let last = points.last, result.last?.id != last.id {
            result.append(last)
        }

        return result
    }
}

private struct ShareMapPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.elevatedSurface, AppDesign.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppDesign.line, lineWidth: 1)

            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(AppDesign.secondaryInk)
                Text("正在准备轨迹图")
                    .font(.appCaption)
                    .foregroundColor(AppDesign.secondaryInk)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

extension View {
    func snapshot(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        let targetSize = size

        controller.view.frame = CGRect(origin: .zero, size: targetSize)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        view?.setNeedsLayout()
        view?.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
        }
    }
}
