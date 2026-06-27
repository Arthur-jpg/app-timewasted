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
        // Debug keys — written by MonitorExtension to confirm it's running
        static let debugMonitorLastStart = "debug_monitorLastStart"
        static let debugMonitorLastThreshold = "debug_monitorLastThreshold"
        static let debugMonitorLastThresholdTime = "debug_monitorLastThresholdTime"
        static let debugContainerAccessible = "debug_containerAccessible"
        static let debugExtensionInit = "debug_extensionInit"
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
        let calendar = Calendar.current
        let today = Date.now
        var total: TimeInterval = 0
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                total += loadDailySeconds(for: date)
            }
        }
        return total
    }

    static func loadMonthlySeconds() -> TimeInterval {
        let calendar = Calendar.current
        let today = Date.now
        var total: TimeInterval = 0
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        for dayOffset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                total += loadDailySeconds(for: date)
            }
        }
        return total
    }

    static func loadYearlySeconds() -> TimeInterval {
        let daily = loadDailySeconds()
        let weekly = loadWeeklySeconds()
        let dailyAvg = weekly > 0 ? weekly / 7 : daily
        return dailyAvg * 365
    }
}
