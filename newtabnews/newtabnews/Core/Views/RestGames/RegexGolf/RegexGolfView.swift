import SwiftUI

enum RegexGolfTheme {
    static let accent = Color(red: 0.98, green: 0.76, blue: 0.18)
    static let accentLight = Color(red: 1.0, green: 0.86, blue: 0.45)
    static let pass = Color(red: 0.36, green: 0.85, blue: 0.5)
    static let fail = Color(red: 1.0, green: 0.42, blue: 0.42)
}

struct RegexGolfView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(RestGameFreeModePolicy.storageKey) private var restGamesAllowFreeMode = false

    @State private var playMode: ScenarioQuizPlayMode = .daily
    @State private var dailyViewModel = RegexGolfViewModel(mode: .daily)
    @State private var freeViewModel = RegexGolfViewModel(mode: .free)
    @State private var hasStartedFree = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.regexGolf)
    @State private var showIntro = false
    @State private var showResult = false
    @State private var showGiveUpConfirm = false
    @State private var showFreeModeLockedHint = false

    var body: some View {
        ZStack {
            RestGameBackground(animated: false)

            if playMode == .free, freeViewModel.phase == .finished {
                RegexGolfFreeResultsView(
                    scores: freeViewModel.roundScores,
                    onPlayAgain: restartFree,
                    onClose: { dismiss() }
                )
            } else {
                playingBody(viewModel: activeViewModel)
            }

            if showOnboarding {
                RestGameOnboardingOverlay.regexGolf {
                    RestGameOnboarding.markSeen(.regexGolf)
                    showOnboarding = false
                    startIfReady()
                }
            }
        }
        .animation(RestGameTheme.spring, value: playMode)
        .toolbar {
            // Na barra de navegação para sobrar espaço vertical para o teclado
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showIntro = true
                } label: {
                    Label("Dica", systemImage: "lightbulb.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.bold))
                }
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            if playMode == .free, !isFreeModeUnlocked {
                playMode = .daily
            }
            startIfReady()
        }
        .sheet(isPresented: $showIntro) {
            RegexGolfIntroSheet { openURL($0) }
        }
        .sheet(isPresented: $showResult, onDismiss: {
            activeViewModel.advanceAfterReveal()
        }) {
            if let puzzle = activeViewModel.puzzle {
                RegexGolfResultSheet(
                    puzzle: puzzle,
                    pattern: activeViewModel.pattern,
                    solved: activeViewModel.lastRoundSolved,
                    score: activeViewModel.lastRoundScore
                )
            }
        }
        .onChange(of: activeViewModel.phase) { _, phase in
            guard phase == .revealing else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if activeViewModel.phase == .revealing {
                    showResult = true
                }
            }
        }
        .alert("Desistir deste puzzle?", isPresented: $showGiveUpConfirm) {
            Button("Continuar tentando", role: .cancel) { }
            Button("Ver solução", role: .destructive) {
                activeViewModel.giveUp()
            }
        } message: {
            Text(playMode == .daily ? "O desafio de hoje conta como não resolvido." : "Este round vale 0 pontos.")
        }
    }

    private var activeViewModel: RegexGolfViewModel {
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
        if mode == .free, !hasStartedFree {
            hasStartedFree = true
            freeViewModel.startGame()
        }
        withAnimation(RestGameTheme.spring) {
            playMode = mode
        }
    }

    private func restartFree() {
        freeViewModel = RegexGolfViewModel(mode: .free)
        hasStartedFree = true
        freeViewModel.startGame()
    }

    // MARK: - Layout

    @ViewBuilder
    private func playingBody(viewModel: RegexGolfViewModel) -> some View {
        VStack(spacing: 0) {
            header

            if showDailyCompleteEmptyState {
                Spacer()
                RestGameDailyCompleteEmptyState(wasCorrect: dailyViewModel.lastRoundSolved) {
                    BigOCountdownLabel(prefix: "Próximo puzzle em")
                }
                Spacer()
            } else if let puzzle = viewModel.puzzle {
                ScrollView(showsIndicators: false) {
                    puzzleContent(viewModel: viewModel, puzzle: puzzle)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                }

                inputBar(viewModel: viewModel, puzzle: puzzle)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func puzzleContent(viewModel: RegexGolfViewModel, puzzle: RegexGolfPuzzle) -> some View {
        let evaluation = viewModel.evaluation ?? .empty(for: puzzle)

        VStack(alignment: .leading, spacing: 16) {
            if playMode == .free {
                HStack {
                    RoundIndicatorView(currentRound: viewModel.currentRound, totalRounds: viewModel.totalRounds)
                    Spacer()
                    Text("\(viewModel.totalScore) pts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(puzzle.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(puzzle.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 12) {
                RegexGolfWordColumn(
                    title: "Deve casar",
                    systemImage: "checkmark",
                    words: puzzle.match,
                    ranges: evaluation.matchRanges,
                    wantsMatch: true
                )
                RegexGolfWordColumn(
                    title: "Não pode",
                    systemImage: "xmark",
                    words: puzzle.noMatch,
                    ranges: evaluation.noMatchRanges,
                    wantsMatch: false
                )
            }
        }
    }

    @ViewBuilder
    private func inputBar(viewModel: RegexGolfViewModel, puzzle: RegexGolfPuzzle) -> some View {
        let evaluation = viewModel.evaluation ?? .empty(for: puzzle)
        let isInvalid = !viewModel.pattern.isEmpty && !evaluation.isValid
        let isPlaying = viewModel.phase == .playing

        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("/")
                    .foregroundStyle(RegexGolfTheme.accent)
                RegexGolfPatternDisplay(pattern: viewModel.pattern, isActive: isPlaying)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("/")
                    .foregroundStyle(RegexGolfTheme.accent)

                Text("\(viewModel.pattern.count)/\(puzzle.par)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.pattern.count <= puzzle.par ? RegexGolfTheme.pass : .white.opacity(0.55))
                    .accessibilityLabel("\(viewModel.pattern.count) caracteres, par \(puzzle.par)")
            }
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isInvalid ? RegexGolfTheme.fail : (evaluation.isSolved ? RegexGolfTheme.pass : .white.opacity(0.12)), lineWidth: isInvalid || evaluation.isSolved ? 2 : 1)
            }
            .animation(RestGameTheme.quickSpring, value: evaluation.isSolved)

            if isInvalid {
                Text("Regex inválida")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RegexGolfTheme.fail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            RegexGolfKeyboard(
                onInsert: { viewModel.append($0) },
                onDelete: { viewModel.deleteLast() },
                onClear: { viewModel.updatePattern("") }
            )
            .disabled(!isPlaying)
            .opacity(isPlaying ? 1 : 0.5)

            HStack(spacing: 10) {
                Button {
                    showGiveUpConfirm = true
                } label: {
                    Text("Desistir")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                }
                .disabled(!isPlaying)

                Button {
                    viewModel.submit()
                } label: {
                    Text(evaluation.isSolved ? "Enviar" : "\(evaluation.matchedCount)/\(puzzle.match.count) casando · \(evaluation.leakedCount) vazando")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(evaluation.isSolved ? .black : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(evaluation.isSolved ? RegexGolfTheme.accent : .white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(RestGameScaleButtonStyle())
                .disabled(!evaluation.isSolved || !isPlaying)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial.opacity(0.6))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Regex Golf")
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
                freeModeDetail: "5 puzzles · quanto menor a regex, mais pontos",
                dailyCompleteDetail: "Puzzle de hoje concluído · modo livre liberado",
                showLockedHint: showFreeModeLockedHint
            )
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Words

private struct RegexGolfWordColumn: View {
    let title: String
    let systemImage: String
    let words: [String]
    let ranges: [NSRange?]
    let wantsMatch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(wantsMatch ? RegexGolfTheme.pass : RegexGolfTheme.fail)

            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let range = index < ranges.count ? ranges[index] : nil
                let matched = range != nil
                let isGood = matched == wantsMatch

                HStack(spacing: 6) {
                    Image(systemName: isGood ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(isGood ? RegexGolfTheme.pass : (matched ? RegexGolfTheme.fail : .white.opacity(0.25)))

                    Text(highlighted(word, range: range))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (matched && !wantsMatch ? RegexGolfTheme.fail : Color.white).opacity(matched && !wantsMatch ? 0.15 : 0.05),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .animation(RestGameTheme.quickSpring, value: matched)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(word), \(matched ? "casa" : "não casa")")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Destaca o trecho que a regex casou
    private func highlighted(_ word: String, range: NSRange?) -> AttributedString {
        var result = AttributedString(word)
        result.foregroundColor = .white.opacity(0.85)

        guard let range, let swiftRange = Range(range, in: word),
              let start = AttributedString.Index(swiftRange.lowerBound, within: result),
              let end = AttributedString.Index(swiftRange.upperBound, within: result) else {
            return result
        }

        result[start..<end].foregroundColor = wantsMatch ? RegexGolfTheme.accentLight : RegexGolfTheme.fail
        result[start..<end].underlineStyle = .single
        return result
    }
}

// MARK: - Input

/// Mostra a regex digitada com um cursor piscando (o teclado é próprio, sem TextField)
private struct RegexGolfPatternDisplay: View {
    let pattern: String
    let isActive: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    if !pattern.isEmpty {
                        Text(pattern)
                            .foregroundStyle(.white)
                    }

                    if isActive {
                        cursor
                            .id("cursor")
                    }

                    if pattern.isEmpty {
                        Text("sua regex")
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .lineLimit(1)
            }
            .onChange(of: pattern) {
                proxy.scrollTo("cursor", anchor: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pattern.isEmpty ? "Regex vazia" : "Regex: \(pattern)")
    }

    private var cursor: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let visible = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(RegexGolfTheme.accent)
                .frame(width: 2, height: 20)
                .opacity(visible ? 1 : 0)
        }
    }
}

// MARK: - Keyboard

/// Teclado próprio: duas linhas fixas de regex + letras (com shift) ou números/símbolos
private struct RegexGolfKeyboard: View {
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let onClear: () -> Void

    @State private var isShifted = false
    @State private var showsSymbols = false

    private let spacing: CGFloat = 5
    private let keyHeight: CGFloat = 36

    private let regexRows: [[String]] = [
        ["^", "$", ".", "*", "+", "?", "|", "\\", "(", ")"],
        ["[", "]", "{", "}", "-", ",", "\\d", "\\w", "\\s", "\\b"]
    ]
    private let letterRows: [[String]] = [
        Array("qwertyuiop").map(String.init),
        Array("asdfghjkl").map(String.init),
        Array("zxcvbnm").map(String.init)
    ]
    private let symbolRows: [[String]] = [
        Array("1234567890").map(String.init),
        ["/", ":", ";", "=", "_", "@", "#", "<", ">"],
        ["'", "\"", "!", "%", "&", "~", " "]
    ]

    var body: some View {
        GeometryReader { geometry in
            let keyWidth = (geometry.size.width - spacing * 9) / 10
            let rows = showsSymbols ? symbolRows : letterRows

            VStack(spacing: spacing) {
                ForEach(regexRows, id: \.self) { row in
                    keyRow(row, keyWidth: keyWidth, style: .regex)
                }

                keyRow(rows[0], keyWidth: keyWidth, style: .plain)
                keyRow(rows[1], keyWidth: keyWidth, style: .plain)

                HStack(spacing: spacing) {
                    specialKey(width: keyWidth, label: Text(showsSymbols ? "abc" : "123").font(.system(size: 12, weight: .bold)), accessibility: showsSymbols ? "Letras" : "Números e símbolos") {
                        showsSymbols.toggle()
                        isShifted = false
                    }

                    if showsSymbols {
                        Color.clear.frame(width: keyWidth, height: keyHeight)
                    } else {
                        specialKey(width: keyWidth, label: Image(systemName: isShifted ? "shift.fill" : "shift"), accessibility: "Maiúscula") {
                            isShifted.toggle()
                        }
                    }

                    ForEach(rows[2], id: \.self) { key in
                        characterKey(key, width: keyWidth, style: .plain, title: key == " " ? "␣" : nil)
                    }

                    // Segurar o apagar limpa a regex inteira
                    specialKey(width: keyWidth * CGFloat(8 - rows[2].count) + spacing * CGFloat(7 - rows[2].count), label: Image(systemName: "delete.left"), accessibility: "Apagar (segure para limpar)") {
                        onDelete()
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            RestFeedbackManager.shared.tap()
                            onClear()
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: keyHeight * 5 + spacing * 4)
    }

    private enum KeyStyle {
        case regex
        case plain
    }

    private func keyRow(_ keys: [String], keyWidth: CGFloat, style: KeyStyle) -> some View {
        HStack(spacing: spacing) {
            ForEach(keys, id: \.self) { key in
                characterKey(key, width: keyWidth, style: style)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func characterKey(_ key: String, width: CGFloat, style: KeyStyle, title: String? = nil) -> some View {
        let appliesShift = style == .plain && !showsSymbols
        let label = isShifted && appliesShift ? key.uppercased() : key

        return Button {
            RestFeedbackManager.shared.tap()
            // Lê o shift no momento do toque (não no último render) para digitação rápida
            let uppercase = isShifted && appliesShift
            onInsert(uppercase ? key.uppercased() : key)
            if uppercase {
                isShifted = false
            }
        } label: {
            Text(title ?? label)
                .font(.system(size: title == nil ? 17 : 14, weight: style == .regex ? .bold : .medium, design: .monospaced))
                .foregroundStyle(style == .regex ? RegexGolfTheme.accentLight : .white)
                .frame(width: width, height: keyHeight)
                .background(
                    style == .regex ? RegexGolfTheme.accent.opacity(0.16) : Color.white.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .accessibilityLabel(title ?? "Inserir \(label)")
    }

    private func specialKey<Label: View>(width: CGFloat, label: Label, accessibility: String, action: @escaping () -> Void) -> some View {
        Button {
            RestFeedbackManager.shared.tap()
            action()
        } label: {
            label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: width, height: keyHeight)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Sheets

private struct RegexGolfResultSheet: View {
    let puzzle: RegexGolfPuzzle
    let pattern: String
    let solved: Bool
    let score: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            Image(systemName: solved ? "checkmark.circle.fill" : "flag.fill")
                                .foregroundStyle(solved ? RegexGolfTheme.pass : .orange)
                            Text(resultTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if solved {
                                Text("+\(score)")
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(RegexGolfTheme.accent)
                                    .monospacedDigit()
                            }
                        }
                        .padding(14)
                        .background((solved ? RegexGolfTheme.pass : Color.orange).opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if solved {
                            regexBlock(title: "Sua regex · \(pattern.count) caracteres", regex: pattern)
                        }

                        regexBlock(title: "Solução de referência · par \(puzzle.par)", regex: puzzle.solution)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("COMO FUNCIONA")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.45))
                            Text(puzzle.explanation)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RestGamePrimaryButton(title: "Continuar") { dismiss() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle(solved ? "Resolvido" : "Solução")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var resultTitle: String {
        guard solved else { return "Fica pra próxima" }
        if pattern.count < puzzle.par { return "Abaixo do par! Eagle." }
        if pattern.count == puzzle.par { return "No par. Muito bom!" }
        return "Resolvido!"
    }

    private func regexBlock(title: String, regex: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            Text("/\(regex)/")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(RegexGolfTheme.accentLight)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct RegexGolfIntroSheet: View {
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private let rows: [(String, String)] = [
        ("^  $", "Início e fim do texto"),
        (".", "Qualquer caractere"),
        ("\\d  \\w  \\s", "Dígito, letra/número/_, espaço"),
        ("[abc]  [^abc]", "Um destes / nenhum destes"),
        ("a|b", "a ou b"),
        ("*  +  ?", "0 ou mais, 1 ou mais, opcional"),
        ("{2,4}", "De 2 a 4 repetições"),
        ("(ab)\\1", "Grupo e repetição do grupo")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Escreva uma regex que case com todas as palavras da esquerda e com nenhuma da direita. Ela só precisa encontrar um trecho: use ^ e $ para exigir a palavra inteira.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(rows, id: \.0) { term, detail in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(term)
                                        .font(.system(.caption, design: .monospaced).weight(.bold))
                                        .foregroundStyle(RegexGolfTheme.accentLight)
                                        .frame(width: 110, alignment: .leading)
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }

                        Text("Como no golfe: o par é o tamanho de uma boa solução. Abaixo do par vale pontos extras.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        RestGameSecondaryButton(title: "Guia de regex na MDN") {
                            if let url = URL(string: "https://developer.mozilla.org/pt-BR/docs/Web/JavaScript/Guide/Regular_expressions") {
                                onReadMore?(url)
                            }
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

private struct RegexGolfFreeResultsView: View {
    let scores: [Int]
    let onPlayAgain: () -> Void
    let onClose: () -> Void

    @StateObject private var gameCenter = GameCenterManager.shared
    @State private var showContent = false

    private var total: Int { scores.reduce(0, +) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                RestGamePhaseLabel(text: "Resultado")

                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(RegexGolfTheme.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("pontos")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 8) {
                    ForEach(Array(scores.enumerated()), id: \.offset) { _, score in
                        Text(score > 0 ? "\(score)" : "—")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(score > 0 ? .black : .white.opacity(0.5))
                            .frame(width: 46, height: 30)
                            .background(score > 0 ? RegexGolfTheme.accent.opacity(score >= 100 ? 1 : 0.6) : .white.opacity(0.08), in: Capsule())
                    }
                }

                if showContent {
                    VStack(spacing: 12) {
                        RestGamePrimaryButton(title: "Jogar de novo", action: onPlayAgain)
                        if gameCenter.isAuthenticated {
                            RestGameSecondaryButton(title: "Ver ranking") {
                                gameCenter.showLeaderboard(.regexGolf)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(RestGameTheme.spring) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Hub preview

/// Preview do hub: a regex sendo "digitada" e as palavras acendendo
struct RegexGolfHubPreview: View {
    private let words = ["main.swift", "app.swift", "README.md"]
    private let pattern = "\\.swift$"
    @State private var typed = 0

    var body: some View {
        // Lado a lado no card largo; empilhado no card quadrado da grade
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                patternText
                    .frame(minWidth: 110, alignment: .leading)
                wordList
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                patternText
                wordList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            while !Task.isCancelled {
                typed = 0
                for index in 1...pattern.count {
                    try? await Task.sleep(for: .milliseconds(140))
                    withAnimation(.easeOut(duration: 0.12)) { typed = index }
                }
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
    }

    private var patternText: some View {
        Text("/" + String(pattern.prefix(typed)) + "/")
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(RegexGolfTheme.accentLight)
    }

    private var wordList: some View {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let lit = typed == pattern.count && index < 2
                    let blocked = typed == pattern.count && index == 2
                    HStack(spacing: 5) {
                        Image(systemName: lit ? "checkmark.circle.fill" : (blocked ? "xmark.circle" : "circle"))
                            .font(.system(size: 9))
                            .foregroundStyle(lit ? RegexGolfTheme.pass : (blocked ? RegexGolfTheme.fail : .white.opacity(0.3)))
                        Text(word)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(lit ? 0.95 : 0.45))
                    }
                }
            }
    }
}
