import Foundation

enum ActivityDatabase {
    static let all: [Activity] = [
        Activity(id: "meditate", name: "Meditar", emoji: "🧘", durationMinutes: 15, category: .wellbeing, detail: "Sessão de meditação guiada"),
        Activity(id: "journal", name: "Escrever no diário", emoji: "📔", durationMinutes: 15, category: .wellbeing, detail: "Reflexão e gratidão"),
        Activity(id: "stretch", name: "Alongamento completo", emoji: "🤸", durationMinutes: 15, category: .fitness, detail: "Rotina de flexibilidade"),
        Activity(id: "read_chapter", name: "Ler um capítulo", emoji: "📚", durationMinutes: 20, category: .education, detail: "De um livro de desenvolvimento"),
        Activity(id: "hiit", name: "Treino HIIT", emoji: "🔥", durationMinutes: 25, category: .fitness, detail: "Alta intensidade, sem equipamento"),
        Activity(id: "run_5k", name: "Correr 5km", emoji: "🏃", durationMinutes: 30, category: .fitness, detail: "Ritmo confortável de corrida"),
        Activity(id: "podcast", name: "Episódio de podcast", emoji: "🎧", durationMinutes: 30, category: .education, detail: "Educativo ou inspirador"),
        Activity(id: "language", name: "Aula de idioma", emoji: "🌍", durationMinutes: 30, category: .skill, detail: "Espanhol, francês ou japonês"),
        Activity(id: "music", name: "Praticar instrumento", emoji: "🎸", durationMinutes: 30, category: .skill, detail: "Guitarra, piano ou violão"),
        Activity(id: "cook", name: "Cozinhar uma refeição", emoji: "🥗", durationMinutes: 45, category: .lifestyle, detail: "Refeição saudável do zero"),
        Activity(id: "swim", name: "Nadar", emoji: "🏊", durationMinutes: 45, category: .fitness, detail: "Natação livre ou técnica"),
        Activity(id: "calculus", name: "Aula de Cálculo 1", emoji: "📐", durationMinutes: 50, category: .education, detail: "Derivadas, integrais e mais"),
        Activity(id: "gym", name: "Treino na academia", emoji: "💪", durationMinutes: 60, category: .fitness, detail: "Musculação ou cardio completo"),
        Activity(id: "english", name: "Aula de inglês", emoji: "🗣️", durationMinutes: 60, category: .skill, detail: "Conversação ou gramática"),
        Activity(id: "yoga", name: "Aula de yoga", emoji: "🧘‍♂️", durationMinutes: 60, category: .fitness, detail: "Yoga flow completo"),
        Activity(id: "code", name: "Sessão de programação", emoji: "💻", durationMinutes: 60, category: .productivity, detail: "Feature ou exercício prático"),
        Activity(id: "bike", name: "Andar de bicicleta", emoji: "🚴", durationMinutes: 60, category: .fitness, detail: "Ciclismo urbano ou trilha"),
        Activity(id: "course_module", name: "Módulo de curso online", emoji: "🎓", durationMinutes: 90, category: .education, detail: "Udemy, Coursera ou YouTube"),
        Activity(id: "hike", name: "Trilha na natureza", emoji: "🌲", durationMinutes: 90, category: .fitness, detail: "Caminhada ao ar livre"),
        Activity(id: "portfolio", name: "Projeto de portfólio", emoji: "⌨️", durationMinutes: 120, category: .productivity, detail: "Construção de projeto real"),
        Activity(id: "read_book", name: "Ler um livro inteiro", emoji: "📖", durationMinutes: 300, category: .education, detail: "Desenvolvimento pessoal"),
        Activity(id: "study_day", name: "Dia de estudo intensivo", emoji: "🎯", durationMinutes: 240, category: .education, detail: "4 horas focadas de estudo"),
    ]

    static func translations(
        for seconds: TimeInterval,
        timeframe: TimeFrame,
        preferences: UserPreferences = .default
    ) -> [ActivityTranslation] {
        let minutes = seconds / 60
        let pool = activityPool(for: preferences)
        let allResults = pool.map { activity in
            let exactCount = minutes / activity.durationMinutes
            let count = Int(exactCount)
            return ActivityTranslation(
                activity: activity,
                count: count,
                exactCount: exactCount,
                timeframe: timeframe
            )
        }

        // Explicitly selected comparisons should never disappear just because
        // the observed period is shorter than the activity or produces a high
        // count. Partial activities are represented as a completion percentage.
        if preferences.hasAnyPreferences {
            return allResults
        }

        guard minutes >= 1 else { return [] }

        var results: [ActivityTranslation] = []

        for translation in allResults {
            let count = translation.count
            guard count >= 1 else { continue }

            let isRelevant: Bool
            switch timeframe {
            case .day: isRelevant = count <= 10
            case .week: isRelevant = count <= 50
            case .month: isRelevant = count <= 200
            case .year: isRelevant = count >= 3
            }
            guard isRelevant else { continue }
            results.append(translation)
        }

        // Default: pick 3 from different categories for variety
        var picked: [ActivityTranslation] = []
        var usedCategories = Set<ActivityCategory>()
        let targetCount = timeframe == .day ? 2 : timeframe == .week ? 5 : 10
        let sorted = results.sorted { abs($0.count - targetCount) < abs($1.count - targetCount) }

        for translation in sorted {
            if !usedCategories.contains(translation.activity.category) {
                picked.append(translation)
                usedCategories.insert(translation.activity.category)
            }
            if picked.count == 3 { break }
        }

        if picked.count < 3 {
            for translation in sorted where !picked.contains(where: { $0.activity.id == translation.activity.id }) {
                picked.append(translation)
                if picked.count == 3 { break }
            }
        }

        return picked
    }

    static func predictions(
        for observedSeconds: TimeInterval,
        timeframe: TimeFrame,
        preferences: UserPreferences = .default
    ) -> [ActivityPrediction] {
        guard observedSeconds > 60 else { return [] }

        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
        let dayOfMonth = max(1, calendar.component(.day, from: .now))
        let dayOfYear = max(1, calendar.ordinality(of: .day, in: .year, for: .now) ?? 1)
        let weekday = calendar.component(.weekday, from: .now)
        let elapsedWeekDays = ((weekday - calendar.firstWeekday + 7) % 7) + 1

        let projection: TimeInterval
        let period: String
        switch timeframe {
        case .day:
            projection = observedSeconds * Double(daysInMonth)
            period = "mês"
        case .week:
            projection = observedSeconds / Double(elapsedWeekDays) * Double(daysInMonth)
            period = "mês"
        case .month:
            projection = observedSeconds / Double(dayOfMonth) * Double(daysInMonth)
            period = "mês"
        case .year:
            let daysInYear = calendar.range(of: .day, in: .year, for: .now)?.count ?? 365
            projection = observedSeconds / Double(dayOfYear) * Double(daysInYear)
            period = "ano"
        }

        let pool = activityPool(for: preferences)
        let customIDs = Set(preferences.customActivities.map { "custom_\($0.id.uuidString)" })

        var preds: [ActivityPrediction] = []

        for activity in pool {
            let activitySeconds = activity.durationMinutes * 60
            let projectedCount = projection / activitySeconds

            let upperLimit = period == "mês" ? 20.0 : 60.0
            if projectedCount >= 1 && projectedCount <= upperLimit {
                preds.append(ActivityPrediction(
                    name: activity.name,
                    emoji: activity.emoji,
                    projectedCount: projectedCount,
                    period: period,
                    isCustom: customIDs.contains(activity.id)
                ))
            }
        }

        // Custom activities first, then by most "relatable" count
        let sorted = preds.sorted { a, b in
            if a.isCustom != b.isCustom { return a.isCustom }
            return abs(a.projectedCount - 5) < abs(b.projectedCount - 5)
        }
        return Array(sorted.prefix(2))
    }

    private static func activityPool(for preferences: UserPreferences) -> [Activity] {
        guard preferences.hasAnyPreferences else { return [] }

        let selectedBuiltIn = all.filter { preferences.selectedActivityIDs.contains($0.id) }
        let customActivities = preferences.customActivities.map { $0.toActivity() }

        return selectedBuiltIn + customActivities
    }
}
