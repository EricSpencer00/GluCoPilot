import Foundation

@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()

    struct LoggedItem: Codable, Identifiable {
        var id: UUID = UUID()
        let type: String // "food", "insulin", "note", etc.
        let payload: [String: String] // simple string payload for now
        let timestamp: Date
    }

    @Published private(set) var items: [LoggedItem] = []

    private let storageKey = "glucopilot_cache_v1"

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([LoggedItem].self, from: data) {
            items = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func log(type: String, payload: [String: String], at timestamp: Date = Date()) {
        let item = LoggedItem(type: type, payload: payload, timestamp: timestamp)
        items.insert(item, at: 0)
        // Keep last 48 entries to avoid unbounded growth
        if items.count > 200 { items = Array(items.prefix(200)) }
        persist()
    }

    func getItems(since: Date) -> [LoggedItem] {
        return items.filter { $0.timestamp >= since }
    }

    func clearAll() {
        items.removeAll()
        persist()
    }
}
