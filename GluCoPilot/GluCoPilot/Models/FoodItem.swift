import Foundation

/// Standardized frontend Food model used across the app
struct FoodItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String?
    let timestamp: Date
    let caloriesKcal: Double
    let carbsGrams: Double
    let proteinGrams: Double
    let fatGrams: Double
    let sourceName: String?
    let sourceBundleId: String?
    let metadata: [String: AnyCodable]?

    init(id: String = UUID().uuidString,
         name: String? = nil,
         timestamp: Date,
         caloriesKcal: Double = 0,
         carbsGrams: Double = 0,
         proteinGrams: Double = 0,
         fatGrams: Double = 0,
         sourceName: String? = nil,
         sourceBundleId: String? = nil,
         metadata: [String: AnyCodable]? = nil) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.caloriesKcal = caloriesKcal
        self.carbsGrams = carbsGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
        self.metadata = metadata
    }
}

// Small helper to allow storing heterogeneous metadata in Codable structs
// Use minimal AnyCodable implementation to avoid external dependency
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int; return }
        if let double = try? container.decode(Double.self) { value = double; return }
        if let bool = try? container.decode(Bool.self) { value = bool; return }
        if let string = try? container.decode(String.self) { value = string; return }
        if let dict = try? container.decode([String: AnyCodable].self) { value = dict; return }
        if let arr = try? container.decode([AnyCodable].self) { value = arr; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        case let dict as [String: AnyCodable]: try container.encode(dict)
        case let arr as [AnyCodable]: try container.encode(arr)
        default: try container.encode(String(describing: value))
        }
    }
}
