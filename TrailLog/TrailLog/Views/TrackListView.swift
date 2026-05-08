import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [AppDesign.background, AppDesign.backgroundAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                if store.tracks.isEmpty {
                    VStack(spacing: 18) {
                        Spacer(minLength: 40)
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
                        Spacer()
                    }
                    .padding(24)
                    .appCardStyle()
                    .padding(.horizontal, AppDesign.horizontalPadding)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("我的路线")
                                .font(.appCaption)
                                .foregroundColor(AppDesign.accent)

                            ForEach(store.tracks) { track in
                                NavigationLink(destination: TrackDetailView(track: track)) {
                                    TrackRow(track: track)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, AppDesign.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarTitle(Text("我的轨迹"), displayMode: .large)
        }
    }
}

struct TrackRow: View {
    let track: Track

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
            }

            HStack(spacing: 12) {
                metricChip(icon: "figure.walk", value: String(format: "%.2f km", track.summary.distanceMeters / 1000))
                metricChip(icon: "mountain.2", value: "\(Int(track.summary.totalAscent)) m")
            }
        }
        .padding(20)
        .appCardStyle()
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
