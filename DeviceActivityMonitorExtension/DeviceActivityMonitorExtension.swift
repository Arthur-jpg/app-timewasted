import DeviceActivity
import Foundation
import OSLog
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
            return
        }

        // The system doesn't guarantee callback ordering when several past
        // thresholds are delivered together. Never let an older event reduce
        // the value already persisted for today.
        SharedDefaults.saveDailySecondsIfGreater(seconds, for: .now)
        SharedDefaults.container?.set(event.rawValue, forKey: SharedDefaults.Keys.debugMonitorLastThreshold)
        SharedDefaults.container?.set(Date.now, forKey: SharedDefaults.Keys.debugMonitorLastThresholdTime)
        WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
        logger.info("💾 Saved \(seconds)s (\(minutes)min)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.info("🔚 intervalDidEnd — activity: \(activity.rawValue)")
    }
}
