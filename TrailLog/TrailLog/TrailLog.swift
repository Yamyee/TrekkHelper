import SwiftUI

struct TrailLogRootView: View {
    @ObservedObject var trackStore: TrackStore
    @State private var showLaunchOverlay = true

    var body: some View {
        ZStack {
            MainTabView()
                .environmentObject(trackStore)

            if showLaunchOverlay {
                LaunchOverlayView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showLaunchOverlay = false
                }
            }
        }
    }
}

private struct LaunchOverlayView: View {
    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                Text("山行记")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppDesign.accentDeep)

                Text("GPX 户外轨迹助手")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppDesign.secondaryInk)
            }
        }
    }
}
