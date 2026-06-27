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

enum ActivityCategory: String, CaseIterable {
    case fitness = "Fitness"
    case education = "Educação"
    case productivity = "Produtividade"
    case wellbeing = "Bem-estar"
    case skill = "Habilidade"
    case lifestyle = "Estilo de vida"
}

struct ActivityTranslation: Identifiable {
    var id: String { "\(activity.id)_\(count)" }
    let activity: Activity
    let count: Int
    let timeframe: TimeFrame

    var headline: String {
        count == 1
            ? "\(activity.emoji) \(activity.name)"
            : "\(activity.emoji) \(activity.name) \(count)x"
    }

    var subtitle: String {
        switch (timeframe, count) {
        case (.day, 1): "no lugar das redes sociais de hoje"
        case (.day, _): "\(count) vezes no lugar das redes sociais de hoje"
        case (.week, 7): "todos os dias da semana"
        case (.week, _): "\(count) vezes esta semana"
        case (.month, _): "\(count) vezes este mês"
        case (.year, _): "\(count) vezes este ano"
        }
    }
}

func formatTime(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)min" }
    if hours > 0 { return "\(hours)h" }
    return "\(minutes)min"
}
