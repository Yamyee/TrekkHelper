import SwiftUI

struct TrackListView: View {
    @EnvironmentObject private var store: TrackStore

    var body: some View {
        NavigationStack {
            if store.tracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("暂无已导入轨迹")
                        .font(.title3)
                        .bold()
                    Text("请先通过“导入”页面导入 GPX 文件，开始查看轨迹详情与海拔剖面。")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                List {
                    ForEach(store.tracks) { track in
                        NavigationLink(destination: TrackDetailView(track: track)) {
                            TrackRow(track: track)
                        }
                    }
                    .onDelete(perform: store.deleteTracks)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("我的轨迹")
        }
    }
}

struct TrackRow: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(track.name)
                .font(.headline)
            Text("里程：\(String(format: "%.2f", track.summary.distanceMeters / 1000)) km · 爬升：\(Int(track.summary.totalAscent)) m")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}
