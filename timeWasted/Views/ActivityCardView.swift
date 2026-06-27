import SwiftUI

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

struct ActivityCardView: View {
    let translation: ActivityTranslation
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text(translation.activity.emoji)
                .font(compact ? .title2 : .title)
                .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(translation.activity.category.color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(translation.activity.name)
                        .font(compact ? .subheadline : .body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if translation.isPartial || translation.count > 1 {
                        Text(translation.badgeText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(translation.activity.category.color.opacity(0.2))
                            )
                            .foregroundStyle(translation.activity.category.color)
                    }
                }

                Text(translation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(compact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
    }
}
