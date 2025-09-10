import Foundation

struct WorkoutItem: Identifiable, Codable, Equatable {
    let id: String
    let type: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Double
    let caloriesKcal: Double
    let sourceName: String?
    let sourceBundleId: String?

    init(id: String = UUID().uuidString,
         type: String,
         startDate: Date,
         endDate: Date,
         durationMinutes: Double,
         caloriesKcal: Double,
         sourceName: String? = nil,
         sourceBundleId: String? = nil) {
        self.id = id
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.caloriesKcal = caloriesKcal
        self.sourceName = sourceName
        self.sourceBundleId = sourceBundleId
    }
}
