import SwiftUI

struct FullScreenTrackMapView: View {
    let track: Track
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            TrackMapView(segments: track.segments, isInteractive: true, maxRenderPointCount: 1500)
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarTitle(Text(track.name), displayMode: .inline)
                .navigationBarItems(trailing: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
