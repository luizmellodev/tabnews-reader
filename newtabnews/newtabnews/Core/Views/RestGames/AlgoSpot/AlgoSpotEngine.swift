import Foundation

enum AlgoSpotPlayMode: Equatable, Hashable, RestGamePlayMode {
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

enum AlgoSpotPhase: Equatable {
    case playing
    case revealing
    case finished
}

struct AlgoSpotChallenge: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let snippet: String
    let options: [String]
    let answer: String
    let difficulty: String?
    let category: String?
    let caseNote: String?
    let whatItIs: String
    let explanation: String
    let hint: String?
    let reference: String
    let learnMoreURL: String?

    func shuffledOptions() -> [String] {
        options.shuffled()
    }

    var displaySnippet: String {
        Self.stripFunctionDeclaration(from: snippet)
    }

    static func stripFunctionDeclaration(from snippet: String) -> String {
        let lines = snippet.components(separatedBy: "\n")
        guard let first = lines.first,
              first.range(of: #"^function\s+\w+\s*\("#, options: .regularExpression) != nil else {
            return snippet
        }
        return lines.dropFirst().joined(separator: "\n")
    }
}

struct AlgoSpotRound: Equatable {
    let challenge: AlgoSpotChallenge
    let displayOptions: [String]

    var correctAnswer: String { challenge.answer }
}

enum AlgoSpotSchedule {
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

struct AlgoSpotDailyDictionary {
    let challenges: [AlgoSpotChallenge]

    static let shared: AlgoSpotDailyDictionary = {
        if let loaded = loadFromBundle(resource: "algo_spot_daily") {
            return loaded
        }
        return fallback
    }()

    func challenge(for date: Date = .now) -> AlgoSpotChallenge? {
        guard !challenges.isEmpty else { return nil }
        let index = abs(AlgoSpotSchedule.dayIndex(for: date)) % challenges.count
        return challenges[index]
    }

    private static func loadFromBundle(resource: String) -> AlgoSpotDailyDictionary? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.challenges.isEmpty else {
            return nil
        }
        return AlgoSpotDailyDictionary(challenges: payload.challenges)
    }

    private static let fallback = AlgoSpotDailyDictionary(
        challenges: [
            AlgoSpotChallenge(
                id: "fallback-linear",
                title: "Busca linear",
                snippet: "function find(arr, target):\n  for i in 0..arr.length:\n    if arr[i] == target:\n      return i\n  return -1",
                options: ["Busca linear", "Busca binária", "Busca ternária", "DFS"],
                answer: "Busca linear",
                difficulty: "easy",
                category: "busca",
                caseNote: "O(n)",
                whatItIs: "Algoritmo de busca que percorre o array elemento a elemento até encontrar o alvo.",
                explanation: "Percorre o array elemento a elemento até encontrar o alvo.",
                hint: "Um loop do início ao fim.",
                reference: "https://www.geeksforgeeks.org/dsa/linear-search/",
                learnMoreURL: nil
            )
        ]
    )

    private struct Payload: Decodable {
        let challenges: [AlgoSpotChallenge]
    }
}

struct AlgoSpotFreeDictionary {
    let challenges: [AlgoSpotChallenge]

    static let shared: AlgoSpotFreeDictionary = {
        if let loaded = loadFromBundle(resource: "algo_spot_free") {
            return loaded
        }
        return fallback
    }()

    func makeRound(excluding usedIDs: Set<String> = []) -> AlgoSpotRound? {
        let pool = challenges.filter { !usedIDs.contains($0.id) }
        guard let challenge = (pool.isEmpty ? challenges.randomElement() : pool.randomElement()) else {
            return nil
        }
        return AlgoSpotRound(challenge: challenge, displayOptions: challenge.shuffledOptions())
    }

    private static func loadFromBundle(resource: String) -> AlgoSpotFreeDictionary? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.challenges.isEmpty else {
            return nil
        }
        return AlgoSpotFreeDictionary(challenges: payload.challenges)
    }

    private static let fallback = AlgoSpotFreeDictionary(challenges: [])

    private struct Payload: Decodable {
        let challenges: [AlgoSpotChallenge]
    }
}

enum AlgoSpotEngine {
    static let freeTotalRounds = 10

    static func isCorrect(round: AlgoSpotRound, selected: String) -> Bool {
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

struct AlgoSpotDailySummary {
    let played: Bool
    let won: Bool
    let currentStreak: Int
}

struct AlgoSpotSavedState: Codable, Equatable {
    let challengeID: String
    let selectedAnswer: String?
    let wasCorrect: Bool
    let finished: Bool
}

@MainActor
final class AlgoSpotStorage {
    static let shared = AlgoSpotStorage()

    private enum Keys {
        static let currentStreak = "algoSpotCurrentStreak"
        static let maxStreak = "algoSpotMaxStreak"
        static let lastPlayedDate = "algoSpotLastPlayedDate"
    }

    private init() {}

    func loadState(for dateKey: String) -> AlgoSpotSavedState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(dateKey)) else { return nil }
        return try? JSONDecoder().decode(AlgoSpotSavedState.self, from: data)
    }

    func saveState(_ state: AlgoSpotSavedState, for dateKey: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey(dateKey))
    }

    func summary(for dateKey: String) -> AlgoSpotDailySummary {
        let state = loadState(for: dateKey)
        return AlgoSpotDailySummary(
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
        "algoSpot_state_\(dateKey)"
    }
}
