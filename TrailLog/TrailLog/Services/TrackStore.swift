import Foundation
import SwiftUI

struct TrackImportEvent: Identifiable, Equatable {
    let id = UUID()
    let trackID: UUID
    let trackName: String
}

final class TrackStore: ObservableObject {
    static let shared = TrackStore()

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var equipments: [Equipment] = []
    @Published var isHydratingData = true
    @Published var lastError: String?
    @Published var importStatus: String? = "等待导入GPX文件"
    @Published var lastImportEvent: TrackImportEvent?

    private let tracksPersistenceURL: URL
    private let equipmentPersistenceURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        self.tracksPersistenceURL = (documentsDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("tracks.json")
        self.equipmentPersistenceURL = (documentsDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("equipments.json")
    }

    func loadPersistedData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let loadedTracks = self.readTracks()
            let loadedEquipments = self.readEquipments()

            DispatchQueue.main.async {
                self.tracks = loadedTracks.tracks
                self.equipments = loadedEquipments.equipments

                if let importStatus = loadedTracks.importStatus {
                    self.importStatus = importStatus
                }

                if let lastError = loadedTracks.lastError ?? loadedEquipments.lastError {
                    self.lastError = lastError
                }

                self.isHydratingData = false
            }
        }
    }

    func importGPX(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                guard let self else { return }
                let track = try self.makeTrack(from: url)
                DispatchQueue.main.async {
                    self.insert(track)
                    self.importStatus = "已导入：\(track.name)"
                    self.lastImportEvent = TrackImportEvent(trackID: track.id, trackName: track.name)
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

    func deleteTrack(id: UUID) {
        tracks.removeAll { $0.id == id }
        persistTracks()
    }

    func renameTrack(id: UUID, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }

        tracks[index] = tracks[index].updatingName(trimmedName)
        persistTracks()
    }

    func addEquipment(_ equipment: Equipment) {
        equipments.insert(equipment, at: 0)
        persistEquipments()
    }

    func deleteEquipments(at offsets: IndexSet) {
        let removedIDs = offsets.map { equipments[$0].id }
        equipments.remove(atOffsets: offsets)
        if !removedIDs.isEmpty {
            tracks = tracks.map { track in
                let filteredIDs = track.equipmentIDs.filter { removedIDs.contains($0) == false }
                return filteredIDs == track.equipmentIDs ? track : track.updatingEquipmentIDs(filteredIDs)
            }
            persistTracks()
        }
        persistEquipments()
    }

    func updateEquipments(for trackID: UUID, equipmentIDs: [UUID]) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        let sanitizedIDs = equipmentIDs.filter { id in
            equipments.contains(where: { $0.id == id })
        }
        tracks[index] = tracks[index].updatingEquipmentIDs(sanitizedIDs)
        persistTracks()
    }

    func equipments(for ids: [UUID]) -> [Equipment] {
        let idSet = Set(ids)
        return equipments.filter { idSet.contains($0.id) }
    }

    func usageDistanceKilometers(for equipmentID: UUID) -> Double {
        tracks
            .filter { $0.equipmentIDs.contains(equipmentID) }
            .map { $0.summary.distanceMeters / 1000 }
            .reduce(0, +)
    }

    func usageCount(for equipmentID: UUID) -> Int {
        tracks.filter { $0.equipmentIDs.contains(equipmentID) }.count
    }

    func equipmentCost(for track: Track) -> Double {
        let distanceKilometers = track.summary.distanceMeters / 1000
        return equipments(for: track.equipmentIDs)
            .map { $0.costPerKilometer * distanceKilometers }
            .reduce(0, +)
    }

    private func insert(_ track: Track) {
        tracks.removeAll { existingTrack in
            existingTrack.id == track.id || isLikelySameTrack(existingTrack, as: track)
        }
        tracks.insert(track, at: 0)
        persistTracks()
    }

    private func isLikelySameTrack(_ lhs: Track, as rhs: Track) -> Bool {
        guard lhs.name == rhs.name else { return false }

        switch (lhs.startDate, rhs.startDate) {
        case let (.some(left), .some(right)):
            return abs(left.timeIntervalSince(right)) < 60
        case (.none, .none):
            return lhs.points.count == rhs.points.count
        default:
            return false
        }
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

    private func readTracks() -> (tracks: [Track], importStatus: String?, lastError: String?) {
        guard let data = try? Data(contentsOf: tracksPersistenceURL) else {
            return ([], nil, nil)
        }

        do {
            let tracks = try decoder.decode([Track].self, from: data)
                .sorted { $0.importedAt > $1.importedAt }
            return (tracks, nil, nil)
        } catch {
            return ([], "历史轨迹读取失败", "本地轨迹数据损坏，已忽略旧数据。")
        }
    }

    private func readEquipments() -> (equipments: [Equipment], lastError: String?) {
        guard let data = try? Data(contentsOf: equipmentPersistenceURL) else {
            return ([], nil)
        }

        do {
            let equipments = try decoder.decode([Equipment].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            return (equipments, nil)
        } catch {
            return ([], "装备数据读取失败，已忽略旧数据。")
        }
    }

    private func persistTracks() {
        do {
            let data = try encoder.encode(tracks)
            try data.write(to: tracksPersistenceURL, options: .atomic)
        } catch {
            lastError = "保存轨迹失败：\(error.localizedDescription)"
        }
    }

    private func persistEquipments() {
        do {
            let data = try encoder.encode(equipments)
            try data.write(to: equipmentPersistenceURL, options: .atomic)
        } catch {
            lastError = "保存装备失败：\(error.localizedDescription)"
        }
    }
}
