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
    var invalidGuessCount = 0
    var hintText: String?

    let targetWord: String
    let dateKey: String
    let mode: DevWordlePlayMode
    let sessionId: UUID

    private let dictionary = DevWordDictionary.shared
    private let storage = DevWordleStorage.shared

    init(mode: DevWordlePlayMode = .daily, date: Date = .now, excludeWords: Set<String> = [], forceFresh: Bool = false) {
        self.mode = mode
        self.sessionId = UUID()

        switch mode {
        case .daily:
            self.dateKey = Self.dateKey(for: date)
            self.targetWord = dictionary.dailyWord(for: date)
        case .free:
            self.dateKey = DevWordleStorage.freeModeKey
            let saved = forceFresh ? nil : storage.loadState(for: DevWordleStorage.freeModeKey)
            if let saved, saved.gameStatus == .playing {
                self.targetWord = saved.targetWord
            } else {
                if saved != nil {
                    storage.clearState(for: DevWordleStorage.freeModeKey)
                }
                var excluded = excludeWords
                excluded.insert(dictionary.dailyWord(for: date))
                self.targetWord = dictionary.randomPracticeWord(excluding: excluded)
            }
        }

        self.rows = Array(repeating: DevWordleGuessRow.empty(), count: DevWordleEngine.maxAttempts)

        if let saved = storage.loadState(for: dateKey),
           saved.targetWord == targetWord,
           mode == .daily || saved.gameStatus == .playing {
            rows = saved.rows
            currentRowIndex = saved.currentRowIndex
            currentGuess = saved.currentGuess
            gameStatus = saved.gameStatus
            invalidGuessCount = saved.invalidGuessCount
            hintText = saved.hintText
            if saved.gameStatus == .playing {
                revealedRows = Set(0..<saved.currentRowIndex)
            } else {
                revealedRows = Set(0...saved.currentRowIndex)
            }
        }
    }

    var isRoundComplete: Bool {
        gameStatus == .won || gameStatus == .lost
    }

    var isCompletedToday: Bool {
        mode == .daily && isRoundComplete
    }

    var showHintOffer: Bool {
        guard gameStatus == .playing, hintText == nil else { return false }
        let attemptsLeft = DevWordleEngine.maxAttempts - currentRowIndex
        return attemptsLeft <= 2 || invalidGuessCount >= 5
    }

    var winningAttemptNumber: Int? {
        guard gameStatus == .won else { return nil }
        return currentRowIndex + 1
    }

    var completedAttemptCount: Int? {
        guard isRoundComplete else { return nil }
        if gameStatus == .won {
            return winningAttemptNumber
        }
        return DevWordleEngine.maxAttempts
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
        let label = mode == .free ? "DevWordle Livre" : "DevWordle TabNews"
        let header = "\(label) \(wonAttemptLabel())"
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
        RestFeedbackManager.shared.tapHaptic()
        persist()
    }

    func deleteLetter() {
        guard gameStatus == .playing else { return }
        guard !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        RestFeedbackManager.shared.tapHaptic()
        persist()
    }

    func submitGuess() {
        guard gameStatus == .playing else { return }
        guard currentGuess.count == DevWordleEngine.wordLength else { return }

        let guess = currentGuess.uppercased()
        guard dictionary.isValidGuess(guess) else {
            invalidGuessCount += 1
            withInvalidShake()
            persist()
            return
        }

        let results = DevWordleEngine.evaluate(guess: guess, target: targetWord)
        rows[currentRowIndex].letters = guess.map { String($0) }
        rows[currentRowIndex].results = results
        revealedRows.insert(currentRowIndex)

        RestFeedbackManager.shared.confirmHaptic()

        if guess == targetWord {
            gameStatus = .won
            if mode == .daily {
                storage.recordWin(on: dateKey)
                if let attempt = winningAttemptNumber {
                    GameCenterManager.shared.submitDevWordleScore(attempts: attempt)
                    GamificationManager.shared.trackDevWordleWin(attempts: attempt)
                }
            }
        } else if currentRowIndex >= DevWordleEngine.maxAttempts - 1 {
            gameStatus = .lost
            if mode == .daily {
                storage.recordLoss(on: dateKey)
                GamificationManager.shared.trackDevWordlePlayed()
            }
        } else {
            currentRowIndex += 1
            currentGuess = ""
        }

        persist()
    }

    func acceptHint() {
        guard showHintOffer else { return }
        hintText = generateHint()
        RestFeedbackManager.shared.confirmHaptic()
        persist()
    }

    func clearSavedFreeState() {
        guard mode == .free else { return }
        storage.clearState(for: dateKey)
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
                gameStatus: gameStatus,
                invalidGuessCount: invalidGuessCount,
                hintText: hintText
            ),
            for: dateKey
        )
    }

    private func generateHint() -> String {
        let target = Array(targetWord.uppercased())
        let knownCorrectPositions = Set(
            (0..<currentRowIndex).flatMap { rowIndex in
                (0..<DevWordleEngine.wordLength).compactMap { column in
                    rows[rowIndex].results[column] == .correct ? column : nil
                }
            }
        )

        for (index, letter) in target.enumerated() where !knownCorrectPositions.contains(index) {
            return "A \(ordinalPosition(index + 1)) letra é \(letter)"
        }

        for letter in Set(target) {
            let state = keyboardStates[letter]
            if state != .correct && state != .present {
                return "A palavra contém a letra \(letter)"
            }
        }

        return "A palavra começa com \(target[0])"
    }

    private func ordinalPosition(_ position: Int) -> String {
        switch position {
        case 1: return "1ª"
        case 2: return "2ª"
        case 3: return "3ª"
        case 4: return "4ª"
        default: return "5ª"
        }
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
    var invalidGuessCount: Int = 0
    var hintText: String? = nil
}

struct DevWordleDailySummary {
    let played: Bool
    let won: Bool
    let currentStreak: Int
}

@MainActor
final class DevWordleStorage {
    static let shared = DevWordleStorage()
    static let freeModeKey = "free"

    private enum Keys {
        static let currentStreak = "devWordleCurrentStreak"
        static let maxStreak = "devWordleMaxStreak"
        static let lastPlayedDate = "devWordleLastPlayedDate"
        static let freeSession = "devWordle_freeSession"
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

    func clearState(for dateKey: String) {
        UserDefaults.standard.removeObject(forKey: stateKey(dateKey))
    }

    func loadFreeSession() -> DevWordleFreeSession? {
        guard let data = UserDefaults.standard.data(forKey: Keys.freeSession) else { return nil }
        return try? JSONDecoder().decode(DevWordleFreeSession.self, from: data)
    }

    func saveFreeSession(_ session: DevWordleFreeSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: Keys.freeSession)
    }

    func clearFreeSession() {
        UserDefaults.standard.removeObject(forKey: Keys.freeSession)
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

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: Keys.currentStreak)
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
