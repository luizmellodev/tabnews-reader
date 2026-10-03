import Foundation

@Observable
@MainActor
final class RegexGolfViewModel {
    let mode: ScenarioQuizPlayMode

    var phase: ScenarioQuizPhase = .playing
    var currentRound = 1
    var puzzle: RegexGolfPuzzle?
    private(set) var pattern = ""
    private(set) var evaluation: RegexGolfEvaluation?
    /// Resultado do round atual (preenchido ao enviar ou desistir)
    var lastRoundSolved = false
    var lastRoundScore = 0
    var roundScores: [Int] = []

    private var usedPuzzleIDs: Set<String> = []
    private let dateKey: String

    var totalRounds: Int {
        mode == .daily ? 1 : RegexGolfEngine.freeTotalRounds
    }

    var totalScore: Int {
        roundScores.reduce(0, +)
    }

    var isDailyComplete: Bool {
        guard mode == .daily else { return false }
        return RegexGolfStorage.loadState(for: dateKey)?.finished == true
    }

    init(mode: ScenarioQuizPlayMode, date: Date = .now) {
        self.mode = mode
        self.dateKey = ScenarioQuizEngine.dateKey(for: date)

        if mode == .daily, let saved = RegexGolfStorage.loadState(for: dateKey), saved.finished {
            phase = .finished
            lastRoundSolved = saved.solved
            if let daily = RegexGolfDictionary.daily.dailyPuzzle(for: date), daily.id == saved.puzzleID {
                puzzle = daily
                updatePattern(saved.pattern)
            }
        }
    }

    func startGame() {
        guard mode == .free || !isDailyComplete else { return }

        phase = .playing
        currentRound = 1
        roundScores = []
        usedPuzzleIDs = []
        loadNextPuzzle()
    }

    func updatePattern(_ newValue: String) {
        pattern = RegexGolfEngine.sanitize(newValue)
        if let puzzle {
            evaluation = RegexGolfEngine.evaluate(pattern, puzzle: puzzle)
        }
    }

    func append(_ token: String) {
        guard phase == .playing else { return }
        updatePattern(pattern + token)
    }

    func deleteLast() {
        guard phase == .playing, !pattern.isEmpty else { return }
        updatePattern(String(pattern.dropLast()))
    }

    func submit() {
        guard phase == .playing, let puzzle, evaluation?.isSolved == true else { return }
        finishRound(solved: true, score: RegexGolfEngine.score(length: pattern.count, par: puzzle.par))
        RestFeedbackManager.shared.correct()
    }

    func giveUp() {
        guard phase == .playing else { return }
        finishRound(solved: false, score: 0)
        RestFeedbackManager.shared.wrong()
    }

    func advanceAfterReveal() {
        guard phase == .revealing else { return }

        if mode == .daily || currentRound >= totalRounds {
            phase = .finished
            if mode == .free {
                GameCenterManager.shared.submitScore(totalScore, to: .regexGolf)
            }
        } else {
            currentRound += 1
            loadNextPuzzle()
        }
        RestFeedbackManager.shared.phaseTransition()
    }

    static func todaySummary() -> ScenarioQuizDailySummary {
        RegexGolfStorage.summary()
    }

    private func finishRound(solved: Bool, score: Int) {
        lastRoundSolved = solved
        lastRoundScore = score
        roundScores.append(score)
        phase = .revealing

        if mode == .daily, let puzzle {
            RegexGolfStorage.saveState(
                RegexGolfSavedState(puzzleID: puzzle.id, pattern: pattern, solved: solved, finished: true),
                for: dateKey
            )
            RegexGolfStorage.recordResult(solved: solved, dateKey: dateKey)
        }
    }

    private func loadNextPuzzle() {
        let next: RegexGolfPuzzle?
        switch mode {
        case .daily: next = RegexGolfDictionary.daily.dailyPuzzle()
        case .free: next = RegexGolfDictionary.free.randomPuzzle(excluding: usedPuzzleIDs)
        }

        guard let next else { return }
        usedPuzzleIDs.insert(next.id)
        puzzle = next
        lastRoundSolved = false
        lastRoundScore = 0
        phase = .playing
        updatePattern("")
    }
}
