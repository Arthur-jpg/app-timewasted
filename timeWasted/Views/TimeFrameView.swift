import SwiftUI

struct TimeFrameView: View {
    let timeframe: TimeFrame
    let summary: ScreenTimeSummary

    private var seconds: TimeInterval { timeframe.seconds(summary) }

    private var lastUpdatedText: String {
        let elapsed = Date.now.timeIntervalSince(summary.lastUpdated)
        switch elapsed {
        case ..<60:
            return "agora mesmo"
        case ..<3600:
            let minutes = Int(elapsed / 60)
            return "há \(minutes) min"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "às \(formatter.string(from: summary.lastUpdated))"
        }
    }

    private var translations: [ActivityTranslation] {
        ActivityDatabase.translations(for: seconds, timeframe: timeframe)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                timeDisplay
                if !translations.isEmpty {
                    alternativesSection
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    private var timeDisplay: some View {
        VStack(spacing: 8) {
            Text(formatTime(seconds))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text("nas redes sociais \(periodLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if summary.isSampleData {
                Label("Dados de exemplo — configure o Screen Time", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            } else {
                Label("Atualizado \(lastUpdatedText)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
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

    private var periodLabel: String {
        switch timeframe {
        case .day: "hoje"
        case .week: "esta semana"
        case .month: "este mês"
        case .year: "este ano (estimativa)"
        }
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Você poderia ter feito", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(translations) { translation in
                ActivityCardView(translation: translation)
            }
        }
    }
}
