import Foundation
import SwiftUI

final class TrackStore: ObservableObject {
    static let shared = TrackStore()

    @Published private(set) var tracks: [Track] = []
    @Published var lastError: String?
    @Published var importStatus: String? = "等待导入GPX文件"

    private let persistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.persistenceURL = (documentsDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("tracks.json")
        loadTracks()
    }

    func importGPX(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                guard let self else { return }
                let track = try self.makeTrack(from: url)
                DispatchQueue.main.async {
                    self.insert(track)
                    self.importStatus = "已导入：\(track.name)"
                    self.lastError = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self?.importStatus = "导入失败"
                    self?.lastError = "GPX解析失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func importGPX(at url: URL) throws -> Track {
        let track = try makeTrack(from: url)
        insert(track)
        return track
    }

    func deleteTracks(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
        persistTracks()
    }

    private func insert(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
        tracks.insert(track, at: 0)
        persistTracks()
    }

    private func makeTrack(from url: URL) throws -> Track {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try GPXParser.parse(url: url)
    }

    private func loadTracks() {
        guard let data = try? Data(contentsOf: persistenceURL) else {
            tracks = []
            return
        }

        do {
            tracks = try decoder.decode([Track].self, from: data)
                .sorted { $0.importedAt > $1.importedAt }
        } catch {
            tracks = []
            importStatus = "历史轨迹读取失败"
            lastError = "本地轨迹数据损坏，已忽略旧数据。"
        }
    }

    private func persistTracks() {
        do {
            let data = try encoder.encode(tracks)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            lastError = "保存轨迹失败：\(error.localizedDescription)"
        }
    }
}
