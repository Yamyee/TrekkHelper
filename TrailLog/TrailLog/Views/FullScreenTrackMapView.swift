import SwiftUI

struct FullScreenTrackMapView: View {
    let track: Track
    @Environment(\.presentationMode) private var presentationMode
    @State private var isMapReady = false

    var body: some View {
        NavigationView {
            Group {
                if isMapReady {
                    TrackMapView(segments: track.segments, isInteractive: true, maxRenderPointCount: 1500)
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [AppDesign.background, AppDesign.backgroundAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 16) {
                            AppLoadingIndicator()
                                .scaleEffect(1.1)

                            Text("正在加载全屏地图")
                                .font(.appSection)
                                .foregroundColor(AppDesign.ink)

                            Text("正在准备轨迹渲染和交互。")
                                .font(.appBody)
                                .foregroundColor(AppDesign.secondaryInk)
                        }
                        .padding(28)
                        .appCardStyle()
                        .padding(.horizontal, 28)
                    }
                }
            }
            .navigationBarTitle(Text(track.name), displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard isMapReady == false else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isMapReady = true
            }
        }
    }
}
