import SwiftUI

struct TrackDetailView: View {
    @EnvironmentObject private var store: TrackStore
    let track: Track
    @State private var showFullScreenMap = false
    @State private var showMapPreview = false
    @State private var showEquipmentSheet = false
    @State private var showShareSheet = false
    @State private var showPlanningSheet = false
    @State private var showRenameAlert = false
    @State private var showMoreActions = false
    @State private var draftTrackName = ""
    @State private var suggestedPlan = RoutePlanningPlan.empty
    @State private var isLoadingSuggestedPlan = true

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
                    TrackSummaryCard(summary: currentTrack.summary)

                    mapSection

                    ElevationProfileView(points: currentTrack.points)
                        .frame(height: 220)

                    planningSection

                    equipmentSection

                    detailSection
                }
                .padding(.horizontal, AppDesign.horizontalPadding)
                .padding(.vertical, 18)
            }
        }
        .navigationBarTitle(Text(currentTrack.name), displayMode: .large)
        .navigationBarItems(
            trailing: Button(action: {
                showMoreActions = true
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
            }
        )
        .sheet(isPresented: $showFullScreenMap) {
            FullScreenTrackMapView(track: currentTrack)
        }
        .sheet(isPresented: $showEquipmentSheet) {
            TrackEquipmentSelectionView(track: currentTrack)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPlanningSheet) {
            RoutePlanningSheetView(track: currentTrack)
        }
        .sheet(isPresented: $showShareSheet) {
            TrackSharePreviewView(track: currentTrack, equipmentCost: store.equipmentCost(for: currentTrack))
        }
        .sheet(isPresented: $showRenameAlert) {
            NavigationView {
                RenameTrackView(
                    initialName: currentTrack.name,
                    draftTrackName: $draftTrackName,
                    onCancel: {
                        showRenameAlert = false
                    },
                    onSave: {
                        store.renameTrack(id: currentTrack.id, to: draftTrackName)
                        showRenameAlert = false
                    }
                )
            }
        }
        .actionSheet(isPresented: $showMoreActions) {
            ActionSheet(
                title: Text("更多操作"),
                buttons: [
                    .default(Text("修改名称")) {
                        draftTrackName = currentTrack.name
                        showRenameAlert = true
                    },
                    .default(Text("路线规划")) {
                        showPlanningSheet = true
                    },
                    .default(Text("分享轨迹")) {
                        showShareSheet = true
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
        .onAppear {
            if showMapPreview == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showMapPreview = true
                }
            }
            loadSuggestedPlanIfNeeded()
        }
    }

    private var currentTrack: Track {
        store.tracks.first(where: { $0.id == track.id }) ?? track
    }

    private var selectedEquipments: [Equipment] {
        store.equipments(for: currentTrack.equipmentIDs)
    }

    private var equipmentCostText: String {
        String(format: "¥%.2f", store.equipmentCost(for: currentTrack))
    }

    private var mapSection: some View {
        VStack(spacing: 0) {
            Button(action: { showFullScreenMap = true }) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if showMapPreview {
                            TrackMapView(segments: currentTrack.segments, maxRenderPointCount: 250)
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

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本次装备")
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)
                    Text("把实际使用的装备关联到这条轨迹，自动核算单次分摊成本。")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.secondaryInk)
                }

                Spacer()

                Button(action: { showEquipmentSheet = true }) {
                    Text(selectedEquipments.isEmpty ? "选择装备" : "编辑")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .frame(width: 112)
            }

            if selectedEquipments.isEmpty {
                Text("还没有关联装备。选择鞋靴、背包或衣物后，这里会显示本次使用清单和分摊成本。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            } else {
                ForEach(selectedEquipments) { equipment in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(equipment.name)
                                .font(.appBody.weight(.semibold))
                                .foregroundColor(AppDesign.ink)
                            Text(equipment.category.title)
                                .font(.appCaption)
                                .foregroundColor(AppDesign.secondaryInk)
                        }
                        Spacer()
                        Text(String(format: "¥%.2f", equipment.costPerKilometer * currentTrack.summary.distanceMeters / 1000))
                            .font(.appBody.weight(.semibold))
                            .foregroundColor(AppDesign.accentDeep)
                    }
                }
            }

            HStack {
                Text("本次装备分摊成本")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
                Spacer()
                Text(equipmentCostText)
                    .font(.appSection)
                    .foregroundColor(AppDesign.ink)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .appCardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("路线规划")
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)
                    Text("按徒步模式优先控制单日里程和爬升，先给出一版稳妥行程。")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.secondaryInk)
                }

                Spacer()

                Button(action: { showPlanningSheet = true }) {
                    Text("去规划")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .frame(width: 112)
            }

            HStack(spacing: 12) {
                planningMetric(title: "建议天数", value: isLoadingSuggestedPlan ? "计算中" : "\(suggestedPlan.days.count) 天")
                planningMetric(title: "整体难度", value: isLoadingSuggestedPlan ? "计算中" : suggestedPlan.difficulty.title)
            }

            if isLoadingSuggestedPlan {
                Text("正在计算首版路线规划。")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            } else if let firstDay = suggestedPlan.days.first {
                Text("首日参考：\(Formatter.distance(firstDay.distanceMeters)) · 爬升 \(Formatter.meters(firstDay.ascentMeters)) · 预计 \(Formatter.durationHours(firstDay.estimatedHours))")
                    .font(.appBody)
                    .foregroundColor(AppDesign.secondaryInk)
            }
        }
        .padding(22)
        .appCardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planningMetric(title: String, value: String) -> some View {
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

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("路线细节")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Group {
                detailRow(icon: "waveform.path", title: "点数", value: "\(currentTrack.summary.pointCount)")
                detailRow(icon: "mountain.2", title: "最高海拔", value: currentTrack.summary.maxElevation.map { String(format: "%.0f m", $0) } ?? "未知")
                detailRow(icon: "arrow.down", title: "最低海拔", value: currentTrack.summary.minElevation.map { String(format: "%.0f m", $0) } ?? "未知")
                detailRow(icon: "triangle.fill", title: "平均坡度", value: currentTrack.summary.averageSlope.map { String(format: "%.1f%%", $0) } ?? "0%")
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

    private func loadSuggestedPlanIfNeeded() {
        guard isLoadingSuggestedPlan else { return }
        guard suggestedPlan.days.isEmpty else { return }

        let track = currentTrack
        DispatchQueue.global(qos: .userInitiated).async {
            let plan = RoutePlanner.makePlan(for: track, dailyDistanceKilometers: 12, maxDailyAscentMeters: 900)

            DispatchQueue.main.async {
                suggestedPlan = plan
                isLoadingSuggestedPlan = false
            }
        }
    }
}

private struct RoutePlanningSheetView: View {
    let track: Track
    @State private var isReady = false

    var body: some View {
        NavigationView {
            Group {
                if isReady {
                    RoutePlanningView(track: track)
                } else {
                    RoutePlanningLoadingView()
                }
            }
        }
        .onAppear {
            guard isReady == false else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isReady = true
            }
        }
    }
}

private struct RoutePlanningLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.background, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                AppLoadingIndicator()
                    .scaleEffect(1.15)

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
        .navigationBarTitle(Text("路线规划"), displayMode: .inline)
    }
}

private struct RenameTrackView: View {
    let initialName: String
    @Binding var draftTrackName: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        Form {
            Section(header: Text("路线名称")) {
                TextField("输入路线名称", text: $draftTrackName)
            }

            Section(footer: Text("更新后会同步到轨迹列表和详情页。")) {
                EmptyView()
            }
        }
        .navigationBarTitle(Text("修改路线名称"), displayMode: .inline)
        .navigationBarItems(
            leading: Button("取消") {
                draftTrackName = initialName
                onCancel()
            },
            trailing: Button("保存") {
                onSave()
            }
            .disabled(draftTrackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        )
        .onAppear {
            draftTrackName = initialName
        }
    }
}

struct TrackEquipmentSelectionView: View {
    @EnvironmentObject private var store: TrackStore
    @Environment(\.presentationMode) private var presentationMode

    let track: Track
    @State private var selectedIDs: Set<UUID>

    init(track: Track) {
        self.track = track
        self._selectedIDs = State(initialValue: Set(track.equipmentIDs))
    }

    var body: some View {
        NavigationView {
            List {
                if store.equipments.isEmpty {
                    Text("还没有可选装备，请先到装备页录入。")
                        .foregroundColor(AppDesign.secondaryInk)
                } else {
                    ForEach(store.equipments) { equipment in
                        Button(action: { toggle(equipment.id) }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(equipment.name)
                                        .foregroundColor(AppDesign.ink)
                                    Text("\(equipment.category.title) · ¥\(Int(equipment.purchasePrice))")
                                        .font(.caption)
                                        .foregroundColor(AppDesign.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: selectedIDs.contains(equipment.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIDs.contains(equipment.id) ? AppDesign.accent : AppDesign.line)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationBarTitle(Text("关联装备"), displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    store.updateEquipments(for: track.id, equipmentIDs: Array(selectedIDs))
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
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
