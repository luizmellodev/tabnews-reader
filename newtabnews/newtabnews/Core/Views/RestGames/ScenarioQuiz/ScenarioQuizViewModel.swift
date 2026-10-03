import Foundation

@Observable
@MainActor
final class ScenarioQuizViewModel {
    let config: ScenarioQuizConfig
    let mode: ScenarioQuizPlayMode

    var phase: ScenarioQuizPhase = .playing
    var currentRound = 1
    var currentRoundData: ScenarioQuizRound?
    var selectedAnswer: String?
    var wasCorrect = false
    var correctCount = 0
    var currentStreak = 0
    var bestStreak = 0
    var roundResults: [Bool] = []

    private let dailyDictionary: ScenarioQuizDictionary
    private let freeDictionary: ScenarioQuizDictionary
    private let storage: ScenarioQuizStorage
    private var usedChallengeIDs: Set<String> = []
    private let dateKey: String

    var totalRounds: Int {
        mode == .daily ? 1 : ScenarioQuizEngine.freeTotalRounds
    }

    var isDailyComplete: Bool {
        guard mode == .daily else { return false }
        return storage.loadState(for: dateKey)?.finished == true
    }

    init(config: ScenarioQuizConfig, mode: ScenarioQuizPlayMode, date: Date = .now) {
        self.config = config
        self.mode = mode
        self.dateKey = ScenarioQuizEngine.dateKey(for: date)
        self.dailyDictionary = .load(resource: config.dailyResource)
        self.freeDictionary = .load(resource: config.freeResource)
        self.storage = ScenarioQuizStorage(prefix: config.storagePrefix)

        if mode == .daily, let saved = storage.loadState(for: dateKey), saved.finished {
            phase = .finished
            wasCorrect = saved.wasCorrect
            correctCount = saved.wasCorrect ? 1 : 0
            roundResults = [saved.wasCorrect]
            if let challenge = dailyDictionary.dailyChallenge(for: date), challenge.id == saved.challengeID {
                currentRoundData = ScenarioQuizRound(challenge: challenge, displayOptions: challenge.options)
                selectedAnswer = saved.selectedAnswer
            }
        }
    }

    func startGame() {
        guard mode == .free || !isDailyComplete else { return }

        phase = .playing
        currentRound = 1
        selectedAnswer = nil
        wasCorrect = false
        correctCount = 0
        currentStreak = 0
        bestStreak = 0
        roundResults = []
        usedChallengeIDs = []
        loadNextRound()
    }

    func select(_ answer: String) {
        guard phase == .playing, let round = currentRoundData else { return }

        selectedAnswer = answer
        wasCorrect = answer == round.correctAnswer
        roundResults.append(wasCorrect)

        if wasCorrect {
            correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            RestFeedbackManager.shared.correct()
        } else {
            currentStreak = 0
            RestFeedbackManager.shared.wrong()
        }

        phase = .revealing

        if mode == .daily {
            storage.saveState(
                ScenarioQuizSavedState(
                    challengeID: round.challenge.id,
                    selectedAnswer: answer,
                    wasCorrect: wasCorrect,
                    finished: true
                ),
                for: dateKey
            )
            storage.recordResult(correct: wasCorrect, dateKey: dateKey)
        }
    }

    func advanceAfterReveal() {
        guard phase == .revealing else { return }

        if mode == .daily || currentRound >= totalRounds {
            phase = .finished
            if mode == .free {
                GameCenterManager.shared.submitScore(correctCount * 100, to: config.leaderboard)
            }
            RestFeedbackManager.shared.phaseTransition()
        } else {
            currentRound += 1
            selectedAnswer = nil
            wasCorrect = false
            phase = .playing
            loadNextRound()
            RestFeedbackManager.shared.phaseTransition()
        }
    }

    static func todaySummary(for config: ScenarioQuizConfig) -> ScenarioQuizDailySummary {
        ScenarioQuizStorage(prefix: config.storagePrefix).summary(for: ScenarioQuizEngine.dateKey())
    }

    private func loadNextRound() {
        switch mode {
        case .daily:
            guard let challenge = dailyDictionary.dailyChallenge() else { return }
            currentRoundData = ScenarioQuizRound(challenge: challenge, displayOptions: challenge.options.shuffled())
            usedChallengeIDs.insert(challenge.id)

        case .free:
            guard let round = freeDictionary.makeRound(excluding: usedChallengeIDs) else { return }
            currentRoundData = round
            usedChallengeIDs.insert(round.challenge.id)
        }
    }
}
