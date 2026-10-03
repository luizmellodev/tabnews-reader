import SwiftUI

private struct ScenarioQuizRevealSnapshot: Equatable {
    let challenge: ScenarioQuizChallenge
    let wasCorrect: Bool
}

struct ScenarioQuizView: View {
    let config: ScenarioQuizConfig

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(RestGameFreeModePolicy.storageKey) private var restGamesAllowFreeMode = false

    @State private var playMode: ScenarioQuizPlayMode = .daily
    @State private var dailyViewModel: ScenarioQuizViewModel
    @State private var freeViewModel: ScenarioQuizViewModel
    @State private var hasStartedFree = false
    @State private var showOnboarding: Bool
    @State private var showIntroLearn = false
    @State private var showRevealLearn = false
    @State private var revealSnapshot: ScenarioQuizRevealSnapshot?
    @State private var showFreeModeLockedHint = false

    init(config: ScenarioQuizConfig) {
        self.config = config
        _dailyViewModel = State(initialValue: ScenarioQuizViewModel(config: config, mode: .daily))
        _freeViewModel = State(initialValue: ScenarioQuizViewModel(config: config, mode: .free))
        _showOnboarding = State(initialValue: !RestGameOnboarding.hasSeen(config.onboardingID))
    }

    var body: some View {
        ZStack {
            RestGameBackground(animated: false)

            if playMode == .free, freeViewModel.phase == .finished {
                ScenarioQuizResultsView(
                    config: config,
                    correctCount: freeViewModel.correctCount,
                    totalRounds: freeViewModel.totalRounds,
                    bestStreak: freeViewModel.bestStreak,
                    roundResults: freeViewModel.roundResults,
                    onPlayAgain: restartFree,
                    onClose: { dismiss() }
                )
            } else {
                playingBody(viewModel: activeViewModel)
            }

            if showOnboarding {
                config.onboardingOverlay {
                    RestGameOnboarding.markSeen(config.onboardingID)
                    showOnboarding = false
                    startIfReady()
                }
            }
        }
        .animation(RestGameTheme.spring, value: playMode)
        .onAppear {
            RestFeedbackManager.shared.prepare()
            if playMode == .free, !isFreeModeUnlocked {
                playMode = .daily
            }
            startIfReady()
        }
        .onChange(of: restGamesAllowFreeMode) { _, _ in
            if playMode == .free, !isFreeModeUnlocked {
                playMode = .daily
            }
        }
        .sheet(isPresented: $showIntroLearn) {
            ScenarioQuizIntroSheet(config: config) { openURL($0) }
        }
        .sheet(isPresented: $showRevealLearn, onDismiss: handleRevealSheetDismissed) {
            if let snapshot = revealSnapshot {
                ScenarioQuizLearnSheet(
                    config: config,
                    challenge: snapshot.challenge,
                    wasCorrect: snapshot.wasCorrect
                ) { openURL($0) }
            }
        }
        .onChange(of: activeViewModel.phase) { _, phase in
            guard phase == .revealing, let round = activeViewModel.currentRoundData else { return }
            revealSnapshot = ScenarioQuizRevealSnapshot(
                challenge: round.challenge,
                wasCorrect: activeViewModel.wasCorrect
            )
            // Pequena pausa para o jogador ver qual opção estava certa antes do sheet subir
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if activeViewModel.phase == .revealing {
                    showRevealLearn = true
                }
            }
        }
    }

    private func handleRevealSheetDismissed() {
        guard activeViewModel.phase == .revealing else { return }
        activeViewModel.advanceAfterReveal()
        revealSnapshot = nil
    }

    private var activeViewModel: ScenarioQuizViewModel {
        playMode == .daily ? dailyViewModel : freeViewModel
    }

    private var isFreeModeUnlocked: Bool {
        RestGameFreeModePolicy.isUnlocked(
            dailyComplete: dailyViewModel.isDailyComplete,
            isAllowed: restGamesAllowFreeMode
        )
    }

    private var showDailyCompleteEmptyState: Bool {
        playMode == .daily && dailyViewModel.isDailyComplete && dailyViewModel.phase == .finished
    }

    private func startIfReady() {
        guard !showOnboarding else { return }
        if playMode == .daily, !dailyViewModel.isDailyComplete, dailyViewModel.phase != .finished {
            dailyViewModel.startGame()
        }
        if playMode == .free, !hasStartedFree {
            hasStartedFree = true
            freeViewModel.startGame()
        }
    }

    private func selectMode(_ mode: ScenarioQuizPlayMode) {
        guard playMode != mode else { return }
        guard mode != .free || isFreeModeUnlocked else {
            withAnimation(.easeOut(duration: 0.22)) {
                showFreeModeLockedHint = true
            }
            RestGameFreeModePolicy.handleLockedAttempt(
                dailyComplete: dailyViewModel.isDailyComplete,
                isAllowed: restGamesAllowFreeMode
            )
            return
        }
        showFreeModeLockedHint = false
        showRevealLearn = false
        revealSnapshot = nil
        if mode == .free, !hasStartedFree {
            hasStartedFree = true
            freeViewModel.startGame()
        }
        withAnimation(RestGameTheme.spring) {
            playMode = mode
        }
    }

    private func restartFree() {
        freeViewModel = ScenarioQuizViewModel(config: config, mode: .free)
        hasStartedFree = true
        freeViewModel.startGame()
    }

    // MARK: - Layout

    @ViewBuilder
    private func playingBody(viewModel: ScenarioQuizViewModel) -> some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 12)

            ZStack {
                if showDailyCompleteEmptyState {
                    RestGameDailyCompleteEmptyState(wasCorrect: dailyViewModel.wasCorrect) {
                        BigOCountdownLabel(prefix: "Próximo desafio em")
                    }
                    .transition(.opacity)
                } else if let round = viewModel.currentRoundData {
                    playingContent(viewModel: viewModel, round: round)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: showDailyCompleteEmptyState)
            .padding(.horizontal, 16)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func playingContent(viewModel: ScenarioQuizViewModel, round: ScenarioQuizRound) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if playMode == .free {
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
                    .padding(.bottom, 12)
                }

                ScenarioQuizCardView(config: config, challenge: round.challenge)
                    .padding(.horizontal, 20)
                    .id("\(viewModel.currentRound)-\(round.challenge.id)")

                Text(config.question)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScenarioQuizOptionsView(
                    config: config,
                    options: round.displayOptions,
                    phase: viewModel.phase,
                    selectedAnswer: viewModel.selectedAnswer,
                    correctAnswer: round.correctAnswer,
                    wasCorrect: viewModel.wasCorrect,
                    onSelect: { viewModel.select($0) }
                )
                .padding(.horizontal, 20)
                .disabled(viewModel.phase != .playing)

                if viewModel.phase == .revealing {
                    Button {
                        showRevealLearn = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                            Text("Entender")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(config.accentLight)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(config.accent.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(RestGameScaleButtonStyle())
                    .padding(.top, 16)
                    .transition(.opacity)
                }

                if viewModel.currentStreak >= 2 && viewModel.phase == .playing && playMode == .free {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text("\(viewModel.currentStreak) seguidos")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .padding(.top, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .animation(RestGameTheme.spring, value: viewModel.phase)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button {
                    showIntroLearn = true
                } label: {
                    Label("Dica", systemImage: "lightbulb.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(RestGameScaleButtonStyle())
            }
            .padding(.horizontal, 20)

            Text(config.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            RestGameModeToggle(
                selection: playMode,
                isFreeUnlocked: isFreeModeUnlocked,
                daily: .daily,
                free: .free,
                onSelect: selectMode
            )
            .padding(.horizontal, 32)

            let subtitle = RestGameFreeModePolicy.modeSubtitle(
                isFreeModeActive: playMode == .free,
                dailyComplete: showDailyCompleteEmptyState || dailyViewModel.isDailyComplete,
                isAllowed: restGamesAllowFreeMode,
                freeModeDetail: "10 desafios · lista separada do diário",
                dailyCompleteDetail: "Desafio de hoje concluído · modo livre liberado",
                showLockedHint: showFreeModeLockedHint
            )
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Card

private struct ScenarioQuizCardView: View {
    let config: ScenarioQuizConfig
    let challenge: ScenarioQuizChallenge

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(challenge.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(challenge.scenario)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if let context = challenge.context, !context.isEmpty {
                ScenarioQuizTerminalBlock(text: context, accent: config.accentLight)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [config.accent.opacity(0.6), config.accentLight.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: config.accent.opacity(0.15), radius: 16, y: 6)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(RestGameTheme.spring) {
                appeared = true
            }
        }
    }
}

/// Bloco estilo terminal: linhas com `$` ganham a cor do jogo
struct ScenarioQuizTerminalBlock: View {
    let text: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: 12.5, weight: line.hasPrefix("$") ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(line.hasPrefix("$") ? accent : .white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Options

private enum ScenarioQuizOptionState {
    case neutral
    case correct
    case wrong
    case dimmed
}

private struct ScenarioQuizOptionsView: View {
    let config: ScenarioQuizConfig
    let options: [String]
    let phase: ScenarioQuizPhase
    let selectedAnswer: String?
    let correctAnswer: String
    let wasCorrect: Bool
    let onSelect: (String) -> Void

    var body: some View {
        let columns = config.optionsInSingleColumn
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        LazyVGrid(columns: columns, spacing: config.optionsInSingleColumn ? 10 : 12) {
            ForEach(options, id: \.self) { option in
                ScenarioQuizOptionButton(
                    config: config,
                    label: option,
                    state: state(for: option),
                    onTap: { onSelect(option) }
                )
            }
        }
    }

    private func state(for option: String) -> ScenarioQuizOptionState {
        guard phase != .playing else { return .neutral }
        if option == correctAnswer { return .correct }
        if selectedAnswer == option && !wasCorrect { return .wrong }
        return .dimmed
    }
}

private struct ScenarioQuizOptionButton: View {
    let config: ScenarioQuizConfig
    let label: String
    let state: ScenarioQuizOptionState
    let onTap: () -> Void

    @State private var shake = false

    var body: some View {
        Button {
            guard state == .neutral else { return }
            RestFeedbackManager.shared.tap()
            onTap()
        } label: {
            Text(label)
                .font(config.monospacedOptions
                    ? .system(size: 15, weight: .semibold, design: .monospaced)
                    : .system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(config.optionsInSingleColumn ? 1 : 2)
                .multilineTextAlignment(config.optionsInSingleColumn ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: config.optionsInSingleColumn ? .leading : .center)
                .padding(.horizontal, config.optionsInSingleColumn ? 18 : 10)
                .frame(height: config.optionsInSingleColumn ? 54 : 64)
                .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(borderColor, lineWidth: state == .neutral ? 1 : 2)
                }
                .shadow(color: state == .correct ? .green.opacity(0.4) : .clear, radius: 18, y: 3)
                .offset(x: shake ? -6 : 0)
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .disabled(state != .neutral)
        .animation(RestGameTheme.quickSpring, value: state)
        .onChange(of: state) { _, newState in
            guard newState == .wrong else { return }
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shake = false
            }
        }
    }

    private var background: Color {
        switch state {
        case .neutral: return .white.opacity(0.08)
        case .correct: return .green.opacity(0.35)
        case .wrong: return .red.opacity(0.3)
        case .dimmed: return .white.opacity(0.04)
        }
    }

    private var borderColor: Color {
        switch state {
        case .neutral: return .white.opacity(0.12)
        case .correct: return .green.opacity(0.8)
        case .wrong: return .red.opacity(0.7)
        case .dimmed: return .white.opacity(0.06)
        }
    }
}

// MARK: - Sheets

private struct ScenarioQuizLearnSheet: View {
    let config: ScenarioQuizConfig
    let challenge: ScenarioQuizChallenge
    let wasCorrect: Bool
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(wasCorrect ? .green : .orange)
                            Text(wasCorrect ? "Você acertou!" : "Quase. Revise abaixo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background((wasCorrect ? Color.green : Color.orange).opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("Resposta correta")
                            Text(challenge.answer)
                                .font(config.monospacedOptions
                                    ? .system(size: 20, weight: .bold, design: .monospaced)
                                    : .system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(config.accentLight)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        section(title: "Por quê?", body: challenge.explanation)

                        if let hint = challenge.hint {
                            section(title: "Dica", body: hint)
                        }

                        if let url = URL(string: challenge.reference) {
                            RestGameSecondaryButton(title: "Ver documentação") {
                                onReadMore?(url)
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 8)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider().overlay(Color.white.opacity(0.12))

                    RestGamePrimaryButton(title: "Continuar") {
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Entender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.45))
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ScenarioQuizIntroSheet: View {
    let config: ScenarioQuizConfig
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(config.introText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(config.introRows, id: \.self) { row in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(row.term)
                                        .font(config.monospacedOptions
                                            ? .system(.caption, design: .monospaced).weight(.bold)
                                            : .system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(config.accentLight)
                                        .frame(width: config.monospacedOptions ? 120 : 56, alignment: .leading)
                                    Text(row.detail)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }

                        Text(config.introFootnote)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        RestGameSecondaryButton(title: config.learnMoreTitle) {
                            onReadMore?(config.learnMoreURL)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Dica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Results

private struct ScenarioQuizResultsView: View {
    let config: ScenarioQuizConfig
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
                        .stroke(RestGameScoring.scoreColor(scorePercent).opacity(0.25), lineWidth: 10)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ringScale)

                    VStack(spacing: 4) {
                        Text("\(correctCount)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(RestGameScoring.scoreColor(scorePercent))
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
                                gameCenter.showLeaderboard(config.leaderboard)
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

    private var resultMessage: String {
        switch correctCount {
        case totalRounds: return config.perfectMessage
        case 8...: return config.goodMessage
        case 5...: return config.okMessage
        default: return config.lowMessage
        }
    }
}
