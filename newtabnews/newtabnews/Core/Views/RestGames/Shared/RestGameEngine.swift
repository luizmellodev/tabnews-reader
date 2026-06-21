import Foundation

enum RestGameType: Hashable {
    case color
    case sound
}

enum RestGamePhase: Equatable {
    case memorizing
    case recreating
    case scoreReveal
    case finalResults
}

@Observable
@MainActor
final class RestGameSession {
    let gameType: RestGameType
    let totalRounds = RestGameScoring.totalRounds

    var phase: RestGamePhase = .memorizing
    var currentRound = 1
    var roundScores: [Double] = []
    var memorizeTimeRemaining: TimeInterval = RestGameScoring.memorizeDuration

    var targetColor: HSLColor?
    var targetFrequency: Double?

    var guessColor = HSLColor(hue: 180, saturation: 50, lightness: 50)
    var guessFrequency: Double = 440

    var lastRoundScore: Double = 0
    private var memorizeTask: Task<Void, Never>?

    init(gameType: RestGameType) {
        self.gameType = gameType
    }

    var totalScore: Double {
        roundScores.reduce(0, +)
    }

    var formattedTotalScore: String {
        RestGameScoring.formattedScore(totalScore)
    }

    func startGame() {
        roundScores = []
        currentRound = 1
        beginRound()
    }

    func beginRound() {
        memorizeTimeRemaining = RestGameScoring.memorizeDuration

        switch gameType {
        case .color:
            targetColor = HSLColor.randomEasy()
            guessColor = HSLColor(hue: 180, saturation: 50, lightness: 50)
        case .sound:
            targetFrequency = RestGameScoring.randomEasyFrequency()
            guessFrequency = 440
        }

        withPhaseTransition(to: .memorizing)
        startMemorizeCountdown()
    }

    func confirmGuess() {
        memorizeTask?.cancel()
        ToneGenerator.shared.stop()

        switch gameType {
        case .color:
            guard let targetColor else { return }
            lastRoundScore = RestGameScoring.colorScore(target: targetColor, guess: guessColor)
        case .sound:
            guard let targetFrequency else { return }
            lastRoundScore = RestGameScoring.frequencyScore(target: targetFrequency, guess: guessFrequency)
        }

        roundScores.append(lastRoundScore)
        RestFeedbackManager.shared.confirm()
        withPhaseTransition(to: .scoreReveal)
    }

    func advanceAfterScoreReveal() {
        if currentRound >= totalRounds {
            withPhaseTransition(to: .finalResults)
        } else {
            currentRound += 1
            beginRound()
        }
    }

    func playAgain() {
        startGame()
    }

    func cleanup() {
        memorizeTask?.cancel()
        ToneGenerator.shared.stop()
    }

    private func withPhaseTransition(to newPhase: RestGamePhase) {
        phase = newPhase
        RestFeedbackManager.shared.phaseTransition()
    }

    private func startMemorizeCountdown() {
        memorizeTask?.cancel()

        if gameType == .sound, let targetFrequency {
            ToneGenerator.shared.sustain(frequency: targetFrequency)
        }

        let totalSeconds = Int(RestGameScoring.memorizeDuration)
        var announcedSecond = Int(ceil(memorizeTimeRemaining))
        RestFeedbackManager.shared.countdownTick(second: announcedSecond, total: totalSeconds)

        memorizeTask = Task { [weak self] in
            guard let self else { return }
            let steps = Int(RestGameScoring.memorizeDuration * 10)
            for step in 0...steps {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                memorizeTimeRemaining = max(0, RestGameScoring.memorizeDuration - (Double(step) / 10))

                let second = Int(ceil(memorizeTimeRemaining))
                if second != announcedSecond {
                    announcedSecond = second
                    if second > 0 {
                        RestFeedbackManager.shared.countdownTick(second: second, total: totalSeconds)
                    }
                }
            }

            if Task.isCancelled { return }
            RestFeedbackManager.shared.countdownFinish()
            ToneGenerator.shared.stop()
            withPhaseTransition(to: .recreating)

            if gameType == .sound {
                ToneGenerator.shared.sustain(frequency: guessFrequency)
            }
        }
    }
}
