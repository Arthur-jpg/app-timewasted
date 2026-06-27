import Foundation

struct ScreenTimeSummary {
    var dailySeconds: TimeInterval
    var weeklySeconds: TimeInterval
    var monthlySeconds: TimeInterval
    var yearlySeconds: TimeInterval
    var lastUpdated: Date
    var isSampleData: Bool

    static let sample = ScreenTimeSummary(
        dailySeconds: 7620,      // 2h 7min
        weeklySeconds: 53340,    // ~8.9h
        monthlySeconds: 228600,  // ~63.5h
        yearlySeconds: 2781900,  // ~773h
        lastUpdated: .now,
        isSampleData: true
    )

    static let empty = ScreenTimeSummary(
        dailySeconds: 0, weeklySeconds: 0,
        monthlySeconds: 0, yearlySeconds: 0,
        lastUpdated: .now, isSampleData: false
    )
}

enum TimeFrame: String, CaseIterable, Identifiable {
    case day = "Hoje"
    case week = "Semana"
    case month = "Mês"
    case year = "Ano"

    var id: String { rawValue }

    var seconds: (ScreenTimeSummary) -> TimeInterval {
        switch self {
        case .day: { $0.dailySeconds }
        case .week: { $0.weeklySeconds }
        case .month: { $0.monthlySeconds }
        case .year: { $0.yearlySeconds }
        }
    }

    var systemImage: String {
        switch self {
        case .day: "sun.max.fill"
        case .week: "calendar.badge.clock"
        case .month: "calendar"
        case .year: "star.fill"
        }
    }
}

struct Activity: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let durationMinutes: Double
    let category: ActivityCategory
    let detail: String
}

enum ActivityCategory: String, CaseIterable, Codable {
    case fitness = "Fitness"
    case education = "Educação"
    case productivity = "Produtividade"
    case wellbeing = "Bem-estar"
    case skill = "Habilidade"
    case lifestyle = "Estilo de vida"
}

struct ActivityPrediction: Identifiable {
    var id: String { "\(name)_\(period)" }
    let name: String
    let emoji: String
    let projectedCount: Double
    let period: String  // "mês" or "ano"
    var isCustom: Bool = false

    var headline: String {
        "\(emoji) \(name)\(compactCountSuffix(for: projectedCount))"
    }

    var subtitle: String {
        "No ritmo atual, daria para \(spokenCount(for: projectedCount)) este \(period)"
    }
}

struct ActivityTranslation: Identifiable {
    var id: String { "\(activity.id)_\(count)" }
    let activity: Activity
    let count: Int
    let exactCount: Double
    let timeframe: TimeFrame

    var isPartial: Bool { exactCount < 1 }

    var completionPercentage: Int {
        guard exactCount > 0 else { return 0 }
        return min(99, max(1, Int((exactCount * 100).rounded())))
    }

    var badgeText: String {
        isPartial ? "\(completionPercentage)%" : "×\(count)"
    }

    var metricValueText: String {
        if isPartial { return "\(completionPercentage)%" }
        return compactCountSuffix(for: exactCount)
            .trimmingCharacters(in: .whitespaces)
    }

    var headline: String {
        if isPartial {
            return "\(activity.emoji) \(activity.name) — \(completionPercentage)%"
        }
        return "\(activity.emoji) \(activity.name)\(countSuffix)"
    }

    private var countSuffix: String {
        compactCountSuffix(for: exactCount, omitSingle: true)
    }

    var subtitle: String {
        if isPartial {
            return "Você completaria \(completionPercentage)% dessa atividade \(partialPeriodText)"
        }

        let countText = spokenCount(for: exactCount)
        let isSingle = exactCount < 1.15

        switch timeframe {
        case .day:
            if isSingle { return "no lugar das redes sociais de hoje" }
            return "\(countText) no lugar das redes sociais de hoje"
        case .week:
            if abs(exactCount - 7) < 0.15 { return "todos os dias da semana" }
            return "\(countText) esta semana"
        case .month:
            return "\(countText) este mês"
        case .year:
            return "\(countText) este ano"
        }
    }

    private var partialPeriodText: String {
        switch timeframe {
        case .day: "com o tempo de hoje"
        case .week: "com o tempo desta semana"
        case .month: "com o tempo deste mês"
        case .year: "com o tempo deste ano"
        }
    }
}

private func countDescription(for exactCount: Double) -> (compact: String, spoken: String) {
    let whole = max(1, Int(exactCount.rounded(.down)))
    let fraction = exactCount - Double(whole)

    switch fraction {
    case ..<0.15:
        return ("\(whole)×", whole == 1 ? "1 vez" : "\(whole) vezes")
    case ..<0.4:
        return ("mais de \(whole)×", "mais de \(whole) vezes")
    case ..<0.65:
        return ("\(whole)× e meia", "\(whole) vezes e meia")
    case ..<0.9:
        return ("quase \(whole + 1)×", "quase \(whole + 1) vezes")
    default:
        return ("\(whole + 1)×", "\(whole + 1) vezes")
    }
}

func compactCountSuffix(for exactCount: Double, omitSingle: Bool = false) -> String {
    let description = countDescription(for: exactCount).compact
    if omitSingle && exactCount < 1.15 { return "" }
    return " \(description)"
}

func spokenCount(for exactCount: Double) -> String {
    countDescription(for: exactCount).spoken
}

func formatTime(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)min" }
    if hours > 0 { return "\(hours)h" }
    return "\(minutes)min"
}
