import Foundation

enum BigOPlayMode: Equatable, Hashable {
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

enum BigOPhase: Equatable {
    case playing
    case revealing
    case finished
}

struct BigOChallenge: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let snippet: String
    let options: [String]
    let answer: String
    let difficulty: String?
    let caseNote: String?
    let explanation: String
    let hint: String?
    let reference: String
    let learnMoreURL: String?

    func shuffledOptions() -> [String] {
        options.shuffled()
    }
}

struct BigORound: Equatable {
    let challenge: BigOChallenge
    let displayOptions: [String]

    var correctAnswer: String { challenge.answer }
}

enum BigOSchedule {
    static var nextPuzzleAt: Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? .now
    }

    static func remainingInterval(from date: Date = .now) -> TimeInterval {
        max(0, nextPuzzleAt.timeIntervalSince(date))
    }

    static func formattedRemaining(from date: Date = .now) -> String {
        let total = Int(remainingInterval(from: date))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func dayIndex(for date: Date = .now) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let today = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: today).day ?? 0
    }
}

struct BigODailyDictionary {
    let challenges: [BigOChallenge]

    static let shared: BigODailyDictionary = {
        if let loaded = loadFromBundle(resource: "big_o_daily") {
            return loaded
        }
        return fallback
    }()

    func challenge(for date: Date = .now) -> BigOChallenge? {
        guard !challenges.isEmpty else { return nil }
        let index = abs(BigOSchedule.dayIndex(for: date)) % challenges.count
        return challenges[index]
    }

    private static func loadFromBundle(resource: String) -> BigODailyDictionary? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.challenges.isEmpty else {
            return nil
        }
        return BigODailyDictionary(challenges: payload.challenges)
    }

    private static let fallback = BigODailyDictionary(
        challenges: [
            BigOChallenge(
                id: "fallback-linear",
                title: "Busca linear",
                snippet: "function find(arr, target):\n  for i in 0..arr.length:\n    if arr[i] == target:\n      return i",
                options: ["O(1)", "O(n)", "O(n log n)", "O(n²)"],
                answer: "O(n)",
                difficulty: "easy",
                caseNote: "pior caso",
                explanation: "Um loop percorre o array.",
                hint: "Quantas iterações?",
                reference: "https://www.geeksforgeeks.org/dsa/linear-search/",
                learnMoreURL: nil
            )
        ]
    )

    private struct Payload: Decodable {
        let challenges: [BigOChallenge]
    }
}

struct BigOFreeDictionary {
    let challenges: [BigOChallenge]

    static let shared: BigOFreeDictionary = {
        if let loaded = loadFromBundle(resource: "big_o_free") {
            return loaded
        }
        return fallback
    }()

    func makeRound(excluding usedIDs: Set<String> = []) -> BigORound? {
        let pool = challenges.filter { !usedIDs.contains($0.id) }
        guard let challenge = (pool.isEmpty ? challenges.randomElement() : pool.randomElement()) else {
            return nil
        }
        return BigORound(challenge: challenge, displayOptions: challenge.shuffledOptions())
    }

    private static func loadFromBundle(resource: String) -> BigOFreeDictionary? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.challenges.isEmpty else {
            return nil
        }
        return BigOFreeDictionary(challenges: payload.challenges)
    }

    private static let fallback = BigOFreeDictionary(challenges: [])

    private struct Payload: Decodable {
        let challenges: [BigOChallenge]
    }
}

enum BigOEngine {
    static let freeTotalRounds = 10
    static let revealDurationMs = 2_500

    static func isCorrect(round: BigORound, selected: String) -> Bool {
        selected == round.correctAnswer
    }

    static func dateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct BigODailySummary {
    let played: Bool
    let won: Bool
    let currentStreak: Int
}

struct BigOSavedState: Codable, Equatable {
    let challengeID: String
    let selectedAnswer: String?
    let wasCorrect: Bool
    let finished: Bool
}

@MainActor
final class BigOStorage {
    static let shared = BigOStorage()

    private enum Keys {
        static let currentStreak = "bigOCurrentStreak"
        static let maxStreak = "bigOMaxStreak"
        static let lastPlayedDate = "bigOLastPlayedDate"
    }

    private init() {}

    func loadState(for dateKey: String) -> BigOSavedState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(dateKey)) else { return nil }
        return try? JSONDecoder().decode(BigOSavedState.self, from: data)
    }

    func saveState(_ state: BigOSavedState, for dateKey: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey(dateKey))
    }

    func summary(for dateKey: String) -> BigODailySummary {
        let state = loadState(for: dateKey)
        return BigODailySummary(
            played: state?.finished == true,
            won: state?.wasCorrect == true,
            currentStreak: UserDefaults.standard.integer(forKey: Keys.currentStreak)
        )
    }

    func recordResult(correct: Bool, dateKey: String) {
        updateStreak(for: dateKey, won: correct)
    }

    private func updateStreak(for dateKey: String, won: Bool) {
        let defaults = UserDefaults.standard
        let lastPlayed = defaults.string(forKey: Keys.lastPlayedDate)
        var streak = defaults.integer(forKey: Keys.currentStreak)

        if won {
            if isYesterday(lastPlayed, comparedTo: dateKey) || lastPlayed == nil {
                streak += 1
            } else if lastPlayed != dateKey {
                streak = 1
            }
        } else {
            streak = 0
        }

        defaults.set(streak, forKey: Keys.currentStreak)
        defaults.set(max(streak, defaults.integer(forKey: Keys.maxStreak)), forKey: Keys.maxStreak)
        defaults.set(dateKey, forKey: Keys.lastPlayedDate)
    }

    private func isYesterday(_ previousDateKey: String?, comparedTo todayKey: String) -> Bool {
        guard let previousDateKey,
              let previous = date(from: previousDateKey),
              let today = date(from: todayKey) else { return false }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return false }
        return Calendar.current.isDate(previous, inSameDayAs: yesterday)
    }

    private func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    private func stateKey(_ dateKey: String) -> String {
        "bigO_state_\(dateKey)"
    }
}
