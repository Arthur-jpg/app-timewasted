import Foundation

enum SharedDefaults {
    static let appGroupID = "group.com.arthurschiller.timeWasted"
    static var container: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    enum Keys {
        static let dailySecondsPrefix = "dailySeconds_"
        static let weeklySeconds = "weeklySeconds"
        static let activitySelection = "activitySelection"
        static let isAuthorized = "isAuthorized"
        static let lastUpdated = "lastUpdated"
        static let useSampleData = "useSampleData"
        static let monitorConfigurationVersion = "monitorConfigurationVersion"
        static let monitorGeneration = "monitorGeneration"
        static let userPreferences = "userPreferences"
        static let userPreferencesRevision = "userPreferencesRevision"
        // Debug keys — written by MonitorExtension to confirm it's running
        static let debugMonitorLastStart = "debug_monitorLastStart"
        static let debugMonitorLastThreshold = "debug_monitorLastThreshold"
        static let debugMonitorLastThresholdTime = "debug_monitorLastThresholdTime"
        static let debugContainerAccessible = "debug_containerAccessible"
        static let debugExtensionInit = "debug_extensionInit"
        static let debugNotificationLastEvaluation = "debug_notificationLastEvaluation"
        static let debugNotificationLastAttempt = "debug_notificationLastAttempt"
        static let debugNotificationLastSuccess = "debug_notificationLastSuccess"
        static let debugNotificationLastError = "debug_notificationLastError"
    }

    static func dateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Keys.dailySecondsPrefix + formatter.string(from: date)
    }

    static func saveDailySeconds(_ seconds: TimeInterval, for date: Date = .now) {
        container?.set(seconds, forKey: dateKey(for: date))
        container?.set(Date.now, forKey: Keys.lastUpdated)
    }

    static func saveDailySecondsIfGreater(_ seconds: TimeInterval, for date: Date = .now) {
        guard seconds > loadDailySeconds(for: date) else { return }
        saveDailySeconds(seconds, for: date)
    }

    static func resetDailySeconds(for date: Date = .now) {
        saveDailySeconds(0, for: date)
    }

    static func loadDailySeconds(for date: Date = .now) -> TimeInterval {
        container?.double(forKey: dateKey(for: date)) ?? 0
    }

    static func hasDailyData(inLastDays numberOfDays: Int = 7) -> Bool {
        let calendar = Calendar.current
        return (0..<numberOfDays).contains { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else {
                return false
            }
            return container?.object(forKey: dateKey(for: date)) != nil
        }
    }

    static func hasDailyData(for date: Date) -> Bool {
        container?.object(forKey: dateKey(for: date)) != nil
    }

    static func loadWeeklySeconds() -> TimeInterval {
        loadAccumulatedSeconds(for: .weekOfYear)
    }

    static func loadMonthlySeconds() -> TimeInterval {
        loadAccumulatedSeconds(for: .month)
    }

    static func loadYearlySeconds() -> TimeInterval {
        loadAccumulatedSeconds(for: .year)
    }

    static func loadSeconds(for timeframe: TimeFrame) -> TimeInterval {
        switch timeframe {
        case .day: loadDailySeconds()
        case .week: loadWeeklySeconds()
        case .month: loadMonthlySeconds()
        case .year: loadYearlySeconds()
        }
    }

    private static func loadAccumulatedSeconds(for component: Calendar.Component) -> TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let interval = calendar.dateInterval(of: component, for: today) else {
            return loadDailySeconds()
        }

        var total: TimeInterval = 0
        var date = calendar.startOfDay(for: interval.start)
        while date <= today {
            total += loadDailySeconds(for: date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        return total
    }

    static func loadUserPreferences() -> UserPreferences {
        guard
            let data = container?.data(forKey: Keys.userPreferences),
            let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return .default }
        return prefs
    }

    static func saveUserPreferences(_ prefs: UserPreferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        container?.set(data, forKey: Keys.userPreferences)
        container?.set(userPreferencesRevision + 1, forKey: Keys.userPreferencesRevision)
    }

    static var userPreferencesRevision: Int {
        container?.integer(forKey: Keys.userPreferencesRevision) ?? 0
    }
}
