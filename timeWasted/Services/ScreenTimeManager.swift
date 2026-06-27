import Foundation
import FamilyControls
import DeviceActivity
import SwiftUI
import OSLog
import WidgetKit

private let logger = Logger(subsystem: "com.arthurschiller.timeWasteddd", category: "ScreenTimeManager")

// CFNotificationCallback must be @convention(c) (no captures).
// Uses the singleton so no retain cycle occurs.
@MainActor
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    private static let monitorConfigurationVersion = 3

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var activitySelection = FamilyActivitySelection()
    @Published var summary: ScreenTimeSummary = .empty

    private lazy var authCenter = AuthorizationCenter.shared
    private lazy var activityCenter = DeviceActivityCenter()

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    init() {
        loadSelection()
        refreshSummary()
        if !activitySelection.applicationTokens.isEmpty
            || !activitySelection.categoryTokens.isEmpty
            || !activitySelection.webDomainTokens.isEmpty {
            let savedVersion = SharedDefaults.container?.integer(
                forKey: SharedDefaults.Keys.monitorConfigurationVersion
            ) ?? 0
            if savedVersion < Self.monitorConfigurationVersion
                || !activityCenter.activities.contains(.daily) {
                startMonitoring(resetDailyValue: true)
            }
        }
    }

    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationStatus = .authorized
            SharedDefaults.container?.set(true, forKey: SharedDefaults.Keys.isAuthorized)
            logger.info("✅ Screen Time authorization granted")
        } catch {
            authorizationStatus = .denied
            logger.error("❌ Screen Time authorization failed: \(error.localizedDescription)")
        }
    }

    func saveSelection() {
        guard let data = try? JSONEncoder().encode(activitySelection) else {
            logger.error("❌ Failed to encode activitySelection")
            return
        }
        SharedDefaults.container?.set(data, forKey: SharedDefaults.Keys.activitySelection)
        SharedDefaults.container?.set(false, forKey: SharedDefaults.Keys.useSampleData)
        let appCount = activitySelection.applicationTokens.count
        let catCount = activitySelection.categoryTokens.count
        logger.info("💾 Selection saved — apps: \(appCount), categories: \(catCount)")
        startMonitoring(resetDailyValue: true)
    }

    func enableSampleData() {
        SharedDefaults.container?.set(true, forKey: SharedDefaults.Keys.useSampleData)
        summary = .sample
    }

    func loadSelection() {
        guard
            let data = SharedDefaults.container?.data(forKey: SharedDefaults.Keys.activitySelection),
            let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            logger.warning("⚠️ No saved selection found in App Group")
            return
        }
        activitySelection = saved
        logger.info("📂 Selection loaded — apps: \(saved.applicationTokens.count)")
    }

    func startMonitoring(resetDailyValue: Bool = false) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        // Thresholds every 3 minutes up to 10 hours (200 events).
        // 600 events (1/min) exceeded system limits and caused startMonitoring to fail silently.
        let generation = (SharedDefaults.container?.integer(
            forKey: SharedDefaults.Keys.monitorGeneration
        ) ?? 0) + 1
        SharedDefaults.container?.set(generation, forKey: SharedDefaults.Keys.monitorGeneration)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for threshold in stride(from: 3, through: 600, by: 3) {
            let eventName = DeviceActivityEvent.Name("usage.g\(generation).\(threshold)min")
            events[eventName] = DeviceActivityEvent(
                applications: activitySelection.applicationTokens,
                categories: activitySelection.categoryTokens,
                webDomains: activitySelection.webDomainTokens,
                threshold: DateComponents(minute: threshold),
                includesPastActivity: true
            )
        }

        if resetDailyValue {
            SharedDefaults.resetDailySeconds()
            WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
        }

        // Stop first to clear any stale state before restarting
        activityCenter.stopMonitoring([.daily])
        logger.info("🛑 Stopped existing monitoring")
        logger.info("🔍 Starting monitoring with \(events.count) threshold events")

        do {
            try activityCenter.startMonitoring(.daily, during: schedule, events: events)
            SharedDefaults.container?.set(
                Self.monitorConfigurationVersion,
                forKey: SharedDefaults.Keys.monitorConfigurationVersion
            )
            logger.info("✅ Monitoring started successfully")
        } catch {
            logger.error("❌ startMonitoring failed: \(error.localizedDescription) — code: \((error as NSError).code)")
        }
    }

    func refreshSummary() {
        let daily = SharedDefaults.loadDailySeconds()
        let weekly = SharedDefaults.loadWeeklySeconds()
        let monthly = SharedDefaults.loadMonthlySeconds()
        let yearly = SharedDefaults.loadYearlySeconds()

        let useSampleData = SharedDefaults.container?.bool(forKey: SharedDefaults.Keys.useSampleData) ?? false
        let hasSavedData = SharedDefaults.hasDailyData()
        let lastUpdated = SharedDefaults.container?.object(forKey: SharedDefaults.Keys.lastUpdated) as? Date ?? .now

        logger.info("🔄 refreshSummary — daily: \(daily)s, hasSavedData: \(hasSavedData)")

        if useSampleData && !hasSavedData {
            summary = .sample
            return
        }

        summary = ScreenTimeSummary(
            dailySeconds: daily,
            weeklySeconds: weekly,
            monthlySeconds: monthly,
            yearlySeconds: yearly,
            lastUpdated: lastUpdated,
            isSampleData: false
        )
    }
}

extension DeviceActivityName {
    static let daily = DeviceActivityName("daily")
}
