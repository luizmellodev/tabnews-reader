import Foundation

@Observable
@MainActor
final class DevWordleViewModel {
    var rows: [DevWordleGuessRow]
    var currentRowIndex = 0
    var currentGuess = ""
    var gameStatus: DevWordleGameStatus = .playing
    var shakeRow = false
    var revealedRows: Set<Int> = []

    let targetWord: String
    let dateKey: String

    private let dictionary = DevWordDictionary.shared
    private let storage = DevWordleStorage.shared

    init(date: Date = .now) {
        self.dateKey = Self.dateKey(for: date)
        self.targetWord = dictionary.dailyWord(for: date)
        self.rows = Array(repeating: DevWordleGuessRow.empty(), count: DevWordleEngine.maxAttempts)

        if let saved = storage.loadState(for: dateKey), saved.targetWord == targetWord {
            rows = saved.rows
            currentRowIndex = saved.currentRowIndex
            currentGuess = saved.currentGuess
            gameStatus = saved.gameStatus
            if saved.gameStatus == .playing {
                revealedRows = Set(0..<saved.currentRowIndex)
            } else {
                revealedRows = Set(0...saved.currentRowIndex)
            }
        }
    }

    var isCompletedToday: Bool {
        gameStatus == .won || gameStatus == .lost
    }

    var winningAttemptNumber: Int? {
        guard gameStatus == .won else { return nil }
        return currentRowIndex + 1
    }

    var keyboardStates: [Character: DevWordleLetterResult] {
        var states: [Character: DevWordleLetterResult] = [:]
        for rowIndex in 0..<currentRowIndex {
            let row = rows[rowIndex]
            for index in 0..<DevWordleEngine.wordLength {
                guard let letterString = row.letters[index], let letter = letterString.first,
                      let result = row.results[index] else { continue }
                let existing = states[letter]
                states[letter] = bestResult(existing, result)
            }
        }
        return states
    }

    var shareText: String {
        let header = "DevWordle TabNews \(wonAttemptLabel())"
        let completedCount = gameStatus == .playing ? currentRowIndex : currentRowIndex + 1
        let grid = (0..<completedCount).map { rowIndex -> String in
            rows[rowIndex].results.compactMap { result in
                switch result {
                case .correct: return "🟩"
                case .present: return "🟨"
                case .absent: return "⬛"
                case .none: return nil
                }
            }.joined()
        }.joined(separator: "\n")
        return "\(header)\n\n\(grid)"
    }

    func appendLetter(_ character: Character) {
        guard gameStatus == .playing else { return }
        guard currentGuess.count < DevWordleEngine.wordLength else { return }
        currentGuess.append(character.uppercased().first ?? character)
        RestFeedbackManager.shared.tap()
        persist()
    }

    func deleteLetter() {
        guard gameStatus == .playing else { return }
        guard !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        RestFeedbackManager.shared.tap()
        persist()
    }

    func submitGuess() {
        guard gameStatus == .playing else { return }
        guard currentGuess.count == DevWordleEngine.wordLength else { return }

        let guess = currentGuess.uppercased()
        guard dictionary.isValidGuess(guess) else {
            withInvalidShake()
            return
        }

        let results = DevWordleEngine.evaluate(guess: guess, target: targetWord)
        rows[currentRowIndex].letters = guess.map { String($0) }
        rows[currentRowIndex].results = results
        revealedRows.insert(currentRowIndex)

        RestFeedbackManager.shared.confirm()

        if guess == targetWord {
            gameStatus = .won
            storage.recordWin(on: dateKey)
        } else if currentRowIndex >= DevWordleEngine.maxAttempts - 1 {
            gameStatus = .lost
            storage.recordLoss(on: dateKey)
        } else {
            currentRowIndex += 1
            currentGuess = ""
        }

        persist()
    }

    static func todaySummary() -> DevWordleDailySummary {
        DevWordleStorage.shared.summary(for: Self.dateKey())
    }

    private func persist() {
        storage.saveState(
            DevWordleSavedState(
                targetWord: targetWord,
                rows: rows,
                currentRowIndex: currentRowIndex,
                currentGuess: currentGuess,
                gameStatus: gameStatus
            ),
            for: dateKey
        )
    }

    private func withInvalidShake() {
        shakeRow = true
        RestFeedbackManager.shared.scoreReveal(score: 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.shakeRow = false
        }
    }

    private func wonAttemptLabel() -> String {
        guard gameStatus == .won else { return "X/6" }
        return "\(currentRowIndex + 1)/6"
    }

    private func bestResult(_ lhs: DevWordleLetterResult?, _ rhs: DevWordleLetterResult) -> DevWordleLetterResult {
        switch (lhs, rhs) {
        case (.correct, _), (_, .correct): return .correct
        case (.present, _), (_, .present): return .present
        default: return rhs
        }
    }

    private static func dateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct DevWordleSavedState: Codable {
    let targetWord: String
    let rows: [DevWordleGuessRow]
    let currentRowIndex: Int
    let currentGuess: String
    let gameStatus: DevWordleGameStatus
}

struct DevWordleDailySummary {
    let played: Bool
    let won: Bool
    let currentStreak: Int
}

@MainActor
final class DevWordleStorage {
    static let shared = DevWordleStorage()

    private enum Keys {
        static let currentStreak = "devWordleCurrentStreak"
        static let maxStreak = "devWordleMaxStreak"
        static let lastPlayedDate = "devWordleLastPlayedDate"
    }

    private init() {}

    func loadState(for dateKey: String) -> DevWordleSavedState? {
        guard let data = UserDefaults.standard.data(forKey: stateKey(dateKey)) else { return nil }
        return try? JSONDecoder().decode(DevWordleSavedState.self, from: data)
    }

    func saveState(_ state: DevWordleSavedState, for dateKey: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: stateKey(dateKey))
    }

    func summary(for dateKey: String) -> DevWordleDailySummary {
        let state = loadState(for: dateKey)
        return DevWordleDailySummary(
            played: state?.gameStatus != .playing && state != nil,
            won: state?.gameStatus == .won,
            currentStreak: UserDefaults.standard.integer(forKey: Keys.currentStreak)
        )
    }

    func recordWin(on dateKey: String) {
        updateStreak(for: dateKey, won: true)
    }

    func recordLoss(on dateKey: String) {
        updateStreak(for: dateKey, won: false)
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
        "devWordle_state_\(dateKey)"
    }
}
