import SwiftUI

struct DevSpotView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = DevSpotViewModel()
    @State private var hasStarted = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.devSpot)

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            RestGameBackground()

            switch viewModel.phase {
            case .playing, .revealing:
                playingBody
            case .finished:
                DevSpotResultsView(
                    correctCount: viewModel.correctCount,
                    totalRounds: viewModel.totalRounds,
                    bestStreak: viewModel.bestStreak,
                    roundResults: viewModel.roundResults,
                    onPlayAgain: {
                        hasStarted = false
                        startIfReady()
                    },
                    onClose: { dismiss() }
                )
            }

            if showOnboarding {
                RestGameOnboardingOverlay.devSpot {
                    RestGameOnboarding.markSeen(.devSpot)
                    showOnboarding = false
                    startIfReady()
                }
            }
        }
        .animation(RestGameTheme.spring, value: viewModel.phase)
        .onAppear {
            RestFeedbackManager.shared.prepare()
            startIfReady()
        }
        .task(id: revealTaskID) {
            guard viewModel.phase == .revealing else { return }
            try? await Task.sleep(for: .milliseconds(1100))
            viewModel.advanceAfterReveal()
        }
    }

    private var revealTaskID: String {
        viewModel.phase == .revealing ? "\(viewModel.currentRound)-reveal" : "idle"
    }

    private func startIfReady() {
        guard !showOnboarding, !hasStarted else { return }
        hasStarted = true
        viewModel.startGame()
    }

    @ViewBuilder
    private var playingBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    RoundIndicatorView(
                        currentRound: viewModel.currentRound,
                        totalRounds: viewModel.totalRounds
                    )
                    Spacer()
                    Text("\(viewModel.correctCount) acertos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Text("DevSpot")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Qual é o termo dev? · PT e EN")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 16)

            if let round = viewModel.currentRoundData {
                DevSpotDuelView(
                    round: round,
                    phase: viewModel.phase,
                    selectedSide: viewModel.selectedSide,
                    wasCorrect: viewModel.wasCorrect,
                    onSelect: { viewModel.select($0) }
                )
                .padding(.horizontal, 20)
                .id("\(viewModel.currentRound)-\(round.devTerm)-\(round.decoy)")
            }

            Spacer(minLength: 16)

            if viewModel.currentStreak >= 2 && viewModel.phase == .playing {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(viewModel.currentStreak) seguidos")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.15), in: Capsule())
                .padding(.bottom, 32)
                .transition(.scale.combined(with: .opacity))
            } else {
                Color.clear.frame(height: 52)
            }
        }
    }
}

private struct DevSpotDuelView: View {
    let round: DevSpotRound
    let phase: DevSpotPhase
    let selectedSide: DevSpotSide?
    let wasCorrect: Bool
    let onSelect: (DevSpotSide) -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            DevSpotWordCard(
                word: round.leftWord,
                side: .left,
                phase: phase,
                selectedSide: selectedSide,
                wasCorrect: wasCorrect,
                isDevTerm: round.isDevTerm(round.leftWord),
                appeared: appeared,
                delay: 0.05,
                onTap: { onSelect(.left) }
            )

            Text("VS")
                .font(.caption.weight(.black))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

            DevSpotWordCard(
                word: round.rightWord,
                side: .right,
                phase: phase,
                selectedSide: selectedSide,
                wasCorrect: wasCorrect,
                isDevTerm: round.isDevTerm(round.rightWord),
                appeared: appeared,
                delay: 0.15,
                onTap: { onSelect(.right) }
            )
        }
        .onAppear {
            appeared = false
            withAnimation(RestGameTheme.spring.delay(0.05)) {
                appeared = true
            }
        }
    }
}

private struct DevSpotWordCard: View {
    let word: String
    let side: DevSpotSide
    let phase: DevSpotPhase
    let selectedSide: DevSpotSide?
    let wasCorrect: Bool
    let isDevTerm: Bool
    let appeared: Bool
    let delay: Double
    let onTap: () -> Void

    @State private var shake = false
    @State private var glow = false

    private var isSelected: Bool { selectedSide == side }
    private var isRevealing: Bool { phase == .revealing }

    private var cardState: DevSpotCardVisualState {
        guard isRevealing else {
            return isSelected ? .selected : .neutral
        }
        if isDevTerm { return .correct }
        if isSelected && !wasCorrect { return .wrong }
        return .dimmed
    }

    var body: some View {
        Button(action: {
            guard phase == .playing else { return }
            RestFeedbackManager.shared.tap()
            onTap()
        }) {
            Text(word)
                .font(.system(size: wordFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(cardBorder, lineWidth: cardState == .neutral ? 1 : 2)
                }
                .shadow(color: cardShadow, radius: glow ? 24 : 8, y: 4)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
                .offset(x: shake ? -8 : 0)
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .disabled(phase != .playing)
        .animation(RestGameTheme.spring.delay(delay), value: appeared)
        .animation(RestGameTheme.quickSpring, value: cardState)
        .onChange(of: phase) { _, newPhase in
            guard newPhase == .revealing else { return }
            if isSelected && !wasCorrect {
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
                    shake = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shake = false
                }
            }
            if isDevTerm {
                withAnimation(RestGameTheme.spring) {
                    glow = true
                }
            }
        }
    }

    private var wordFontSize: CGFloat {
        word.count > 14 ? 20 : word.count > 10 ? 24 : 28
    }

    private var cardBackground: some ShapeStyle {
        switch cardState {
        case .neutral:
            return AnyShapeStyle(.white.opacity(0.08))
        case .selected:
            return AnyShapeStyle(.white.opacity(0.14))
        case .correct:
            return AnyShapeStyle(Color.green.opacity(0.35))
        case .wrong:
            return AnyShapeStyle(Color.red.opacity(0.3))
        case .dimmed:
            return AnyShapeStyle(.white.opacity(0.04))
        }
    }

    private var cardBorder: Color {
        switch cardState {
        case .neutral: return .white.opacity(0.12)
        case .selected: return .white.opacity(0.35)
        case .correct: return .green.opacity(0.8)
        case .wrong: return .red.opacity(0.7)
        case .dimmed: return .white.opacity(0.06)
        }
    }

    private var cardShadow: Color {
        switch cardState {
        case .correct: return .green.opacity(0.45)
        case .wrong where isSelected: return .red.opacity(0.35)
        default: return .clear
        }
    }
}

private enum DevSpotCardVisualState {
    case neutral, selected, correct, wrong, dimmed
}

private struct DevSpotResultsView: View {
    let correctCount: Int
    let totalRounds: Int
    let bestStreak: Int
    let roundResults: [Bool]
    let onPlayAgain: () -> Void
    let onClose: () -> Void

    @StateObject private var gameCenter = GameCenterManager.shared
    @State private var ringScale: CGFloat = 0.6
    @State private var showContent = false

    private var scorePercent: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(correctCount) / Double(totalRounds) * 10
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                RestGamePhaseLabel(text: "Resultado")

                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.25), lineWidth: 10)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringScale)

                    VStack(spacing: 4) {
                        Text("\(correctCount)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()

                        Text("/ \(totalRounds)")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                if bestStreak >= 3 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("Melhor streak: \(bestStreak)")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                }

                HStack(spacing: 6) {
                    ForEach(Array(roundResults.enumerated()), id: \.offset) { _, correct in
                        Circle()
                            .fill(correct ? Color.green.opacity(0.85) : Color.red.opacity(0.55))
                            .frame(width: 14, height: 14)
                    }
                }

                Text(resultMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if showContent {
                    VStack(spacing: 12) {
                        RestGamePrimaryButton(title: "Jogar de novo", action: onPlayAgain)
                        if gameCenter.isAuthenticated {
                            RestGameSecondaryButton(title: "Ver ranking") {
                                gameCenter.showLeaderboard(.devSpot)
                            }
                        }
                        RestGameSecondaryButton(title: "Voltar", action: onClose)
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 32)
        }
        .onAppear {
            withAnimation(RestGameTheme.spring) {
                ringScale = 1
            }
            RestFeedbackManager.shared.scoreReveal(score: scorePercent)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(RestGameTheme.spring) {
                    showContent = true
                }
            }
        }
    }

    private var scoreColor: Color {
        RestGameScoring.scoreColor(scorePercent)
    }

    private var resultMessage: String {
        switch correctCount {
        case totalRounds: return "Dev senior demais. 10/10."
        case 8...: return "Bem demais — você respira tech."
        case 5...: return "Razoável. Tem decoy te enganando."
        default: return "Hora de revisar o glossário."
        }
    }
}
