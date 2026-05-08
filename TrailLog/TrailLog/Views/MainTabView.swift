import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        TabView {
            ImportView()
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "square.and.arrow.down")
                        Text("导入")
                    }
                }

            TrackListView()
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "map")
                        Text("轨迹")
                    }
                }

            OfflineView()
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "tray.full")
                        Text("离线")
                    }
                }
        }
        .accentColor(AppDesign.accent)
        .onAppear {
            if store.tracks.isEmpty {
                store.importStatus = "等待导入GPX文件"
            }
        }
    }
}

struct OfflineView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppDesign.background, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer(minLength: 32)

                VStack(alignment: .leading, spacing: 18) {
                    AppStatusPill(text: "OFFLINE READY", tint: AppDesign.warning)

                    Image(systemName: "wifi.slash")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundColor(AppDesign.warning)

                    Text("离线模式已就绪")
                        .font(.appTitle)
                        .foregroundColor(AppDesign.ink)

                    Text("轨迹、统计和地图预览都保留在本地缓存。没有信号时，也能像翻看笔记一样，从容回读每一段路线。")
                        .font(.appBody)
                        .foregroundColor(AppDesign.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCardStyle()

                Spacer()
            }
            .padding(.horizontal, AppDesign.horizontalPadding)
            .padding(.bottom, 24)
        }
    }
}
