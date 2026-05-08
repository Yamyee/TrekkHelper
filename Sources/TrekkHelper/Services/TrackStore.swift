import Foundation
import SwiftUI

@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published var lastError: String?
    @Published var importStatus: String? = "等待导入GPX文件"

    init() {
        self.tracks = []
    }

    func importGPX(from url: URL) async {
        do {
            let track = try GPXParser.parse(url: url)
            tracks.insert(track, at: 0)
            importStatus = "已导入：\(track.name)"
            lastError = nil
        } catch {
            importStatus = "导入失败"
            lastError = "GPX解析失败：\(error.localizedDescription)"
        }
    }

    func deleteTracks(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
    }
}
