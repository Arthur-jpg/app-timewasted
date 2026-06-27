import SwiftUI
import WidgetKit

struct TimeWastedWidgetView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ENQUANTO VOCÊ GASTAVA TEMPO...")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.3)

            if let first = entry.translations.first {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(first.activity.emoji)
                        .font(.title2)
                    Text(first.metricValueText)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.tint)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }

                Text(first.activity.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            } else {
                Text("Escolha o que esse tempo poderia virar.")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            Text("≈ \(formatTime(entry.dailySeconds)) nas redes hoje")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Enquanto você gastava tempo")
                    .font(.headline.weight(.bold))

                Spacer(minLength: 8)

                Text("≈ \(formatTime(entry.dailySeconds)) hoje")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if entry.isSampleData {
                    Text("Exemplo")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
            }

            if entry.translations.isEmpty {
                Text("Configure no app as atividades que poderiam substituir esse tempo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.translations.prefix(3)) { translation in
                    HStack(spacing: 9) {
                        Text(translation.activity.emoji)
                            .font(.title3)
                            .frame(width: 26)

                        Text(translation.activity.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Spacer(minLength: 6)

                        Text(translation.metricValueText)
                            .font(.system(.title3, design: .rounded, weight: .black))
                            .foregroundStyle(.tint)
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.accentColor.opacity(0.09))
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
    }
}

#Preview(as: .systemMedium) {
    TimeWastedWidget()
} timeline: {
    WidgetEntry.sample
}
