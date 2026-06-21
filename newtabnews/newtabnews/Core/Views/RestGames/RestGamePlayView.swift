import SwiftUI

struct RestGamePlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: RestGameSession
    @State private var hasStarted = false
    @State private var showOnboarding: Bool

    init(gameType: RestGameType) {
        _session = State(initialValue: RestGameSession(gameType: gameType))
        let onboardingID: RestGameOnboardingID = gameType == .color ? .colorMatch : .soundMatch
        _showOnboarding = State(initialValue: !RestGameOnboarding.hasSeen(onboardingID))
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

            if showOnboarding {
                onboardingOverlay
            }
        }
        .animation(RestGameTheme.spring, value: session.phase)
        .onAppear {
            RestFeedbackManager.shared.prepare()
            startIfReady()
        }
        .onDisappear {
            session.cleanup()
        }
    }

    @ViewBuilder
    private var onboardingOverlay: some View {
        switch session.gameType {
        case .color:
            RestGameOnboardingOverlay.colorMatch {
                dismissOnboarding()
            }
        case .sound:
            RestGameOnboardingOverlay.soundMatch {
                dismissOnboarding()
            }
        }
    }

    private func dismissOnboarding() {
        let id: RestGameOnboardingID = session.gameType == .color ? .colorMatch : .soundMatch
        RestGameOnboarding.markSeen(id)
        showOnboarding = false
        startIfReady()
    }

    private func startIfReady() {
        guard !showOnboarding, !hasStarted else { return }
        hasStarted = true
        session.startGame()
    }

    @ViewBuilder
    private var gameChrome: some View {
        VStack {
            if session.phase != .finalResults && !showOnboarding {
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

            if session.phase == .recreating && !showOnboarding {
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
                gameType: session.gameType,
                score: session.lastRoundScore,
                round: session.currentRound,
                targetColor: session.targetColor,
                guessColor: session.guessColor,
                targetFrequency: session.targetFrequency,
                guessFrequency: session.guessFrequency
            ) {
                session.advanceAfterScoreReveal()
            }
        case .finalResults:
            FinalResultsView(
                scores: session.roundScores,
                leaderboard: session.gameType == .color ? .colorMatch : .soundMatch,
                onPlayAgain: {
                    hasStarted = false
                    showOnboarding = false
                    startIfReadyAfterReplay()
                },
                onClose: {
                    session.cleanup()
                    dismiss()
                }
            )
        }
    }

    private func startIfReadyAfterReplay() {
        guard !hasStarted else { return }
        hasStarted = true
        session.playAgain()
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
