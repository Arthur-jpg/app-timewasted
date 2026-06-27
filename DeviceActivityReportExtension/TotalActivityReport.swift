import _DeviceActivity_SwiftUI
import DeviceActivity
import SwiftUI
import WidgetKit

struct ActivityReportConfiguration {
    let totalSeconds: TimeInterval
    let lastUpdated: Date
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let timeframe: TimeFrame
    var content: (ActivityReportConfiguration) -> ReportTimeFrameView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReportConfiguration {
        var total: TimeInterval = 0
        var lastUpdated = Date.distantPast
        for await userData in data {
            lastUpdated = max(lastUpdated, userData.lastUpdatedDate)
            for await segment in userData.activitySegments {
                // ActivitySegment.totalActivityDuration is the device's total
                // screen-on time. Sum the filtered applications instead.
                for await category in segment.categories {
                    for await application in category.applications {
                        total += application.totalActivityDuration
                    }
                }
            }
        }
        if lastUpdated != .distantPast {
            SharedDefaults.saveReportSeconds(total, for: timeframe)
            WidgetCenter.shared.reloadTimelines(ofKind: "TimeWastedWidget")
        }
        return ActivityReportConfiguration(
            totalSeconds: total,
            lastUpdated: lastUpdated == .distantPast ? .now : lastUpdated
        )
    }
}

struct ReportTimeFrameView: View {
    let configuration: ActivityReportConfiguration
    let timeframe: TimeFrame

    private var totalSeconds: TimeInterval { configuration.totalSeconds }

    private var preferences: UserPreferences {
        SharedDefaults.loadUserPreferences()
    }

    private var translations: [ActivityTranslation] {
        ActivityDatabase.translations(for: totalSeconds, timeframe: timeframe, preferences: preferences)
    }

    private var predictions: [ActivityPrediction] {
        ActivityDatabase.predictions(for: totalSeconds, timeframe: timeframe, preferences: preferences)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                timeDisplay

                if !translations.isEmpty {
                    alternativesSection
                } else if !preferences.hasAnyPreferences {
                    emptyPreferencesPrompt
                }

                if !predictions.isEmpty {
                    predictionsSection
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    private var timeDisplay: some View {
        VStack(spacing: 8) {
            Text(formatTime(totalSeconds))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text("nos apps selecionados \(periodLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("Atualizado \(configuration.lastUpdated.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Você poderia ter feito", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(translations) { translation in
                translationCard(translation)
            }
        }
    }

    private func translationCard(_ translation: ActivityTranslation) -> some View {
        HStack(spacing: 12) {
            Text(translation.activity.emoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(translation.activity.category.color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(translation.headline)
                    .font(.body.weight(.semibold))
                Text(translation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
    }

    private var predictionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Se continuar assim...", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(predictions) { prediction in
                predictionCard(prediction)
            }
        }
    }

    private func predictionCard(_ prediction: ActivityPrediction) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.2), .purple.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Text(prediction.emoji).font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(prediction.headline)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(prediction.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [.indigo.opacity(0.06), .purple.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.indigo.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var emptyPreferencesPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Personalize suas comparações")
                .font(.headline)
            Text("Abra o app e toque em \(Image(systemName: "person.crop.circle")) para escolher atividades.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private var periodLabel: String {
        switch timeframe {
        case .day: "hoje"
        case .week: "esta semana"
        case .month: "este mês"
        case .year: "este ano"
        }
    }
}

extension ActivityCategory {
    var color: Color {
        switch self {
        case .fitness: .red
        case .education: .blue
        case .productivity: .orange
        case .wellbeing: .green
        case .skill: .purple
        case .lifestyle: .yellow
        }
    }
}
