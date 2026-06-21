import SwiftUI

struct RestGamePlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: RestGameSession
    @State private var hasStarted = false

    init(gameType: RestGameType) {
        _session = State(initialValue: RestGameSession(gameType: gameType))
    }

    var body: some View {
        @Bindable var session = session

        ZStack {
            switch session.phase {
            case .memorizing:
                MemorizePhaseView(
                    gameType: session.gameType,
                    targetColor: session.targetColor,
                    targetFrequency: session.targetFrequency,
                    timeRemaining: session.memorizeTimeRemaining
                )
            case .recreating:
                if session.gameType == .color {
                    HSLColorPickerView(color: $session.guessColor)
                } else {
                    FrequencyPickerView(frequency: $session.guessFrequency)
                }
            case .scoreReveal, .finalResults:
                RestGameBackground()
                phaseContent
            }

            gameChrome
        }
        .animation(RestGameTheme.spring, value: session.phase)
        .onAppear {
            RestFeedbackManager.shared.prepare()
            guard !hasStarted else { return }
            hasStarted = true
            session.startGame()
        }
        .onDisappear {
            session.cleanup()
        }
    }

    @ViewBuilder
    private var gameChrome: some View {
        VStack {
            if session.phase != .finalResults {
                HStack {
                    RoundIndicatorView(
                        currentRound: session.currentRound,
                        totalRounds: session.totalRounds,
                        lightStyle: session.phase == .memorizing && session.gameType == .color
                            || session.phase == .recreating && session.gameType == .color
                    )
                    Spacer()
                }
                .padding(.leading, 56)
                .padding(.trailing, 24)
                .padding(.top, 8)
            }

            Spacer()

            if session.phase == .recreating {
                HStack {
                    Spacer()
                    RestGameConfirmFAB {
                        session.confirmGuess()
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch session.phase {
        case .memorizing, .recreating:
            EmptyView()
        case .scoreReveal:
            ScoreRevealView(
                score: session.lastRoundScore,
                round: session.currentRound
            ) {
                session.advanceAfterScoreReveal()
            }
        case .finalResults:
            FinalResultsView(
                scores: session.roundScores,
                onPlayAgain: { session.playAgain() },
                onClose: {
                    session.cleanup()
                    dismiss()
                }
            )
        }
    }
}

struct ColorMatchView: View {
    var body: some View {
        RestGamePlayView(gameType: .color)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SoundMatchView: View {
    var body: some View {
        RestGamePlayView(gameType: .sound)
            .navigationBarTitleDisplayMode(.inline)
    }
}
