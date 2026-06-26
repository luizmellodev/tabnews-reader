import Foundation

enum DevWordleLetterResult: String, Codable, Equatable {
    case correct
    case present
    case absent
}

struct DevWordleGuessRow: Codable, Equatable {
    var letters: [String?]
    var results: [DevWordleLetterResult?]

    static func empty() -> DevWordleGuessRow {
        DevWordleGuessRow(
            letters: Array(repeating: nil, count: DevWordleEngine.wordLength),
            results: Array(repeating: nil, count: DevWordleEngine.wordLength)
        )
    }
}

enum DevWordleGameStatus: String, Codable, Equatable {
    case playing
    case won
    case lost
}

enum DevWordlePlayMode: Equatable, Hashable, RestGamePlayMode {
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

enum DevWordleEngine {
    static let maxAttempts = 6
    static let wordLength = 5

    static func evaluate(guess: String, target: String) -> [DevWordleLetterResult] {
        let guessChars = Array(guess.uppercased())
        let targetChars = Array(target.uppercased())
        guard guessChars.count == wordLength, targetChars.count == wordLength else { return [] }

        var results = Array(repeating: DevWordleLetterResult.absent, count: wordLength)
        var remaining = targetChars

        for index in 0..<wordLength where guessChars[index] == targetChars[index] {
            results[index] = .correct
            if let removeIndex = remaining.firstIndex(of: guessChars[index]) {
                remaining.remove(at: removeIndex)
            }
        }

        for index in 0..<wordLength where results[index] != .correct {
            if let matchIndex = remaining.firstIndex(of: guessChars[index]) {
                results[index] = .present
                remaining.remove(at: matchIndex)
            }
        }

        return results
    }

    static func isCompleteWord(_ word: String) -> Bool {
        word.count == wordLength && word.allSatisfy(\.isLetter)
    }
}

struct DevWordleFreeRoundResult: Codable, Equatable {
    let word: String
    let attempts: Int
    let won: Bool
}

struct DevWordleFreeSession: Codable, Equatable {
    static let targetWordCount = 5

    var startTime: Date
    var results: [DevWordleFreeRoundResult]

    var wordsPlayed: Int { results.count }
    var isComplete: Bool { results.count >= Self.targetWordCount }

    var wins: Int { results.filter(\.won).count }

    var averageAttempts: Double {
        guard !results.isEmpty else { return 0 }
        let total = results.reduce(0) { $0 + $1.attempts }
        return Double(total) / Double(results.count)
    }

    func elapsedTime(at endDate: Date = .now) -> TimeInterval {
        max(0, endDate.timeIntervalSince(startTime))
    }

    static func formattedDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func newSession() -> DevWordleFreeSession {
        DevWordleFreeSession(startTime: .now, results: [])
    }
}

enum DevWordleSchedule {
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
}

struct DevWordDictionary {
    /// Daily challenge pool — programming terms only.
    let answers: [String]
    /// Valid guesses (dev + non-dev); never used as a target word.
    let extras: [String]
    /// Free mode pool — separate programming terms, disjoint from `answers`.
    let practiceAnswers: [String]
    let validGuesses: Set<String>

    static let shared: DevWordDictionary = {
        let loaded = loadFromBundle()
        let dictionary = loaded ?? fallback
        #if DEBUG
        if loaded != nil {
            DevWordDictionaryTests.runAll(on: dictionary)
        }
        #endif
        return dictionary
    }()

    var practiceWordCount: Int { practiceAnswers.count }

    func dailyWord(for date: Date = .now) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let today = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let index = abs(days) % answers.count
        return answers[index]
    }

    func randomPracticeWord(excluding words: Set<String> = []) -> String {
        let excluded = words.map { $0.uppercased() }
        let pool = practiceAnswers.filter { !excluded.contains($0) }
        return (pool.isEmpty ? practiceAnswers : pool).randomElement() ?? practiceAnswers[0]
    }

    func isValidGuess(_ word: String) -> Bool {
        validGuesses.contains(word.uppercased())
    }

    private static func loadFromBundle() -> DevWordDictionary? {
        guard let url = Bundle.main.url(forResource: "dev_words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(WordPayload.self, from: data) else {
            return nil
        }

        let answers = payload.answers
            .map { $0.uppercased() }
            .filter { $0.count == DevWordleEngine.wordLength && $0.allSatisfy(\.isLetter) }

        let extras = payload.extraGuesses
            .map { $0.uppercased() }
            .filter { $0.count == DevWordleEngine.wordLength && $0.allSatisfy(\.isLetter) }

        let answerSet = Set(answers)
        let practice = (payload.practiceAnswers ?? [])
            .map { $0.uppercased() }
            .filter { $0.count == DevWordleEngine.wordLength && $0.allSatisfy(\.isLetter) && !answerSet.contains($0) }

        guard !answers.isEmpty, !practice.isEmpty else { return nil }

        #if DEBUG
        DevWordDictionaryValidation.assertValid(answers: answers, extras: extras, practice: practice)
        #endif

        return DevWordDictionary(
            answers: answers,
            extras: extras,
            practiceAnswers: practice,
            validGuesses: Set(answers + extras + practice)
        )
    }

    private static let fallback = DevWordDictionary(
        answers: ["REACT", "SWIFT", "CACHE", "ASYNC", "HTTPS", "LINUX", "NGINX", "REDIS", "QUERY", "DEBUG"],
        extras: ["ABOUT", "HOUSE", "WORLD", "PLACE", "WRITE", "CLASS", "ERROR", "TOKEN", "FETCH", "PROXY"],
        practiceAnswers: ["CLASS", "ERROR", "TOKEN", "FETCH", "PROXY", "ADMIN", "AGENT", "ALERT", "ALPHA", "BADGE"],
        validGuesses: Set(["REACT", "SWIFT", "CACHE", "ASYNC", "HTTPS", "LINUX", "NGINX", "REDIS", "QUERY", "DEBUG", "ABOUT", "HOUSE", "WORLD", "PLACE", "WRITE", "CLASS", "ERROR", "TOKEN", "FETCH", "PROXY", "ADMIN", "AGENT", "ALERT", "ALPHA", "BADGE"])
    )

    private struct WordPayload: Decodable {
        let answers: [String]
        let extraGuesses: [String]
        let practiceAnswers: [String]?
    }
}
