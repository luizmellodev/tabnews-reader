import Foundation

enum RestGameType: Hashable {
    case color
    case sound
}

enum RestGamePhase: Equatable {
    case memorizing
    case recreating
    /// Rounds de múltipla escolha (sem memorizar/recriar).
    case choosing
    case scoreReveal
    case finalResults
}

enum RestGameRoundKind: Equatable {
    /// Memoriza e recria (clássico).
    case recreate
    /// Color Match: lê o hex e toca na cor certa.
    case hexRead
    /// Sound Match: qual de dois tons foi mais agudo.
    case higherPitch

    static func kind(for round: Int, gameType: RestGameType) -> RestGameRoundKind {
        switch gameType {
        case .color: return round == 2 || round == 4 ? .hexRead : .recreate
        case .sound: return round == 3 ? .higherPitch : .recreate
        }
    }
}

@Observable
@MainActor
final class RestGameSession {
    let gameType: RestGameType
    let totalRounds = RestGameScoring.totalRounds

    var phase: RestGamePhase = .memorizing
    var roundKind: RestGameRoundKind = .recreate
    var currentRound = 1
    var roundScores: [Double] = []
    var memorizeTimeRemaining: TimeInterval = RestGameScoring.memorizeDuration

    var targetColor: HSLColor?
    var targetFrequency: Double?

    var guessColor = HSLColor(hue: 180, saturation: 50, lightness: 50)
    var guessFrequency: Double = 440
    var soundVisualProfile: SoundRibbonVisualProfile = .interactive

    // Rounds de escolha: índices valem para `hexOptions` ou `pitchFrequencies`.
    var hexOptions: [HSLColor] = []
    var pitchFrequencies: [Double] = []
    var correctChoiceIndex = 0
    var selectedChoiceIndex: Int?
    var pitchPlayingIndex: Int?
    var hasHeardPitchPair = false

    var lastRoundScore: Double = 0
    private var memorizeTask: Task<Void, Never>?
    private var pitchPlaybackTask: Task<Void, Never>?

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
        memorizeTask?.cancel()
        pitchPlaybackTask?.cancel()
        memorizeTimeRemaining = RestGameScoring.memorizeDuration
        roundKind = RestGameRoundKind.kind(for: currentRound, gameType: gameType)
        selectedChoiceIndex = nil

        switch roundKind {
        case .recreate:
            break
        case .hexRead:
            let round = RestGameScoring.hexReadOptions(closeDistractors: currentRound > 2)
            hexOptions = round.options
            correctChoiceIndex = round.correctIndex
            targetColor = round.options[round.correctIndex]
            withPhaseTransition(to: .choosing)
            return
        case .higherPitch:
            let pair = RestGameScoring.pitchPair()
            pitchFrequencies = pair.frequencies
            correctChoiceIndex = pair.higherIndex
            targetFrequency = pair.frequencies[pair.higherIndex]
            hasHeardPitchPair = false
            withPhaseTransition(to: .choosing)
            playPitchPair()
            return
        }

        switch gameType {
        case .color:
            targetColor = HSLColor.randomEasy()
            guessColor = HSLColor(hue: 180, saturation: 50, lightness: 50)
        case .sound:
            targetFrequency = RestGameScoring.randomEasyFrequency()
            guessFrequency = 440
            soundVisualProfile = SoundRibbonVisualProfile.randomMemorize()
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

    func chooseOption(_ index: Int) {
        guard phase == .choosing, selectedChoiceIndex == nil else { return }
        pitchPlaybackTask?.cancel()
        pitchPlayingIndex = nil
        ToneGenerator.shared.stop()

        switch roundKind {
        case .hexRead:
            guard hexOptions.indices.contains(index) else { return }
            guessColor = hexOptions[index]
        case .higherPitch:
            guard pitchFrequencies.indices.contains(index) else { return }
            guessFrequency = pitchFrequencies[index]
        case .recreate:
            return
        }

        selectedChoiceIndex = index
        lastRoundScore = index == correctChoiceIndex ? RestGameScoring.choiceCorrectScore : 0
        roundScores.append(lastRoundScore)
        RestFeedbackManager.shared.confirm()
        withPhaseTransition(to: .scoreReveal)
    }

    /// Toca o primeiro tom, uma pausa curta e o segundo. Também serve de "ouvir de novo".
    func playPitchPair() {
        guard pitchFrequencies.count == 2 else { return }
        pitchPlaybackTask?.cancel()
        ToneGenerator.shared.stop()

        pitchPlaybackTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(350))

            for (index, frequency) in pitchFrequencies.enumerated() {
                if Task.isCancelled { return }
                pitchPlayingIndex = index
                ToneGenerator.shared.sustain(frequency: frequency)
                try? await Task.sleep(for: .seconds(RestGameScoring.pitchToneDuration))
                if Task.isCancelled { return }
                ToneGenerator.shared.release(purpose: .soundMatch, fadeDuration: 0.1)
                pitchPlayingIndex = nil
                try? await Task.sleep(for: .seconds(RestGameScoring.pitchToneGap))
            }

            if Task.isCancelled { return }
            hasHeardPitchPair = true
        }
    }

    func advanceAfterScoreReveal() {
        if currentRound >= totalRounds {
            GameCenterManager.shared.submitArcadeScore(totalScore: totalScore, gameType: gameType)
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
        pitchPlaybackTask?.cancel()
        pitchPlayingIndex = nil
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
