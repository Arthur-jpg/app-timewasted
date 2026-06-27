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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⏱️")
                    .font(.caption)
                Text("hoje")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text("≈ \(formatTime(entry.dailySeconds))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("estimativa nas redes sociais")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider()

            if let first = entry.translations.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Em vez disso:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(first.activity.emoji) \(first.activity.name)" + (first.count > 1 ? " ×\(first.count)" : ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: time display
            VStack(alignment: .leading, spacing: 6) {
                Label("Hoje", systemImage: "clock.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text("≈ \(formatTime(entry.dailySeconds))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("estimativa nas redes sociais")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if entry.isSampleData {
                    Text("Exemplo")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)

            Divider()
                .padding(.vertical, 14)

            // Right: alternatives
            VStack(alignment: .leading, spacing: 6) {
                Text("Poderia ter feito")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(entry.translations.prefix(3)) { translation in
                    HStack(spacing: 6) {
                        Text(translation.activity.emoji)
                            .font(.caption)
                        Text(translation.activity.name + (translation.count > 1 ? " ×\(translation.count)" : ""))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
        }
    }
}

#Preview(as: .systemMedium) {
    TimeWastedWidget()
} timeline: {
    WidgetEntry.sample
}
