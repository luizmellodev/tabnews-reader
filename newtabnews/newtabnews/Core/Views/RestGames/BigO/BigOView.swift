import SwiftUI

private struct BigORevealSnapshot: Equatable {
    let challenge: BigOChallenge
    let wasCorrect: Bool
}

struct BigOView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(RestGameFreeModePolicy.storageKey) private var restGamesAllowFreeMode = false

    @State private var playMode: BigOPlayMode = .daily
    @State private var dailyViewModel = BigOViewModel(mode: .daily)
    @State private var freeViewModel = BigOViewModel(mode: .free)
    @State private var hasStartedFree = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.bigO)
    @State private var showIntroLearn = false
    @State private var showRevealLearn = false
    @State private var revealSnapshot: BigORevealSnapshot?

    var body: some View {
        @Bindable var activeVM = activeViewModel

        ZStack {
            RestGameBackground()

            switch activeViewModel.phase {
            case .playing, .revealing:
                playingBody(viewModel: activeVM)
            case .finished:
                if playMode == .daily {
                    BigODailyResultsView(
                        viewModel: dailyViewModel,
                        isFreeModeUnlocked: isFreeModeUnlocked,
                        isAllowed: restGamesAllowFreeMode,
                        onPlayFree: { selectMode(.free) },
                        onClose: { dismiss() }
                    )
                } else {
                    BigOFreeResultsView(
                        correctCount: freeViewModel.correctCount,
                        totalRounds: freeViewModel.totalRounds,
                        bestStreak: freeViewModel.bestStreak,
                        roundResults: freeViewModel.roundResults,
                        onPlayAgain: restartFree,
                        onClose: { dismiss() }
                    )
                }
            }

            if showOnboarding {
                RestGameOnboardingOverlay.bigO {
                    RestGameOnboarding.markSeen(.bigO)
                    showOnboarding = false
                    startIfReady()
                }
            }
        }
        .animation(RestGameTheme.spring, value: activeViewModel.phase)
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
            BigOIntroLearnSheet { url in
                openURL(url)
            }
        }
        .sheet(isPresented: $showRevealLearn, onDismiss: handleRevealSheetDismissed) {
            if let snapshot = revealSnapshot {
                BigOLearnSheet(
                    challenge: snapshot.challenge,
                    wasCorrect: snapshot.wasCorrect
                ) { url in
                    openURL(url)
                }
            }
        }
        .onChange(of: activeViewModel.phase) { _, phase in
            guard phase == .revealing, let round = activeViewModel.currentRoundData else { return }
            revealSnapshot = BigORevealSnapshot(
                challenge: round.challenge,
                wasCorrect: activeViewModel.wasCorrect
            )
            showRevealLearn = true
        }
    }

    private func handleRevealSheetDismissed() {
        guard activeViewModel.phase == .revealing else { return }
        activeViewModel.advanceAfterReveal()
        revealSnapshot = nil
    }

    private var activeViewModel: BigOViewModel {
        playMode == .daily ? dailyViewModel : freeViewModel
    }

    private var isFreeModeUnlocked: Bool {
        RestGameFreeModePolicy.isUnlocked(
            dailyComplete: dailyViewModel.isDailyComplete,
            isAllowed: restGamesAllowFreeMode
        )
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

    private func selectMode(_ mode: BigOPlayMode) {
        guard playMode != mode else { return }
        guard mode != .free || isFreeModeUnlocked else {
            RestGameFreeModePolicy.handleLockedAttempt(
                dailyComplete: dailyViewModel.isDailyComplete,
                isAllowed: restGamesAllowFreeMode
            )
            return
        }
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
        hasStartedFree = false
        freeViewModel = BigOViewModel(mode: .free)
        hasStartedFree = true
        freeViewModel.startGame()
    }

    @ViewBuilder
    private func playingBody(viewModel: BigOViewModel) -> some View {
        VStack(spacing: 0) {
            header

            if playMode == .daily && dailyViewModel.isDailyComplete && dailyViewModel.phase == .playing {
                BigODailyCompleteEmptyState(
                    isFreeModeUnlocked: isFreeModeUnlocked,
                    dailyComplete: dailyViewModel.isDailyComplete,
                    isAllowed: restGamesAllowFreeMode,
                    onPlayFree: { selectMode(.free) }
                )
                    .padding(.horizontal, 24)
                Spacer()
            } else if let round = viewModel.currentRoundData {
                Spacer(minLength: 12)

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

                BigOCodeCardView(
                    title: round.challenge.title,
                    snippet: round.challenge.snippet
                )
                .padding(.horizontal, 20)
                .id("\(viewModel.currentRound)-\(round.challenge.id)")

                Text("Qual a complexidade?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                BigOOptionsView(
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
                        .foregroundStyle(BigOTheme.accentLight)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(BigOTheme.accent.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(RestGameScaleButtonStyle())
                    .padding(.top, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 16)

                if viewModel.currentStreak >= 2 && viewModel.phase == .playing && playMode == .free {
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
                    .padding(.bottom, 24)
                }
            }

            Spacer(minLength: 8)
        }
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

            Text("Big O")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            BigOModeToggle(
                selection: playMode,
                isFreeUnlocked: isFreeModeUnlocked,
                onSelect: selectMode
            )
            .padding(.horizontal, 32)

            Text(modeSubtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 8)
    }

    private var modeSubtitle: String {
        RestGameFreeModePolicy.modeSubtitle(
            isFreeModeActive: playMode == .free,
            dailyComplete: dailyViewModel.isDailyComplete,
            isAllowed: restGamesAllowFreeMode,
            freeModeDetail: "10 desafios · lista separada do diário",
            dailyCompleteDetail: "Desafio de hoje concluído · modo livre liberado"
        )
    }
}

private struct BigOModeToggle: View {
    let selection: BigOPlayMode
    let isFreeUnlocked: Bool
    let onSelect: (BigOPlayMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            modeButton(.daily)
            modeButton(.free)
        }
        .padding(4)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private func modeButton(_ mode: BigOPlayMode) -> some View {
        let isSelected = selection == mode
        let isLocked = mode == .free && !isFreeUnlocked

        return Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.iconName)
                Text(mode.title)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? .black : .white.opacity(isLocked ? 0.35 : 0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct BigODailyCompleteEmptyState: View {
    let isFreeModeUnlocked: Bool
    let dailyComplete: Bool
    let isAllowed: Bool
    let onPlayFree: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(BigOTheme.accent)

            Text("Você já jogou o desafio de hoje")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            BigOCountdownLabel(prefix: "Próximo em")

            RestGameFreeModeButton(
                isUnlocked: isFreeModeUnlocked,
                dailyComplete: dailyComplete,
                isAllowed: isAllowed,
                onPlay: onPlayFree
            )
        }
        .padding(24)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct BigOCountdownLabel: View {
    let prefix: String
    var onDarkBackground = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(prefix) \(BigOSchedule.formattedRemaining(from: context.date))")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(onDarkBackground ? .white.opacity(0.72) : .secondary)
        }
    }
}

private struct BigODailyResultsView: View {
    let viewModel: BigOViewModel
    let isFreeModeUnlocked: Bool
    let isAllowed: Bool
    let onPlayFree: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            RestGamePhaseLabel(text: "Diário")

            Image(systemName: viewModel.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(viewModel.wasCorrect ? .green : .orange)

            Text(viewModel.wasCorrect ? "Complexidade certa!" : "Amanhã tem mais")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if let challenge = viewModel.currentRoundData?.challenge {
                Text(challenge.answer)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BigOTheme.accentLight)
            }

            BigOCountdownLabel(prefix: "Próximo desafio em")

            VStack(spacing: 12) {
                RestGameFreeModeButton(
                    isUnlocked: isFreeModeUnlocked,
                    dailyComplete: viewModel.isDailyComplete,
                    isAllowed: isAllowed,
                    onPlay: onPlayFree
                )
                RestGameSecondaryButton(title: "Voltar", action: onClose)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
    }
}

private struct BigOFreeResultsView: View {
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
                                gameCenter.showLeaderboard(.bigO)
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
        case totalRounds: return "Mestre da complexidade. 10/10."
        case 8...: return "Você leu muitos loops na vida."
        case 5...: return "Razoável — revise os padrões clássicos."
        default: return "Hora de abrir o material de estudo."
        }
    }
}

struct BigOPreview: View {
    var expanded = false
    @State private var highlightIndex = 0
    private let options = ["O(n)", "O(log n)", "O(n²)", "O(1)"]

    var body: some View {
        VStack(spacing: expanded ? 12 : 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
                    .frame(width: 28, height: 10)
                RoundedRectangle(cornerRadius: 6)
                    .fill(BigOTheme.accent.opacity(0.35))
                    .frame(width: 80, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option)
                        .font(expanded ? .caption.weight(.bold) : .caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(index == highlightIndex ? 1 : 0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, expanded ? 12 : 10)
                        .background(
                            (index == highlightIndex ? BigOTheme.accent : Color.white).opacity(index == highlightIndex ? 0.25 : 0.06),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: expanded ? .infinity : nil)
        .frame(height: expanded ? nil : 72)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeInOut(duration: 0.5)) {
                    highlightIndex = (highlightIndex + 1) % options.count
                }
            }
        }
    }
}
