import Foundation

@Observable
@MainActor
final class AlgoSpotViewModel {
    let mode: AlgoSpotPlayMode

    var phase: AlgoSpotPhase = .playing
    var currentRound = 1
    var currentRoundData: AlgoSpotRound?
    var selectedAnswer: String?
    var wasCorrect = false
    var correctCount = 0
    var currentStreak = 0
    var bestStreak = 0
    var roundResults: [Bool] = []
    var showLearnSheet = false

    private let dailyDictionary = AlgoSpotDailyDictionary.shared
    private let freeDictionary = AlgoSpotFreeDictionary.shared
    private let storage = AlgoSpotStorage.shared
    private var usedChallengeIDs: Set<String> = []
    private let dateKey: String

    var totalRounds: Int {
        mode == .daily ? 1 : AlgoSpotEngine.freeTotalRounds
    }

    var isDailyComplete: Bool {
        guard mode == .daily else { return false }
        return storage.loadState(for: dateKey)?.finished == true
    }

    init(mode: AlgoSpotPlayMode, date: Date = .now) {
        self.mode = mode
        self.dateKey = AlgoSpotEngine.dateKey(for: date)

        if mode == .daily, let saved = storage.loadState(for: dateKey), saved.finished {
            phase = .finished
            wasCorrect = saved.wasCorrect
            correctCount = saved.wasCorrect ? 1 : 0
            roundResults = [saved.wasCorrect]
            if let challenge = dailyDictionary.challenge(for: date), challenge.id == saved.challengeID {
                currentRoundData = AlgoSpotRound(
                    challenge: challenge,
                    displayOptions: challenge.options
                )
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
        showLearnSheet = false
        loadNextRound()
    }

    func select(_ answer: String) {
        guard phase == .playing, let round = currentRoundData else { return }

        selectedAnswer = answer
        wasCorrect = AlgoSpotEngine.isCorrect(round: round, selected: answer)
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
        showLearnSheet = true

        if mode == .daily, let challenge = currentRoundData?.challenge {
            storage.saveState(
                AlgoSpotSavedState(
                    challengeID: challenge.id,
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
        showLearnSheet = false

        if mode == .daily || currentRound >= totalRounds {
            phase = .finished
            if mode == .free {
                GameCenterManager.shared.submitAlgoSpotScore(correctCount: correctCount)
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

    static func todaySummary() -> AlgoSpotDailySummary {
        AlgoSpotStorage.shared.summary(for: AlgoSpotEngine.dateKey())
    }

    private func loadNextRound() {
        switch mode {
        case .daily:
            guard let challenge = dailyDictionary.challenge() else { return }
            currentRoundData = AlgoSpotRound(
                challenge: challenge,
                displayOptions: challenge.shuffledOptions()
            )
            usedChallengeIDs.insert(challenge.id)

        case .free:
            guard let round = freeDictionary.makeRound(excluding: usedChallengeIDs) else { return }
            currentRoundData = round
            usedChallengeIDs.insert(round.challenge.id)
        }
    }
}
