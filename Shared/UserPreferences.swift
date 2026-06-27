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

struct ActivityNotificationRule: Codable, Identifiable {
    var id: String { activityID }
    var activityID: String
    var isEnabled: Bool
    var dailyTarget: Int
    var weeklyTarget: Int
    var monthlyTarget: Int

    static func `default`(for activityID: String) -> ActivityNotificationRule {
        ActivityNotificationRule(
            activityID: activityID,
            isEnabled: true,
            dailyTarget: 1,
            weeklyTarget: 5,
            monthlyTarget: 20
        )
    }
}

struct UserPreferences: Codable {
    var selectedActivityIDs: [String]
    var customActivities: [CustomUserActivity]
    var metricNotificationsEnabled: Bool
    var notificationRules: [ActivityNotificationRule]

    init(
        selectedActivityIDs: [String],
        customActivities: [CustomUserActivity],
        metricNotificationsEnabled: Bool = false,
        notificationRules: [ActivityNotificationRule] = []
    ) {
        self.selectedActivityIDs = selectedActivityIDs
        self.customActivities = customActivities
        self.metricNotificationsEnabled = metricNotificationsEnabled
        self.notificationRules = notificationRules
    }

    private enum CodingKeys: String, CodingKey {
        case selectedActivityIDs
        case customActivities
        case metricNotificationsEnabled
        case notificationRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedActivityIDs = try container.decodeIfPresent([String].self, forKey: .selectedActivityIDs) ?? []
        customActivities = try container.decodeIfPresent([CustomUserActivity].self, forKey: .customActivities) ?? []
        metricNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .metricNotificationsEnabled) ?? false
        notificationRules = try container.decodeIfPresent([ActivityNotificationRule].self, forKey: .notificationRules) ?? []
    }

    mutating func setNotificationRule(_ rule: ActivityNotificationRule) {
        notificationRules.removeAll { $0.activityID == rule.activityID }
        notificationRules.append(rule)
    }

    func notificationRule(for activityID: String) -> ActivityNotificationRule {
        notificationRules.first { $0.activityID == activityID }
            ?? .default(for: activityID)
    }

    var hasAnyPreferences: Bool {
        !selectedActivityIDs.isEmpty || !customActivities.isEmpty
    }

    static var `default`: UserPreferences {
        UserPreferences(selectedActivityIDs: [], customActivities: [])
    }
}
