import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let dailySeconds: TimeInterval
    let translations: [ActivityTranslation]
    let isSampleData: Bool

    static var sample: WidgetEntry {
        let seconds = ScreenTimeSummary.sample.dailySeconds
        let samplePreferences = UserPreferences(
            selectedActivityIDs: ["gym", "read_chapter", "run_5k"],
            customActivities: []
        )
        return WidgetEntry(
            date: .now,
            dailySeconds: seconds,
            translations: ActivityDatabase.translations(for: seconds, timeframe: .day, preferences: samplePreferences),
            isSampleData: true
        )
    }
}

struct TimeWastedProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> WidgetEntry {
        let daily = SharedDefaults.loadDailySeconds()
        let hasSavedData = SharedDefaults.hasDailyData(inLastDays: 1)

        let seconds = hasSavedData ? daily : 0
        let preferences = SharedDefaults.loadUserPreferences()
        let translations = ActivityDatabase.translations(for: seconds, timeframe: .day, preferences: preferences)

        return WidgetEntry(
            date: .now,
            dailySeconds: seconds,
            translations: translations,
            isSampleData: false
        )
    }
}

struct TimeWastedWidget: Widget {
    let kind = "TimeWastedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeWastedProvider()) { entry in
            TimeWastedWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Wasted")
        .description("Veja quanto tempo você gasta nas redes sociais.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
