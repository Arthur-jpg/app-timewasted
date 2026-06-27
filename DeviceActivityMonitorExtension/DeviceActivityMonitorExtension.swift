import DeviceActivity
import Foundation
import OSLog
import UserNotifications
import WidgetKit

private let logger = Logger(subsystem: "com.arthurschiller.timeWasteddd", category: "MonitorExtension")

// Info.plist resolves this as $(PRODUCT_MODULE_NAME).TimeWastedMonitor.
class TimeWastedMonitor: DeviceActivityMonitor {

    override init() {
        super.init()
        // First thing written to SharedDefaults — confirms the extension process launched.
        SharedDefaults.container?.set(Date.now, forKey: SharedDefaults.Keys.debugExtensionInit)
        logger.info("🚀 TimeWastedMonitor init — extension process launched")
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        SharedDefaults.container?.set(true, forKey: SharedDefaults.Keys.debugContainerAccessible)
        SharedDefaults.container?.set(Date.now, forKey: SharedDefaults.Keys.debugMonitorLastStart)
        logger.info("📅 intervalDidStart — activity: \(activity.rawValue)")

        // Only initialize to 0 on a genuine new day (no data for today yet).
        // Avoids resetting when startMonitoring() is called mid-day (e.g. on app launch),
        // which would briefly show 0 in the widget before threshold events fire.
        if !SharedDefaults.hasDailyData(for: .now) {
            SharedDefaults.saveDailySeconds(0, for: .now)
            WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
            logger.info("📅 New day — initialized daily seconds to 0")
        }
        // If data already exists, threshold events will fire (includesPastActivity: true)
        // and update the widget themselves.
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logger.info("⏱️ eventDidReachThreshold — event: \(event.rawValue)")

        let parts = event.rawValue.split(separator: ".")
        let currentGeneration = SharedDefaults.container?.integer(
            forKey: SharedDefaults.Keys.monitorGeneration
        ) ?? 0

        guard parts.count == 3,
              parts[0] == "usage",
              parts[1] == "g\(currentGeneration)",
              let minuteStr = parts[2].components(separatedBy: "min").first,
              let minutes = Double(minuteStr) else {
            logger.warning("⏭️ Ignoring stale or invalid event: \(event.rawValue)")
            return
        }

        let seconds = minutes * 60
        let currentSeconds = SharedDefaults.loadDailySeconds(for: .now)

        // Only save if the new value is higher — prevents out-of-order events
        // (fired in rapid succession on monitoring restart) from going backwards.
        guard seconds > currentSeconds else {
            logger.info("⏭️ Skipping \(seconds)s — already have \(currentSeconds)s")
            // A repeated/out-of-order callback may still be the first callback
            // after the user enabled a goal, so always evaluate notifications.
            evaluateMetricNotifications()
            return
        }

        // The system doesn't guarantee callback ordering when several past
        // thresholds are delivered together. Never let an older event reduce
        // the value already persisted for today.
        SharedDefaults.saveDailySecondsIfGreater(seconds, for: .now)
        SharedDefaults.container?.set(event.rawValue, forKey: SharedDefaults.Keys.debugMonitorLastThreshold)
        SharedDefaults.container?.set(Date.now, forKey: SharedDefaults.Keys.debugMonitorLastThresholdTime)
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
        evaluateMetricNotifications()
        logger.info("💾 Saved \(seconds)s (\(minutes)min)")
    }

    private func evaluateMetricNotifications() {
        SharedDefaults.container?.set(Date.now, forKey: SharedDefaults.Keys.debugNotificationLastEvaluation)
        let preferences = SharedDefaults.loadUserPreferences()
        guard preferences.metricNotificationsEnabled else { return }

        let builtIn = ActivityDatabase.all.filter {
            preferences.selectedActivityIDs.contains($0.id)
        }
        let activities = builtIn + preferences.customActivities.map { $0.toActivity() }
        guard !activities.isEmpty else { return }

        let totals: [(TimeFrame, TimeInterval)] = [
            (.day, SharedDefaults.loadDailySeconds()),
            (.week, SharedDefaults.loadWeeklySeconds()),
            (.month, SharedDefaults.loadMonthlySeconds())
        ]

        for activity in activities {
            let rule = preferences.notificationRule(for: activity.id)
            guard rule.isEnabled else { continue }

            for (timeframe, totalSeconds) in totals {
                let target: Int = switch timeframe {
                case .day: rule.dailyTarget
                case .week: rule.weeklyTarget
                case .month: rule.monthlyTarget
                case .year: 0
                }
                notifyIfReached(
                    activity: activity,
                    timeframe: timeframe,
                    target: target,
                    totalSeconds: totalSeconds
                )
            }
        }
    }

    private func notifyIfReached(
        activity: Activity,
        timeframe: TimeFrame,
        target: Int,
        totalSeconds: TimeInterval
    ) {
        guard target > 0 else { return }
        let requiredSeconds = activity.durationMinutes * 60 * Double(target)
        guard totalSeconds >= requiredSeconds else { return }

        let identifier = notificationIdentifier(
            activityID: activity.id,
            timeframe: timeframe,
            target: target
        )
        let sentKey = "metricNotificationSent_\(identifier)"
        guard SharedDefaults.container?.bool(forKey: sentKey) != true else { return }

        // Mark before scheduling because several threshold callbacks may arrive
        // together when monitoring restarts with includesPastActivity enabled.
        SharedDefaults.container?.set(true, forKey: sentKey)
        SharedDefaults.container?.set(
            "\(activity.name) · \(target)× · \(notificationPeriodText(timeframe))",
            forKey: SharedDefaults.Keys.debugNotificationLastAttempt
        )
        SharedDefaults.container?.removeObject(forKey: SharedDefaults.Keys.debugNotificationLastError)

        let content = UNMutableNotificationContent()
        content.title = "\(activity.emoji) Tempo equivalente a \(target)×"
        content.body = "Nas redes \(notificationPeriodText(timeframe)), você já gastou o equivalente a \(target)× \(activity.name.lowercased())."
        content.sound = .default
        content.threadIdentifier = "metric-goals"

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                SharedDefaults.container?.removeObject(forKey: sentKey)
                SharedDefaults.container?.set(
                    error.localizedDescription,
                    forKey: SharedDefaults.Keys.debugNotificationLastError
                )
                logger.error("🔕 Failed to schedule metric notification: \(error.localizedDescription)")
            } else {
                SharedDefaults.container?.set(
                    Date.now,
                    forKey: SharedDefaults.Keys.debugNotificationLastSuccess
                )
                logger.info("🔔 Metric notification sent: \(identifier)")
            }
        }
    }

    private func notificationIdentifier(
        activityID: String,
        timeframe: TimeFrame,
        target: Int,
        date: Date = .now
    ) -> String {
        let calendar = Calendar.current
        let component: Calendar.Component = switch timeframe {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        let start = calendar.dateInterval(of: component, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "metric.\(timeframe.rawValue).\(formatter.string(from: start)).\(activityID).\(target)"
    }

    private func notificationPeriodText(_ timeframe: TimeFrame) -> String {
        switch timeframe {
        case .day: "hoje"
        case .week: "esta semana"
        case .month: "este mês"
        case .year: "este ano"
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("🔚 intervalDidEnd — activity: \(activity.rawValue)")
    }
}
