import Foundation

struct CustomUserActivity: Codable, Identifiable {
    let id: UUID
    var name: String
    var emoji: String
    var durationMinutes: Double
    var category: ActivityCategory

    func toActivity() -> Activity {
        Activity(
            id: "custom_\(id.uuidString)",
            name: name,
            emoji: emoji,
            durationMinutes: durationMinutes,
            category: category,
            detail: ""
        )
    }
}

struct UserPreferences: Codable {
    var selectedActivityIDs: [String]
    var customActivities: [CustomUserActivity]

    var hasAnyPreferences: Bool {
        !selectedActivityIDs.isEmpty || !customActivities.isEmpty
    }

    static var `default`: UserPreferences {
        UserPreferences(selectedActivityIDs: [], customActivities: [])
    }
}
