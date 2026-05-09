import Foundation

enum EquipmentCategory: String, Codable, CaseIterable, Identifiable {
    case clothing
    case backpack
    case footwear
    case camping
    case electronics
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clothing: return "衣物"
        case .backpack: return "背包"
        case .footwear: return "鞋靴"
        case .camping: return "露营装备"
        case .electronics: return "电子设备"
        case .other: return "其他"
        }
    }
}

struct Equipment: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: EquipmentCategory
    var purchasePrice: Double
    var expectedLifetimeKilometers: Double
    var notes: String
    var createdAt: Date

    init(
        id: UUID = .init(),
        name: String,
        category: EquipmentCategory,
        purchasePrice: Double,
        expectedLifetimeKilometers: Double,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.purchasePrice = purchasePrice
        self.expectedLifetimeKilometers = expectedLifetimeKilometers
        self.notes = notes
        self.createdAt = createdAt
    }

    var costPerKilometer: Double {
        guard expectedLifetimeKilometers > 0 else { return 0 }
        return purchasePrice / expectedLifetimeKilometers
    }
}
