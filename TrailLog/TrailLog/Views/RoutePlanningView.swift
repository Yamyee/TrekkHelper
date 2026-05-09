import CoreLocation
import SwiftUI

struct RoutePlanningView: View {
    let track: Track

    @State private var dailyDistanceKilometers: Double = 12
    @State private var maxDailyAscentMeters: Double = 900
    @State private var renderedPlan = RoutePlanningPlan.empty
    @State private var isCalculatingPlan = true
    @State private var isMapReady = false
    @State private var pendingRecalculationToken = UUID()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.background, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            Group {
                if isCalculatingPlan && renderedPlan.days.isEmpty {
                    RoutePlanningPageLoadingView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            planningSummaryCard
                            planningParameterCard
                            mapCard
                            warningsCard
                            waypointCard
                            riskSegmentCard
                            itineraryCard
                        }
                        .padding(.horizontal, AppDesign.horizontalPadding)
                        .padding(.vertical, 18)
                    }
                }
            }
        }
        .navigationBarTitle(Text("路线规划"), displayMode: .large)
        .overlay(
            Group {
                if isCalculatingPlan && renderedPlan.days.isEmpty == false {
                    VStack(spacing: 10) {
                        AppLoadingIndicator()
                        Text("正在更新规划")
                            .font(.appCaption)
                            .foregroundColor(AppDesign.secondaryInk)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AppDesign.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: AppDesign.shadow, radius: 12, x: 0, y: 8)
                }
            }
        )
        .onAppear {
            guard renderedPlan.days.isEmpty else { return }
            recalculatePlan()
        }
    }

    private var planningSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("规划概览")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Text(track.name)
                .font(.appTitle)
                .foregroundColor(AppDesign.ink)

            HStack(spacing: 12) {
                summaryBox(title: "建议天数", value: "\(renderedPlan.days.count) 天")
                summaryBox(title: "难度", value: renderedPlan.difficulty.title)
            }

            HStack(spacing: 12) {
                summaryBox(title: "总里程", value: Formatter.distance(track.summary.distanceMeters))
                summaryBox(title: "总爬升", value: Formatter.meters(track.summary.totalAscent))
            }

            Text(renderedPlan.overview)
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
        }
        .padding(22)
        .appCardStyle()
    }

    private var planningParameterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("规划参数")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("目标日里程")
                        .font(.appBody)
                        .foregroundColor(AppDesign.secondaryInk)
                    Spacer()
                    Text(String(format: "%.0f km", dailyDistanceKilometers))
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(AppDesign.ink)
                }
                Slider(value: dailyDistanceBinding, in: 6...25, step: 1)
                    .accentColor(AppDesign.accent)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("单日最大爬升")
                        .font(.appBody)
                        .foregroundColor(AppDesign.secondaryInk)
                    Spacer()
                    Text(String(format: "%.0f m", maxDailyAscentMeters))
                        .font(.appBody.weight(.semibold))
                        .foregroundColor(AppDesign.ink)
                }
                Slider(value: maxDailyAscentBinding, in: 400...1800, step: 50)
                    .accentColor(AppDesign.accent)
            }

            Text("这一版会顺序拆分日程，并优先标出坡度明显的风险段与更适合作为休息点的平缓区间。")
                .font(.appCaption)
                .foregroundColor(AppDesign.secondaryInk)
        }
        .padding(22)
        .appCardStyle()
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("规划地图")
                    .font(.appSection)
                    .foregroundColor(AppDesign.ink)
                Spacer()
                AppStatusPill(text: "\(renderedPlan.days.count) 段行程", tint: AppDesign.accentDeep)
            }

            RoutePlanningMapView(days: renderedPlan.days, riskSegments: renderedPlan.riskSegments, waypoints: renderedPlan.waypoints)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .opacity(isMapReady ? 1 : 0)
                .overlay(
                    Group {
                        if isMapReady == false {
                            RoutePlanningMapPlaceholderView()
                        }
                    }
                )

            routeLegend
        }
        .padding(22)
        .appCardStyle()
    }

    private var routeLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(renderedPlan.days) { day in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(day.color)
                            .frame(width: 10, height: 10)
                        Text(day.title)
                            .font(.appCaption)
                            .foregroundColor(AppDesign.ink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppDesign.elevatedSurface)
                    .clipShape(Capsule())
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppDesign.error)
                        .frame(width: 10, height: 10)
                    Text("风险陡坡")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.ink)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppDesign.elevatedSurface)
                .clipShape(Capsule())
            }
        }
    }

    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关键提醒")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            if renderedPlan.warnings.isEmpty {
                Text("当前参数下没有明显超负荷日程，适合作为首版规划。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            } else {
                ForEach(renderedPlan.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppDesign.warning)
                        Text(warning)
                            .font(.appBody)
                            .foregroundColor(AppDesign.secondaryInk)
                    }
                }
            }
        }
        .padding(22)
        .appCardStyle()
    }

    private var waypointCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("休息与露营候选")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            if renderedPlan.waypoints.isEmpty {
                Text("当前轨迹暂未识别到稳定的平缓候选点，可以先按天数规划再人工调整扎营位置。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            } else {
                ForEach(renderedPlan.waypoints.prefix(5)) { waypoint in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(waypoint.title)
                                .font(.appBody.weight(.semibold))
                                .foregroundColor(AppDesign.ink)
                            Spacer()
                            AppStatusPill(text: waypoint.kind.title, tint: waypoint.kind.tint)
                        }
                        Text(waypoint.detail)
                            .font(.appCaption)
                            .foregroundColor(AppDesign.secondaryInk)
                    }
                    .padding(16)
                    .background(AppDesign.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(22)
        .appCardStyle()
    }

    private var riskSegmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("风险路段")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            if renderedPlan.riskSegments.isEmpty {
                Text("当前没有识别到连续高坡度风险段，整体更像常规徒步节奏。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            } else {
                ForEach(renderedPlan.riskSegments.prefix(4)) { segment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(segment.title)
                                .font(.appBody.weight(.semibold))
                                .foregroundColor(AppDesign.ink)
                            Spacer()
                            AppStatusPill(text: String(format: "%.1f%%", segment.averageSlope), tint: AppDesign.error)
                        }
                        Text(segment.detail)
                            .font(.appCaption)
                            .foregroundColor(AppDesign.secondaryInk)
                    }
                    .padding(16)
                    .background(AppDesign.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(22)
        .appCardStyle()
    }

    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("建议行程")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            ForEach(renderedPlan.days) { day in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.title)
                                .font(.appSection)
                                .foregroundColor(AppDesign.ink)
                            Text(day.summaryLine)
                                .font(.appCaption)
                                .foregroundColor(AppDesign.secondaryInk)
                        }
                        Spacer()
                        AppStatusPill(text: day.difficulty.title, tint: day.difficulty.tint)
                    }

                    HStack(spacing: 12) {
                        summaryBox(title: "里程", value: Formatter.distance(day.distanceMeters))
                        summaryBox(title: "爬升", value: Formatter.meters(day.ascentMeters))
                    }

                    HStack(spacing: 12) {
                        summaryBox(title: "预计时长", value: Formatter.durationHours(day.estimatedHours))
                        summaryBox(title: "平均坡度", value: String(format: "%.1f%%", day.averageSlope))
                    }

                    if let restNote = day.restSuggestion {
                        Text(restNote)
                            .font(.appBody)
                            .foregroundColor(AppDesign.secondaryInk)
                    }
                }
                .padding(18)
                .background(AppDesign.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(22)
        .appCardStyle()
    }

    private func summaryBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appCaption)
                .foregroundColor(AppDesign.secondaryInk)
            Text(value)
                .font(.appSection)
                .foregroundColor(AppDesign.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppDesign.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dailyDistanceBinding: Binding<Double> {
        Binding(
            get: { dailyDistanceKilometers },
            set: { newValue in
                dailyDistanceKilometers = newValue
                schedulePlanRecalculation()
            }
        )
    }

    private var maxDailyAscentBinding: Binding<Double> {
        Binding(
            get: { maxDailyAscentMeters },
            set: { newValue in
                maxDailyAscentMeters = newValue
                schedulePlanRecalculation()
            }
        )
    }

    private func schedulePlanRecalculation() {
        let token = UUID()
        pendingRecalculationToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard pendingRecalculationToken == token else { return }
            recalculatePlan()
        }
    }

    private func recalculatePlan() {
        isCalculatingPlan = true
        let track = self.track
        let dailyDistanceKilometers = self.dailyDistanceKilometers
        let maxDailyAscentMeters = self.maxDailyAscentMeters

        DispatchQueue.global(qos: .userInitiated).async {
            let nextPlan = RoutePlanner.makePlan(
                for: track,
                dailyDistanceKilometers: dailyDistanceKilometers,
                maxDailyAscentMeters: maxDailyAscentMeters
            )

            DispatchQueue.main.async {
                renderedPlan = nextPlan
                isCalculatingPlan = false
                isMapReady = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isMapReady = true
                }
            }
        }
    }
}

private struct RoutePlanningPageLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            AppLoadingIndicator()
                .scaleEffect(1.1)

            Text("正在生成路线规划")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Text("正在计算分段、风险路段和休息候选点。")
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .appCardStyle()
        .padding(.horizontal, 28)
    }
}

struct RoutePlanningPlan {
    let days: [RoutePlanningDay]
    let warnings: [String]
    let difficulty: PlanningDifficulty
    let overview: String
    let waypoints: [RoutePlanningWaypoint]
    let riskSegments: [RoutePlanningRiskSegment]

    static let empty = RoutePlanningPlan(
        days: [],
        warnings: [],
        difficulty: .easy,
        overview: "",
        waypoints: [],
        riskSegments: []
    )
}

struct RoutePlanningDay: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let points: [TrackPoint]
    let segments: [[TrackPoint]]
    let distanceMeters: Double
    let ascentMeters: Double
    let averageSlope: Double
    let estimatedHours: Double
    let difficulty: PlanningDifficulty
    let restSuggestion: String?
    let color: Color

    var title: String {
        "第 \(dayIndex) 天"
    }

    var summaryLine: String {
        let start = points.first?.timestamp.map(Formatter.dateTime) ?? "未记录起点时间"
        return "起始参考：\(start)"
    }
}

struct RoutePlanningWaypoint: Identifiable {
    let id = UUID()
    let kind: RoutePlanningWaypointKind
    let point: TrackPoint
    let dayIndex: Int
    let kilometerMark: Double
    let nearbySlope: Double

    var title: String {
        "\(kind.title) · 第 \(dayIndex) 天"
    }

    var detail: String {
        "约在第 \(String(format: "%.1f", kilometerMark)) km，附近坡度 \(String(format: "%.1f%%", nearbySlope))。"
    }
}

enum RoutePlanningWaypointKind {
    case rest
    case camp

    var title: String {
        switch self {
        case .rest: return "休息点"
        case .camp: return "露营候选"
        }
    }

    var tint: Color {
        switch self {
        case .rest: return AppDesign.success
        case .camp: return AppDesign.accent
        }
    }
}

struct RoutePlanningRiskSegment: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let points: [TrackPoint]
    let averageSlope: Double
    let distanceMeters: Double
    let elevationGain: Double

    var title: String {
        "第 \(dayIndex) 天风险坡段"
    }

    var detail: String {
        "长度约 \(Formatter.distance(distanceMeters))，连续抬升 \(Formatter.meters(elevationGain))，建议提前保留体能。"
    }
}

enum PlanningDifficulty {
    case easy
    case moderate
    case hard
    case intense

    var title: String {
        switch self {
        case .easy: return "轻松"
        case .moderate: return "中等"
        case .hard: return "困难"
        case .intense: return "高强度"
        }
    }

    var tint: Color {
        switch self {
        case .easy: return AppDesign.success
        case .moderate: return AppDesign.warning
        case .hard: return AppDesign.accentDeep
        case .intense: return AppDesign.error
        }
    }
}

enum RoutePlanner {
    private static let dayPalette: [Color] = [
        Color(red: 0.28, green: 0.52, blue: 0.39),
        Color(red: 0.77, green: 0.49, blue: 0.25),
        Color(red: 0.32, green: 0.47, blue: 0.67),
        Color(red: 0.68, green: 0.38, blue: 0.33),
        Color(red: 0.45, green: 0.42, blue: 0.26)
    ]

    static func makePlan(
        for track: Track,
        dailyDistanceKilometers: Double,
        maxDailyAscentMeters: Double
    ) -> RoutePlanningPlan {
        let points = track.points
        guard points.count > 1 else {
            let day = makeDay(points: points, sourceSegments: track.segments, dayIndex: 1)
            return RoutePlanningPlan(
                days: [day],
                warnings: [],
                difficulty: day.difficulty,
                overview: "轨迹点较少，建议先补充完整 GPX 再做多日规划。",
                waypoints: [],
                riskSegments: []
            )
        }

        let targetDistanceMeters = max(dailyDistanceKilometers, 1) * 1000
        let targetAscentMeters = max(maxDailyAscentMeters, 100)

        var days = [RoutePlanningDay]()
        var currentPoints = [points[0]]
        var currentDistance = 0.0
        var currentAscent = 0.0

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let sampleDistance = sampleDistanceMeters(from: previous, to: current)
            let sampleAscent = max(0, (current.elevation ?? previous.elevation ?? 0) - (previous.elevation ?? current.elevation ?? 0))

            currentPoints.append(current)
            currentDistance += sampleDistance
            currentAscent += sampleAscent

            let enoughForSplit = currentDistance >= targetDistanceMeters * 0.75 || currentAscent >= targetAscentMeters * 0.75
            let hitLimit = currentDistance >= targetDistanceMeters || currentAscent >= targetAscentMeters
            let hasEnoughRemainingPoints = points.count - index > 12

            if enoughForSplit && hitLimit && hasEnoughRemainingPoints {
                days.append(makeDay(points: currentPoints, sourceSegments: track.segments, dayIndex: days.count + 1))
                currentPoints = [current]
                currentDistance = 0
                currentAscent = 0
            }
        }

        if currentPoints.count > 1 {
            days.append(makeDay(points: currentPoints, sourceSegments: track.segments, dayIndex: days.count + 1))
        }

        if days.isEmpty {
            days = [makeDay(points: points, sourceSegments: track.segments, dayIndex: 1)]
        }

        let waypoints = detectWaypoints(days: days)
        let riskSegments = detectRiskSegments(days: days)
        let warnings = makeWarnings(
            days: days,
            targetDistanceKilometers: dailyDistanceKilometers,
            targetAscentMeters: maxDailyAscentMeters,
            riskSegments: riskSegments
        )
        let overallDifficulty = difficulty(for: track.summary.distanceMeters, ascentMeters: track.summary.totalAscent, averageSlope: track.summary.averageSlope ?? 0)
        let overview = "按每天约 \(Int(dailyDistanceKilometers)) km、单日爬升不超过 \(Int(maxDailyAscentMeters)) m 拆分，当前更适合 \(days.count) 天完成。已额外标出平缓候选点和高坡度风险段。"

        return RoutePlanningPlan(
            days: days,
            warnings: warnings,
            difficulty: overallDifficulty,
            overview: overview,
            waypoints: waypoints,
            riskSegments: riskSegments
        )
    }

    private static func makeDay(points: [TrackPoint], sourceSegments: [[TrackPoint]], dayIndex: Int) -> RoutePlanningDay {
        let segments = extractedSegments(for: points, from: sourceSegments)
        let summary = TrackSummary(segments: segments.isEmpty ? [points] : segments, activityMode: .hiking)
        let estimatedHours = estimateHours(distanceMeters: summary.distanceMeters, ascentMeters: summary.totalAscent, descentMeters: summary.totalDescent)
        let difficulty = difficulty(
            for: summary.distanceMeters,
            ascentMeters: summary.totalAscent,
            averageSlope: summary.averageSlope ?? 0
        )

        return RoutePlanningDay(
            dayIndex: dayIndex,
            points: points,
            segments: segments.isEmpty ? [points] : segments,
            distanceMeters: summary.distanceMeters,
            ascentMeters: summary.totalAscent,
            averageSlope: summary.averageSlope ?? 0,
            estimatedHours: estimatedHours,
            difficulty: difficulty,
            restSuggestion: restSuggestion(for: summary, dayIndex: dayIndex),
            color: dayPalette[(dayIndex - 1) % dayPalette.count]
        )
    }

    private static func extractedSegments(for points: [TrackPoint], from sourceSegments: [[TrackPoint]]) -> [[TrackPoint]] {
        guard points.isEmpty == false else { return [] }

        let pointIDs = Set(points.map(\.id))
        var result = [[TrackPoint]]()

        for sourceSegment in sourceSegments {
            var currentSegment = [TrackPoint]()

            for point in sourceSegment {
                if pointIDs.contains(point.id) {
                    currentSegment.append(point)
                } else if currentSegment.count > 1 {
                    result.append(currentSegment)
                    currentSegment = []
                } else {
                    currentSegment = []
                }
            }

            if currentSegment.count > 1 {
                result.append(currentSegment)
            }
        }

        return result
    }

    private static func estimateHours(distanceMeters: Double, ascentMeters: Double, descentMeters: Double) -> Double {
        let distanceHours = (distanceMeters / 1000) / 4.2
        let ascentHours = ascentMeters / 600
        let descentHours = descentMeters / 1200
        return max(1, distanceHours + ascentHours + descentHours)
    }

    private static func difficulty(for distanceMeters: Double, ascentMeters: Double, averageSlope: Double) -> PlanningDifficulty {
        let distanceScore = distanceMeters / 1000
        let ascentScore = ascentMeters / 180
        let slopeScore = max(0, averageSlope) * 0.9
        let score = distanceScore + ascentScore + slopeScore

        switch score {
        case ..<12:
            return .easy
        case ..<19:
            return .moderate
        case ..<27:
            return .hard
        default:
            return .intense
        }
    }

    private static func restSuggestion(for summary: TrackSummary, dayIndex: Int) -> String {
        if summary.distanceMeters / 1000 > 16 || summary.totalAscent > 1200 {
            return "第 \(dayIndex) 天负荷偏高，建议优先把休息点或露营点放在补给更稳定的位置。"
        }

        if (summary.averageSlope ?? 0) > 16 {
            return "第 \(dayIndex) 天整体坡度更明显，建议提早出发，给陡坡和下撤预留时间。"
        }

        return "第 \(dayIndex) 天节奏相对均衡，适合作为常规推进日。"
    }

    private static func detectWaypoints(days: [RoutePlanningDay]) -> [RoutePlanningWaypoint] {
        var results = [RoutePlanningWaypoint]()

        for day in days {
            guard day.points.count > 12 else { continue }
            let progressPoints = cumulativeProgress(for: day.points)
            let candidateFractions: [(Double, RoutePlanningWaypointKind)] = day.distanceMeters / 1000 > 14
                ? [(0.33, .rest), (0.68, .camp)]
                : [(0.45, .rest)]

            for candidate in candidateFractions {
                let targetDistance = day.distanceMeters * candidate.0
                guard let index = progressPoints.firstIndex(where: { $0 >= targetDistance }) else { continue }
                let nearbySlope = averageSlope(around: index, in: day.points, radius: 3)
                guard abs(nearbySlope) <= 9 else { continue }

                results.append(
                    RoutePlanningWaypoint(
                        kind: candidate.1,
                        point: day.points[index],
                        dayIndex: day.dayIndex,
                        kilometerMark: progressPoints[index] / 1000,
                        nearbySlope: nearbySlope
                    )
                )
            }
        }

        return results
    }

    private static func detectRiskSegments(days: [RoutePlanningDay]) -> [RoutePlanningRiskSegment] {
        var risks = [RoutePlanningRiskSegment]()

        for day in days {
            guard day.points.count > 6 else { continue }

            var currentRisk = [TrackPoint]()
            var currentDistance = 0.0
            var currentGain = 0.0
            var currentSlopeSamples = [Double]()

            for index in 1..<day.points.count {
                let previous = day.points[index - 1]
                let current = day.points[index]
                let distance = sampleDistanceMeters(from: previous, to: current)
                guard distance > 0 else { continue }

                let elevationDiff = (current.elevation ?? previous.elevation ?? 0) - (previous.elevation ?? current.elevation ?? 0)
                let slope = (elevationDiff / distance) * 100
                let isRisky = distance >= 18 && slope >= 22

                if isRisky {
                    if currentRisk.isEmpty {
                        currentRisk.append(previous)
                    }
                    currentRisk.append(current)
                    currentDistance += distance
                    currentGain += max(0, elevationDiff)
                    currentSlopeSamples.append(slope)
                } else if currentRisk.count > 1 {
                    if let risk = finalizedRisk(
                        dayIndex: day.dayIndex,
                        points: currentRisk,
                        distanceMeters: currentDistance,
                        elevationGain: currentGain,
                        slopeSamples: currentSlopeSamples
                    ) {
                        risks.append(risk)
                    }
                    currentRisk = []
                    currentDistance = 0
                    currentGain = 0
                    currentSlopeSamples = []
                }
            }

            if currentRisk.count > 1,
               let risk = finalizedRisk(
                   dayIndex: day.dayIndex,
                   points: currentRisk,
                   distanceMeters: currentDistance,
                   elevationGain: currentGain,
                   slopeSamples: currentSlopeSamples
               ) {
                risks.append(risk)
            }
        }

        return risks
    }

    private static func finalizedRisk(
        dayIndex: Int,
        points: [TrackPoint],
        distanceMeters: Double,
        elevationGain: Double,
        slopeSamples: [Double]
    ) -> RoutePlanningRiskSegment? {
        guard distanceMeters >= 120, slopeSamples.isEmpty == false else { return nil }
        let averageSlope = slopeSamples.reduce(0, +) / Double(slopeSamples.count)
        return RoutePlanningRiskSegment(
            dayIndex: dayIndex,
            points: points,
            averageSlope: averageSlope,
            distanceMeters: distanceMeters,
            elevationGain: elevationGain
        )
    }

    private static func makeWarnings(
        days: [RoutePlanningDay],
        targetDistanceKilometers: Double,
        targetAscentMeters: Double,
        riskSegments: [RoutePlanningRiskSegment]
    ) -> [String] {
        var warnings = [String]()

        for day in days {
            let dayDistance = day.distanceMeters / 1000
            if dayDistance > targetDistanceKilometers * 1.2 {
                warnings.append("\(day.title) 里程达到 \(String(format: "%.1f", dayDistance)) km，已经明显高于目标日里程。")
            }

            if day.ascentMeters > targetAscentMeters * 1.15 {
                warnings.append("\(day.title) 爬升约 \(Int(day.ascentMeters)) m，建议评估体能和补给。")
            }

            if day.averageSlope > 18 {
                warnings.append("\(day.title) 平均坡度偏高，可能包含连续陡升或技术性下降。")
            }

            if day.estimatedHours > 8.5 {
                warnings.append("\(day.title) 预计徒步时长超过 \(Formatter.durationHours(day.estimatedHours))，更适合尽早起步。")
            }
        }

        for risk in riskSegments.prefix(3) {
            warnings.append("\(risk.title) 出现连续高坡度段，建议在进入前完成补水并预留下撤判断。")
        }

        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    private static func cumulativeProgress(for points: [TrackPoint]) -> [Double] {
        guard points.isEmpty == false else { return [] }
        var progress = [Double](repeating: 0, count: points.count)
        var total = 0.0

        for index in 1..<points.count {
            total += sampleDistanceMeters(from: points[index - 1], to: points[index])
            progress[index] = total
        }

        return progress
    }

    private static func averageSlope(around index: Int, in points: [TrackPoint], radius: Int) -> Double {
        let lowerBound = max(0, index - radius)
        let upperBound = min(points.count - 1, index + radius)
        guard upperBound > lowerBound else { return 0 }

        var totalSlope = 0.0
        var count = 0.0

        for pointIndex in (lowerBound + 1)...upperBound {
            let previous = points[pointIndex - 1]
            let current = points[pointIndex]
            let distance = sampleDistanceMeters(from: previous, to: current)
            guard distance > 0 else { continue }
            let elevationDiff = (current.elevation ?? previous.elevation ?? 0) - (previous.elevation ?? current.elevation ?? 0)
            totalSlope += (elevationDiff / distance) * 100
            count += 1
        }

        return count > 0 ? totalSlope / count : 0
    }

    private static func sampleDistanceMeters(from start: TrackPoint, to end: TrackPoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

struct RoutePlanningMapView: View {
    let days: [RoutePlanningDay]
    let riskSegments: [RoutePlanningRiskSegment]
    let waypoints: [RoutePlanningWaypoint]

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size).insetBy(dx: 18, dy: 18)
            let projected = ProjectedRouteMap(days: days, riskSegments: riskSegments, waypoints: waypoints, rect: rect)

            ZStack {
                LinearGradient(
                    colors: [AppDesign.elevatedSurface, AppDesign.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppDesign.line, lineWidth: 1)

                ForEach(projected.dayLines) { line in
                    routePath(points: line.points)
                        .stroke(line.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }

                ForEach(projected.riskLines) { line in
                    routePath(points: line.points)
                        .stroke(AppDesign.error, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round, dash: [7, 6]))
                }

                ForEach(projected.waypointDots) { dot in
                    Circle()
                        .fill(dot.color)
                        .frame(width: dot.size, height: dot.size)
                        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 2))
                        .position(dot.point)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .drawingGroup()
        }
    }

    private func routePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct RoutePlanningMapPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.elevatedSurface, AppDesign.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppDesign.line, lineWidth: 1)

            VStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppDesign.secondaryInk)
                Text("正在准备规划地图")
                    .font(.appCaption)
                    .foregroundColor(AppDesign.secondaryInk)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ProjectedRouteMap {
    let dayLines: [ProjectedLine]
    let riskLines: [ProjectedLine]
    let waypointDots: [ProjectedWaypoint]

    init(days: [RoutePlanningDay], riskSegments: [RoutePlanningRiskSegment], waypoints: [RoutePlanningWaypoint], rect: CGRect) {
        let simplifiedDaySegments = days.flatMap { day in
            day.segments.flatMap { segment in
                Self.segmentedPoints(for: segment, maxPointsPerSegment: 260)
            }.map {
                SimplifiedDayLine(id: UUID(), color: day.color, points: $0)
            }
        }
        let simplifiedRisks = riskSegments.map { risk in
            SimplifiedRiskLine(id: risk.id, points: Self.simplifiedPoints(risk.points, maxPoints: 90))
        }

        let allPoints = simplifiedDaySegments.flatMap(\.points)
        let latitudes = allPoints.map(\.latitude)
        let longitudes = allPoints.map(\.longitude)

        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            self.dayLines = []
            self.riskLines = []
            self.waypointDots = []
            return
        }

        let latitudeSpan = max(maxLatitude - minLatitude, 0.0001)
        let longitudeSpan = max(maxLongitude - minLongitude, 0.0001)

        func project(_ point: TrackPoint) -> CGPoint {
            let xRatio = (point.longitude - minLongitude) / longitudeSpan
            let yRatio = (point.latitude - minLatitude) / latitudeSpan
            return CGPoint(
                x: rect.minX + rect.width * CGFloat(xRatio),
                y: rect.maxY - rect.height * CGFloat(yRatio)
            )
        }

        self.dayLines = simplifiedDaySegments.map {
            ProjectedLine(id: $0.id, points: $0.points.map(project), color: $0.color)
        }.filter { $0.points.count > 1 }

        self.riskLines = simplifiedRisks.map {
            ProjectedLine(id: $0.id, points: $0.points.map(project), color: AppDesign.error)
        }.filter { $0.points.count > 1 }

        self.waypointDots = waypoints.map {
            let waypointColor: Color
            let waypointSize: CGFloat
            switch $0.kind {
            case .camp:
                waypointColor = AppDesign.accent
                waypointSize = 14
            case .rest:
                waypointColor = AppDesign.success
                waypointSize = 12
            }

            return ProjectedWaypoint(
                id: $0.id,
                point: project($0.point),
                color: waypointColor,
                size: waypointSize
            )
        }
    }

    private static func simplifiedPoints(_ points: [TrackPoint], maxPoints: Int) -> [TrackPoint] {
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

    private static func segmentedPoints(for points: [TrackPoint], maxPointsPerSegment: Int) -> [[TrackPoint]] {
        guard points.count > 1 else { return points.isEmpty ? [] : [points] }

        let distances = zip(points, points.dropFirst()).map(sampleDistanceMeters)
        let sortedDistances = distances.sorted()
        let medianDistance = sortedDistances.isEmpty ? 0 : sortedDistances[sortedDistances.count / 2]
        let splitThreshold = max(150, medianDistance * 12)

        var segments = [[TrackPoint]]()
        var currentSegment = [points[0]]

        for index in 1..<points.count {
            let point = points[index]
            let previous = points[index - 1]
            let distance = sampleDistanceMeters(from: previous, to: point)

            if distance > splitThreshold, currentSegment.count > 1 {
                segments.append(simplifiedPoints(currentSegment, maxPoints: maxPointsPerSegment))
                currentSegment = [point]
                continue
            }

            currentSegment.append(point)
        }

        if currentSegment.count > 1 {
            segments.append(simplifiedPoints(currentSegment, maxPoints: maxPointsPerSegment))
        }

        return segments
    }

    private static func sampleDistanceMeters(from start: TrackPoint, to end: TrackPoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

private struct SimplifiedDayLine {
    let id: UUID
    let color: Color
    let points: [TrackPoint]
}

private struct SimplifiedRiskLine {
    let id: UUID
    let points: [TrackPoint]
}

private struct ProjectedLine: Identifiable {
    let id: UUID
    let points: [CGPoint]
    let color: Color
}

private struct ProjectedWaypoint: Identifiable {
    let id: UUID
    let point: CGPoint
    let color: Color
    let size: CGFloat
}
