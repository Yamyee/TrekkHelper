import SwiftUI

struct TrackHubView: View {
    @EnvironmentObject private var store: TrackStore
    @State private var showImportSheet = false
    @State private var pendingDeleteTrack: Track?
    @State private var showDeleteAlert = false
    @State private var highlightedTrackID: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        importCard

                        Group {
                            if store.isHydratingData && store.tracks.isEmpty {
                                loadingStateCard
                            } else if store.tracks.isEmpty {
                                emptyStateCard
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("我的路线")
                                        .font(.appCaption)
                                        .foregroundColor(AppDesign.accent)

                                    ForEach(store.tracks) { track in
                                        ZStack(alignment: .topTrailing) {
                                            NavigationLink(destination: TrackDetailView(track: track)) {
                                                TrackRow(
                                                    track: track,
                                                    isHighlighted: highlightedTrackID == track.id
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            Button(action: {
                                                pendingDeleteTrack = track
                                                showDeleteAlert = true
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(AppDesign.secondaryInk)
                                                    .frame(width: 34, height: 34)
                                                    .background(AppDesign.elevatedSurface)
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.top, 14)
                                            .padding(.trailing, 14)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppDesign.horizontalPadding)
                    .padding(.vertical, 18)
                }
                .onReceive(store.$lastImportEvent) { event in
                    guard let event else { return }
                    showImportSheet = false
                    highlightedTrackID = event.trackID

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                        if highlightedTrackID == event.trackID {
                            withAnimation(.easeOut(duration: 0.3)) {
                                highlightedTrackID = nil
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(Text("我的轨迹"), displayMode: .large)
            .sheet(isPresented: $showImportSheet) {
                ImportView()
                    .environmentObject(store)
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("删除轨迹记录"),
                    message: Text(deletePromptMessage),
                    primaryButton: .destructive(Text("删除")) {
                        if let track = pendingDeleteTrack {
                            store.deleteTrack(id: track.id)
                        }
                        pendingDeleteTrack = nil
                        showDeleteAlert = false
                    },
                    secondaryButton: .cancel {
                        pendingDeleteTrack = nil
                        showDeleteAlert = false
                    }
                )
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("轨迹管理")
                .font(.appTitle)
                .foregroundColor(AppDesign.ink)
            Text("导入 GPX、查看历史路线、继续做规划和分享，都从这里开始。")
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
        }
        .padding(24)
        .appCardStyle()
    }

    private var importCard: some View {
        Button(action: { showImportSheet = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("新增轨迹")
                        .font(.appSection)
                        .foregroundColor(.white)
                    Text("支持本地文件、微信和网盘来源的 GPX 一键导入。")
                        .font(.appBody)
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(22)
            .background(AppDesign.accent)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyStateCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(AppDesign.success)
            Text("暂无轨迹数据")
                .font(.appTitle)
                .foregroundColor(AppDesign.ink)
            Text("先导入一条 GPX。之后这里会像一页安静的行程摘记，整理你的路线、里程和爬升记录。")
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(24)
        .appCardStyle()
    }

    private var loadingStateCard: some View {
        VStack(spacing: 16) {
            AppLoadingIndicator()
                .scaleEffect(1.1)

            Text("正在加载轨迹")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)

            Text("正在读取本地 GPX 记录和统计数据。")
                .font(.appBody)
                .foregroundColor(AppDesign.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(24)
        .appCardStyle()
    }

    private var deletePromptMessage: String {
        guard let track = pendingDeleteTrack else {
            return "删除后将无法恢复。"
        }
        return "“\(track.name)” 删除后将无法恢复。"
    }
}

struct TrackRow: View {
    @EnvironmentObject private var store: TrackStore
    let track: Track
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.name)
                        .font(.appSection)
                        .foregroundColor(AppDesign.ink)

                    Text(track.startDate.map(Formatter.dateTime) ?? "未记录时间")
                        .font(.appCaption)
                        .foregroundColor(AppDesign.secondaryInk)
                }

                Spacer()

                AppStatusPill(text: "\(track.summary.pointCount) 点", tint: AppDesign.accentDeep)
                    .padding(.trailing, 44)
            }

            HStack(spacing: 12) {
                metricChip(icon: "figure.walk", value: String(format: "%.2f km", track.summary.distanceMeters / 1000))
                metricChip(icon: "mountain.2", value: "\(Int(track.summary.totalAscent)) m")
                if track.equipmentIDs.isEmpty == false {
                    metricChip(icon: "yensign.circle", value: String(format: "¥%.0f", store.equipmentCost(for: track)))
                }
            }
        }
        .padding(20)
        .appCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighlighted ? AppDesign.accent : Color.clear, lineWidth: 2)
        )
        .shadow(
            color: isHighlighted ? AppDesign.accent.opacity(0.18) : Color.clear,
            radius: 18,
            x: 0,
            y: 10
        )
        .scaleEffect(isHighlighted ? 1.01 : 1)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
    }

    private func metricChip(icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.appCaption)
        .foregroundColor(AppDesign.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppDesign.elevatedSurface)
        .clipShape(Capsule())
    }
}
