import SwiftUI

@main
struct TrekkHelperApp: App {
    @StateObject private var trackStore = TrackStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(trackStore)
        }
    }
}
