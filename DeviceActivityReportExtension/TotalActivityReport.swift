import _DeviceActivity_SwiftUI
import DeviceActivity
import SwiftUI

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

    private var translations: [ActivityTranslation] {
        ActivityDatabase.translations(for: totalSeconds, timeframe: timeframe)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(formatTime(totalSeconds))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

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
                )

                if !translations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Você poderia ter feito", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(translations) { translation in
                            HStack(spacing: 12) {
                                Text(translation.activity.emoji)
                                    .font(.title)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.accentColor.opacity(0.12))
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
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
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
