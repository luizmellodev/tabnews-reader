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
    let answers: [String]
    let validGuesses: Set<String>

    static let shared: DevWordDictionary = {
        if let loaded = loadFromBundle() {
            return loaded
        }
        return fallback
    }()

    func dailyWord(for date: Date = .now) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let today = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let index = abs(days) % answers.count
        return answers[index]
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

        guard !answers.isEmpty else { return nil }

        return DevWordDictionary(
            answers: answers,
            validGuesses: Set(answers + extras)
        )
    }

    private static let fallback = DevWordDictionary(
        answers: ["REACT", "SWIFT", "CACHE", "ASYNC", "HTTPS", "LINUX", "NGINX", "REDIS", "QUERY", "DEBUG"],
        validGuesses: Set(["REACT", "SWIFT", "CACHE", "ASYNC", "HTTPS", "LINUX", "NGINX", "REDIS", "QUERY", "DEBUG", "CLASS", "ERROR", "TOKEN", "FETCH", "PROXY"])
    )

    private struct WordPayload: Decodable {
        let answers: [String]
        let extraGuesses: [String]
    }
}
