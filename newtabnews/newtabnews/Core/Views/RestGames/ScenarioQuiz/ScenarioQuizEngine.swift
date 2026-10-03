import SwiftUI

/// Base compartilhada dos jogos "situação + 4 opções" (HTTP Status, Git Rescue).
/// Mesma mecânica do Big O: 1 desafio diário e modo livre de 10 rounds, mas com conteúdo
/// e visual definidos por `ScenarioQuizConfig`.

enum ScenarioQuizPlayMode: Equatable, Hashable, RestGamePlayMode {
    case daily
    case free

    var title: String {
        switch self {
        case .daily: return "Diário"
        case .free: return "Livre"
        }
    }

    var iconName: String {
        switch self {
        case .daily: return "calendar"
        case .free: return "infinity"
        }
    }
}

enum ScenarioQuizPhase: Equatable {
    case playing
    case revealing
    case finished
}

struct ScenarioQuizChallenge: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let scenario: String
    let context: String?
    let options: [String]
    let answer: String
    let difficulty: String?
    let explanation: String
    let hint: String?
    let reference: String
}

struct ScenarioQuizRound: Equatable {
    let challenge: ScenarioQuizChallenge
    let displayOptions: [String]

    var correctAnswer: String { challenge.answer }
}

struct ScenarioQuizIntroRow: Hashable {
    let term: String
    let detail: String
}

struct ScenarioQuizConfig {
    /// Prefixo das chaves de UserDefaults (não mudar depois de publicado: perde o progresso)
    let storagePrefix: String
    let title: String
    let icon: String
    let accent: Color
    let accentLight: Color
    let question: String
    let dailyResource: String
    let freeResource: String
    /// Comandos longos (git) ficam em lista; códigos curtos (HTTP) em grade 2x2
    let optionsInSingleColumn: Bool
    let monospacedOptions: Bool
    let leaderboard: RestGameLeaderboard
    let onboardingID: RestGameOnboardingID
    let onboardingSteps: [String]
    let introText: String
    let introRows: [ScenarioQuizIntroRow]
    let introFootnote: String
    let learnMoreTitle: String
    let learnMoreURL: URL
    let perfectMessage: String
    let goodMessage: String
    let okMessage: String
    let lowMessage: String

    var onboardingOverlay: (@escaping () -> Void) -> RestGameOnboardingOverlay {
        { onPlay in
            RestGameOnboardingOverlay(
                title: title,
                icon: icon,
                accent: accent,
                steps: onboardingSteps,
                onPlay: onPlay
            )
        }
    }
}

enum ScenarioQuizEngine {
    static let freeTotalRounds = 10

    static func dateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Content

struct ScenarioQuizDictionary {
    let challenges: [ScenarioQuizChallenge]

    private static var cache: [String: ScenarioQuizDictionary] = [:]

    static func load(resource: String) -> ScenarioQuizDictionary {
        if let cached = cache[resource] { return cached }

        var challenges: [ScenarioQuizChallenge] = []
        if let url = Bundle.main.url(forResource: resource, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            challenges = payload.challenges
        }

        let dictionary = ScenarioQuizDictionary(challenges: challenges)
        cache[resource] = dictionary
        return dictionary
    }

    /// Mesmo desafio para todo mundo no mesmo dia (índice pelo dia, como no Big O)
    func dailyChallenge(for date: Date = .now) -> ScenarioQuizChallenge? {
        guard !challenges.isEmpty else { return nil }
        let index = abs(BigOSchedule.dayIndex(for: date)) % challenges.count
        return challenges[index]
    }

    func makeRound(excluding usedIDs: Set<String>) -> ScenarioQuizRound? {
        let pool = challenges.filter { !usedIDs.contains($0.id) }
        guard let challenge = (pool.isEmpty ? challenges.randomElement() : pool.randomElement()) else {
            return nil
        }
        return ScenarioQuizRound(challenge: challenge, displayOptions: challenge.options.shuffled())
    }

    private struct Payload: Decodable {
        let challenges: [ScenarioQuizChallenge]
    }
}

// MARK: - Storage

struct ScenarioQuizDailySummary {
    let played: Bool
    let won: Bool
    let currentStreak: Int
}

struct ScenarioQuizSavedState: Codable, Equatable {
    let challengeID: String
    let selectedAnswer: String?
    let wasCorrect: Bool
    let finished: Bool
}

@MainActor
struct ScenarioQuizStorage {
    let prefix: String

    private var currentStreakKey: String { "\(prefix)CurrentStreak" }
    private var maxStreakKey: String { "\(prefix)MaxStreak" }
    private var lastPlayedKey: String { "\(prefix)LastPlayedDate" }

    func loadState(for dateKey: String) -> ScenarioQuizSavedState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(dateKey)) else { return nil }
        return try? JSONDecoder().decode(ScenarioQuizSavedState.self, from: data)
    }

    func saveState(_ state: ScenarioQuizSavedState, for dateKey: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey(dateKey))
    }

    func summary(for dateKey: String) -> ScenarioQuizDailySummary {
        let state = loadState(for: dateKey)
        return ScenarioQuizDailySummary(
            played: state?.finished == true,
            won: state?.wasCorrect == true,
            currentStreak: UserDefaults.standard.integer(forKey: currentStreakKey)
        )
    }

    func recordResult(correct: Bool, dateKey: String) {
        let defaults = UserDefaults.standard
        let lastPlayed = defaults.string(forKey: lastPlayedKey)
        var streak = defaults.integer(forKey: currentStreakKey)

        if correct {
            if lastPlayed == nil || isDay(lastPlayed, before: dateKey) {
                streak += 1
            } else if lastPlayed != dateKey {
                streak = 1
            }
        } else {
            streak = 0
        }

        defaults.set(streak, forKey: currentStreakKey)
        defaults.set(max(streak, defaults.integer(forKey: maxStreakKey)), forKey: maxStreakKey)
        defaults.set(dateKey, forKey: lastPlayedKey)
    }

    private func isDay(_ previousKey: String?, before todayKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let previousKey,
              let previous = formatter.date(from: previousKey),
              let today = formatter.date(from: todayKey),
              let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return false }
        return Calendar.current.isDate(previous, inSameDayAs: yesterday)
    }

    private func stateKey(_ dateKey: String) -> String {
        "\(prefix)_state_\(dateKey)"
    }
}
