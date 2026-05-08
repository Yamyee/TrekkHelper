import SwiftUI

struct TrailLogRootView: View {
    @ObservedObject var trackStore: TrackStore

    var body: some View {
        MainTabView()
            .environmentObject(trackStore)
    }
}
