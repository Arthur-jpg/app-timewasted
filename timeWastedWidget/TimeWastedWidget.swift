import WidgetKit
import SwiftUI
import AppIntents

enum WidgetTimeframe: String, AppEnum {
    case day
    case week
    case month
    case year

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Período")
    static let caseDisplayRepresentations: [WidgetTimeframe: DisplayRepresentation] = [
        .day: "Hoje",
        .week: "Esta semana",
        .month: "Este mês",
        .year: "Este ano"
    ]

    var timeframe: TimeFrame {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }
}

struct TimeWastedWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configurar Time Wasted"
    static let description = IntentDescription("Escolha o período e o título exibidos no widget.")

    @Parameter(title: "Período", default: .day)
    var timeframe: WidgetTimeframe

    @Parameter(title: "Título", default: "Enquanto você gastava tempo")
    var customTitle: String
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let seconds: TimeInterval
    let timeframe: TimeFrame
    let title: String
    let translations: [ActivityTranslation]
    let isSampleData: Bool

    var periodLabel: String {
        switch timeframe {
        case .day: "hoje"
        case .week: "esta semana"
        case .month: "este mês"
        case .year: "este ano"
        }
    }

    static var sample: WidgetEntry {
        let seconds = ScreenTimeSummary.sample.dailySeconds
        let samplePreferences = UserPreferences(
            selectedActivityIDs: ["gym", "read_chapter", "run_5k"],
            customActivities: []
        )
        return WidgetEntry(
            date: .now,
            seconds: seconds,
            timeframe: .day,
            title: "Enquanto você gastava tempo",
            translations: ActivityDatabase.translations(for: seconds, timeframe: .day, preferences: samplePreferences),
            isSampleData: true
        )
    }
}

struct TimeWastedProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .sample
    }

    func snapshot(for configuration: TimeWastedWidgetIntent, in context: Context) async -> WidgetEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: TimeWastedWidgetIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let entry = makeEntry(configuration: configuration)
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func makeEntry(configuration: TimeWastedWidgetIntent) -> WidgetEntry {
        let timeframe = configuration.timeframe.timeframe
        let seconds = SharedDefaults.loadSeconds(for: timeframe)
        let preferences = SharedDefaults.loadUserPreferences()
        let translations = ActivityDatabase.translations(for: seconds, timeframe: timeframe, preferences: preferences)
        let configuredTitle = configuration.customTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return WidgetEntry(
            date: .now,
            seconds: seconds,
            timeframe: timeframe,
            title: configuredTitle.isEmpty ? "Enquanto você gastava tempo" : configuredTitle,
            translations: translations,
            isSampleData: false
        )
    }
}

struct TimeWastedWidget: Widget {
    let kind = "TimeWastedWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TimeWastedWidgetIntent.self, provider: TimeWastedProvider()) { entry in
            TimeWastedWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Wasted")
        .description("Veja quanto tempo você gasta nas redes sociais.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
