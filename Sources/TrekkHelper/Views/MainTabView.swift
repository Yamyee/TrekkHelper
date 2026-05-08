import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        TabView {
            ImportView()
                .tabItem {
                    Label("导入", systemImage: "square.and.arrow.down")
                }

            TrackListView()
                .tabItem {
                    Label("轨迹", systemImage: "map")
                }

            OfflineView()
                .tabItem {
                    Label("离线", systemImage: "tray.full")
                }
        }
        .task {
            if store.tracks.isEmpty {
                store.importStatus = "等待导入GPX文件"
            }
        }
    }
}

struct OfflineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("离线模式启用")
                .font(.title2)
                .bold()
            Text("本应用核心功能可离线使用，导入轨迹、查看详情、轨迹管理均支持本地数据。")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
