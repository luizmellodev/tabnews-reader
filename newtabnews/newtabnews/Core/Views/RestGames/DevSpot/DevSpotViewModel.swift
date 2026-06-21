import Foundation

enum DevSpotPhase: Equatable {
    case playing
    case revealing
    case finished
}

@Observable
@MainActor
final class DevSpotViewModel {
    var phase: DevSpotPhase = .playing
    var currentRound = 1
    var currentRoundData: DevSpotRound?
    var selectedSide: DevSpotSide?
    var wasCorrect = false
    var correctCount = 0
    var currentStreak = 0
    var bestStreak = 0
    var roundResults: [Bool] = []

    private let dictionary = DevSpotDictionary.shared
    private var usedPairs: Set<String> = []

    var totalRounds: Int { DevSpotEngine.totalRounds }

    func startGame() {
        phase = .playing
        currentRound = 1
        selectedSide = nil
        wasCorrect = false
        correctCount = 0
        currentStreak = 0
        bestStreak = 0
        roundResults = []
        usedPairs = []
        loadNextRound()
    }

    func select(_ side: DevSpotSide) {
        guard phase == .playing, let round = currentRoundData else { return }

        selectedSide = side
        wasCorrect = DevSpotEngine.isCorrect(round: round, selectedSide: side)
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
    }

    func advanceAfterReveal() {
        guard phase == .revealing else { return }

        if currentRound >= totalRounds {
            phase = .finished
            RestFeedbackManager.shared.phaseTransition()
        } else {
            currentRound += 1
            selectedSide = nil
            wasCorrect = false
            phase = .playing
            loadNextRound()
            RestFeedbackManager.shared.phaseTransition()
        }
    }

    private func loadNextRound() {
        if let round = dictionary.makeRound(usedPairs: usedPairs) {
            currentRoundData = round
            usedPairs.insert([round.devTerm, round.decoy].sorted().joined(separator: "|"))
        }
    }
}
