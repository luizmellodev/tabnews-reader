import SwiftUI

struct DevWordleView: View {
    @State private var playMode: DevWordlePlayMode = .daily
    @State private var dailyViewModel = DevWordleViewModel(mode: .daily)
    @State private var freeViewModel = DevWordleViewModel(mode: .free)
    @State private var freeSession: DevWordleFreeSession?
    @State private var showResultSheet = false
    @State private var showFreeSessionSummary = false
    @State private var showConfetti = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.devWordle)

    var body: some View {
        ZStack {
            RestGameBackground(animated: false)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 16)

                boardArea
                    .padding(.horizontal, 16)

                Spacer(minLength: 16)

                hintBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                bottomArea
                    .padding(.horizontal, playMode == .daily && dailyViewModel.isRoundComplete ? 16 : 8)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showOnboarding {
                RestGameOnboardingOverlay.devWordle {
                    RestGameOnboarding.markSeen(.devWordle)
                    showOnboarding = false
                }
            }

            if showConfetti {
                GeometryReader { geometry in
                    ParticleSystemView(
                        configuration: .confetti,
                        origin: CGPoint(x: geometry.size.width / 2, y: 72)
                    )
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            if playMode == .free, !isFreeModeUnlocked {
                playMode = .daily
            }
            if playMode == .free {
                ensureFreeSession()
                if freeSession?.isComplete == true {
                    showFreeSessionSummary = true
                }
            }
        }
        .onChange(of: dailyViewModel.gameStatus) { oldStatus, status in
            guard playMode == .daily, oldStatus == .playing, status == .won else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showConfetti = false
                }
            }
        }
        .onChange(of: freeViewModel.gameStatus) { _, status in
            guard playMode == .free, status != .playing else { return }
            recordFreeRound(from: freeViewModel)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if freeSession?.isComplete == true {
                    showFreeSessionSummary = true
                } else {
                    showResultSheet = true
                }
            }
        }
        .sheet(isPresented: $showResultSheet) {
            DevWordleResultSheet(
                viewModel: activeViewModel,
                freeSession: freeSession,
                onNextFreeRound: startNextFreeRound
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFreeSessionSummary) {
            if let freeSession {
                DevWordleFreeSessionSummary(
                    session: freeSession,
                    onNewSession: startNewFreeSession
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var isFreeModeUnlocked: Bool {
        dailyViewModel.isRoundComplete
    }

    private var activeViewModel: DevWordleViewModel {
        playMode == .daily ? dailyViewModel : freeViewModel
    }

    private var showDailyCompleteEmptyState: Bool {
        playMode == .daily && dailyViewModel.isRoundComplete
    }

    @ViewBuilder
    private var boardArea: some View {
        ZStack {
            if playMode == .daily {
                if showDailyCompleteEmptyState {
                    DevWordleDailyCompleteEmptyState(viewModel: dailyViewModel)
                        .transition(.opacity)
                } else {
                    board(for: dailyViewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }

            if playMode == .free {
                board(for: freeViewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: playMode)
        .animation(.easeInOut(duration: 0.3), value: showDailyCompleteEmptyState)
    }

    private static let bottomSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)

    private static let bottomSlideTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )

    @ViewBuilder
    private var bottomArea: some View {
        ZStack {
            if showDailyCompleteEmptyState {
                DevWordleDailyCompleteFooter(
                    viewModel: dailyViewModel,
                    onPlayFree: { selectMode(.free) }
                )
                .transition(Self.bottomSlideTransition)
            }

            if !showDailyCompleteEmptyState {
                DevWordleKeyboardView(
                    keyboardStates: activeViewModel.keyboardStates,
                    isEnabled: !activeViewModel.isRoundComplete,
                    onLetter: { activeViewModel.appendLetter($0) },
                    onDelete: { activeViewModel.deleteLetter() },
                    onSubmit: { activeViewModel.submitGuess() }
                )
                .id("\(playMode)-\(activeViewModel.sessionId)")
                .transition(Self.bottomSlideTransition)
            }
        }
        .animation(Self.bottomSpring, value: showDailyCompleteEmptyState)
        .animation(Self.bottomSpring, value: playMode)
    }

    @ViewBuilder
    private func board(for viewModel: DevWordleViewModel) -> some View {
        DevWordleBoardView(
            rows: viewModel.rows,
            currentRowIndex: viewModel.currentRowIndex,
            currentGuess: viewModel.currentGuess,
            revealedRows: viewModel.revealedRows,
            shakeRow: viewModel.shakeRow
        )
        .id(viewModel.sessionId)
    }

    private func selectMode(_ mode: DevWordlePlayMode) {
        guard playMode != mode else { return }
        guard mode != .free || isFreeModeUnlocked else {
            RestFeedbackManager.shared.scoreReveal(score: 2)
            return
        }
        showResultSheet = false
        showConfetti = false
        if mode == .free {
            ensureFreeSession()
            if freeSession?.isComplete == true {
                showFreeSessionSummary = true
            }
        }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            playMode = mode
        }
    }

    private func ensureFreeSession() {
        if let saved = DevWordleStorage.shared.loadFreeSession() {
            freeSession = saved
            return
        }

        let session = DevWordleFreeSession.newSession()
        freeSession = session
        DevWordleStorage.shared.saveFreeSession(session)
    }

    private func recordFreeRound(from viewModel: DevWordleViewModel) {
        guard var session = freeSession else { return }
        guard let attempts = viewModel.completedAttemptCount else { return }
        guard session.results.last?.word != viewModel.targetWord else { return }

        session.results.append(DevWordleFreeRoundResult(
            word: viewModel.targetWord,
            attempts: attempts,
            won: viewModel.gameStatus == .won
        ))
        freeSession = session
        DevWordleStorage.shared.saveFreeSession(session)
    }

    private func startNextFreeRound() {
        let previousWord = freeViewModel.targetWord
        freeViewModel.clearSavedFreeState()
        showResultSheet = false
        playMode = .free
        var excluded = Set(freeSession?.results.map(\.word) ?? [])
        excluded.insert(previousWord)
        freeViewModel = DevWordleViewModel(mode: .free, excludeWords: excluded, forceFresh: true)
    }

    private func startNewFreeSession() {
        DevWordleStorage.shared.clearFreeSession()
        let session = DevWordleFreeSession.newSession()
        freeSession = session
        DevWordleStorage.shared.saveFreeSession(session)
        showFreeSessionSummary = false
        freeViewModel.clearSavedFreeState()
        freeViewModel = DevWordleViewModel(mode: .free, forceFresh: true)
        playMode = .free
    }

    @ViewBuilder
    private var hintBanner: some View {
        if showDailyCompleteEmptyState {
            EmptyView()
        } else if let hintText = activeViewModel.hintText {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color(red: 0.78, green: 0.68, blue: 0.30))
                Text(hintText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .id(activeViewModel.sessionId)
        } else if activeViewModel.showHintOffer {
            Button {
                activeViewModel.acceptHint()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                    Text("Aceita uma dica?")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color(red: 0.78, green: 0.68, blue: 0.30))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .id(activeViewModel.sessionId)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("DevWordle")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            DevWordleModeToggle(
                selection: playMode,
                isFreeUnlocked: isFreeModeUnlocked,
                onSelect: selectMode
            )
            .padding(.horizontal, 32)

            Text(modeSubtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .animation(.easeInOut(duration: 0.25), value: modeSubtitle)

            if playMode == .free, let freeSession {
                HStack(spacing: 16) {
                    Text("Palavra \(min(freeSession.wordsPlayed + 1, DevWordleFreeSession.targetWordCount))/\(DevWordleFreeSession.targetWordCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    DevWordleSessionTimerLabel(startTime: freeSession.startTime)
                }
            }
        }
        .padding(.top, 12)
    }

    private var modeSubtitle: String {
        if playMode == .free {
            return "Termos de programação · lista separada do diário"
        }
        if showDailyCompleteEmptyState {
            return "Desafio de hoje concluído · modo livre liberado"
        }
        if isFreeModeUnlocked {
            return "Termos de programação · desafio do dia"
        }
        return "Complete o diário para liberar o modo livre"
    }
}

private struct DevWordleModeToggle: View {
    let selection: DevWordlePlayMode
    let isFreeUnlocked: Bool
    let onSelect: (DevWordlePlayMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment(.daily, locked: false)
            segment(.free, locked: !isFreeUnlocked)
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func segment(_ mode: DevWordlePlayMode, locked: Bool) -> some View {
        let isSelected = selection == mode
        let isDisabled = locked && mode == .free

        return Button {
            onSelect(mode)
            if !isDisabled {
                RestFeedbackManager.shared.tapHaptic()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isDisabled ? "lock.fill" : mode.iconName)
                    .font(.caption.weight(.bold))
                Text(mode.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(foregroundColor(isSelected: isSelected, isDisabled: isDisabled))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
            .background(isSelected ? Color.white.opacity(0.18) : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func foregroundColor(isSelected: Bool, isDisabled: Bool) -> Color {
        if isDisabled { return .white.opacity(0.22) }
        return isSelected ? .white : .white.opacity(0.42)
    }
}

private struct DevWordleSessionTimerLabel: View {
    let startTime: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(DevWordleFreeSession.formattedDuration(max(0, context.date.timeIntervalSince(startTime))))
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct DevWordleSearchButton: View {
    let term: String
    var onDarkBackground = false
    let onSearch: (String) -> Void

    var body: some View {
        Button {
            RestFeedbackManager.shared.tapHaptic()
            onSearch(term)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Pesquisar \"\(term)\"")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(onDarkBackground ? .white.opacity(0.9) : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                onDarkBackground ? Color.white.opacity(0.10) : Color.primary.opacity(0.08),
                in: Capsule()
            )
            .overlay {
                if onDarkBackground {
                    Capsule().stroke(.white.opacity(0.14), lineWidth: 1)
                }
            }
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }
}

private struct DevWordleResultSheet: View {
    let viewModel: DevWordleViewModel
    let freeSession: DevWordleFreeSession?
    var onNextFreeRound: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.gameStatus == .won ? "Nice!" : "Foi quase")
                .font(.title.weight(.bold))

            if viewModel.gameStatus == .won, let attempt = viewModel.winningAttemptNumber {
                Text("Você acertou em \(attempt)/6")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("A palavra era \(viewModel.targetWord)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DevWordleSearchButton(term: viewModel.targetWord) { term in
                guard let url = RestGameProgrammingSearch.programmingSearchURL(for: term) else { return }
                openURL(url)
            }

            ShareLink(item: viewModel.shareText) {
                Text("Compartilhar resultado")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary.opacity(0.08), in: Capsule())
            }

            if viewModel.mode == .daily, viewModel.gameStatus == .won, gameCenter.isAuthenticated {
                Button("Ver ranking") {
                    gameCenter.showLeaderboard(.devWordle)
                }
                .font(.headline)
            }

            if viewModel.mode == .free {
                Button(nextFreeRoundTitle) {
                    dismiss()
                    onNextFreeRound?()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.42, green: 0.67, blue: 0.36), in: Capsule())
            } else {
                DevWordleCountdownLabel(onDarkBackground: false)
            }

            Button("Fechar") { dismiss() }
                .font(.headline)
        }
        .padding(24)
    }

    private var nextFreeRoundTitle: String {
        let completed = freeSession?.wordsPlayed ?? 0
        return "Próxima palavra (\(completed)/\(DevWordleFreeSession.targetWordCount))"
    }
}

private struct DevWordleFreeSessionSummary: View {
    let session: DevWordleFreeSession
    let onNewSession: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Sessão completa!")
                .font(.title.weight(.bold))

            VStack(spacing: 8) {
                Text("Completou 5 palavras em \(DevWordleFreeSession.formattedDuration(session.elapsedTime()))")
                Text("Média de \(formattedAverageAttempts) tentativas por palavra")
                Text("Acertou \(session.wins)/\(DevWordleFreeSession.targetWordCount)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button("Nova partida") {
                dismiss()
                onNewSession()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(red: 0.42, green: 0.67, blue: 0.36), in: Capsule())

            Button("Fechar") { dismiss() }
                .font(.headline)
        }
        .padding(24)
    }

    private var formattedAverageAttempts: String {
        let average = session.averageAttempts
        if average == floor(average) {
            return String(format: "%.0f", average)
        }
        return String(format: "%.1f", average)
    }
}

private struct DevWordleDailyCompleteEmptyState: View {
    let viewModel: DevWordleViewModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Image(systemName: viewModel.gameStatus == .won ? "checkmark.circle" : "moon.zzz.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(viewModel.gameStatus == .won
                    ? Color(red: 0.42, green: 0.67, blue: 0.36)
                    : .white.opacity(0.45))

            VStack(spacing: 8) {
                Text(viewModel.gameStatus == .won ? "Nice!" : "Foi quase")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                if viewModel.gameStatus == .won, let attempt = viewModel.winningAttemptNumber {
                    Text("Você acertou em \(attempt)/6")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                } else if viewModel.gameStatus == .lost {
                    Text("A palavra era")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }

            DevWordleFeaturedWordView(word: viewModel.targetWord)

            DevWordleCountdownLabel(prefix: "Próximo desafio em")

            Text(viewModel.shareText.components(separatedBy: "\n").dropFirst(2).joined(separator: "\n"))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DevWordleFeaturedWordView: View {
    let word: String

    private let tileColor = Color(red: 0.42, green: 0.67, blue: 0.36)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(word.uppercased().enumerated()), id: \.offset) { _, letter in
                Text(String(letter))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 56)
                    .background(tileColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.uppercased())
    }
}

private struct DevWordleDailyCompleteFooter: View {
    let viewModel: DevWordleViewModel
    let onPlayFree: () -> Void
    @Environment(\.openURL) private var openURL
    @StateObject private var gameCenter = GameCenterManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onPlayFree) {
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                    Text("Jogar modo livre")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.42, green: 0.67, blue: 0.36), in: Capsule())
            }
            .buttonStyle(RestGameScaleButtonStyle())

            HStack(spacing: 8) {
                DevWordleFooterAction(
                    accessibilityLabel: "O que é \(viewModel.targetWord) na programação"
                ) {
                    guard let url = RestGameProgrammingSearch.programmingSearchURL(for: viewModel.targetWord) else { return }
                    openURL(url)
                } label: {
                    DevWordleFooterWhatIsLabel(word: viewModel.targetWord)
                }

                ShareLink(item: viewModel.shareText) {
                    DevWordleFooterActionLabel(icon: "square.and.arrow.up", title: "Compartilhar")
                }

                if viewModel.gameStatus == .won, gameCenter.isAuthenticated {
                    DevWordleIconFooterAction(icon: "trophy.fill", title: "Ranking") {
                        gameCenter.showLeaderboard(.devWordle)
                    }
                }
            }
        }
    }
}

private struct DevWordleFooterWhatIsLabel: View {
    let word: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.book.closed")
                .font(.body.weight(.semibold))

            VStack(spacing: 1) {
                Text("O que é")
                Text("\(word.uppercased())?")
                    .fontWeight(.bold)
            }
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DevWordleFooterActionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DevWordleFooterAction<Label: View>: View {
    var accessibilityLabel: String?
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            RestFeedbackManager.shared.tapHaptic()
            action()
        } label: {
            label()
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? "")
    }
}

private struct DevWordleIconFooterAction: View {
    let icon: String
    let title: String
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        DevWordleFooterAction(accessibilityLabel: accessibilityLabel, action: action) {
            DevWordleFooterActionLabel(icon: icon, title: title)
        }
    }
}

struct DevWordleCountdownLabel: View {
    var prefix: String = "Próxima palavra em"
    var onDarkBackground = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(prefix) \(DevWordleSchedule.formattedRemaining(from: context.date))")
                .font(onDarkBackground ? .caption2.weight(.semibold) : .subheadline)
                .monospacedDigit()
                .foregroundStyle(onDarkBackground ? .white.opacity(0.72) : .secondary)
        }
    }
}
