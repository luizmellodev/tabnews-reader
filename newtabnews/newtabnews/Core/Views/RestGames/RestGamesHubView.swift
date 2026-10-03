import SwiftUI

private enum HubDestination: Hashable {
    case devWordle
    case devLeet
    case devSpot
    case bigO
    case algoSpot
    case httpStatus
    case gitRescue
    case regexGolf
    case arcade(RestGameType)
}

struct RestGamesHubView: View {
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    @State private var destination: HubDestination?
    @State private var dailySummary = DevWordleViewModel.todaySummary()
    @State private var bigOSummary = BigOViewModel.todaySummary()
    @State private var algoSpotSummary = AlgoSpotViewModel.todaySummary()
    @State private var httpStatusSummary = ScenarioQuizViewModel.todaySummary(for: .httpStatus)
    @State private var gitRescueSummary = ScenarioQuizViewModel.todaySummary(for: .gitRescue)
    @State private var regexGolfSummary = RegexGolfViewModel.todaySummary()
    @State private var weeklySummary = DevLeetHubSummary.current()
    @State private var showLeaderboards = false
    @State private var hubStreak = RestGamesHubStreak.current

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        hubHeader

                        VStack(alignment: .leading, spacing: 12) {
                            if let next = nextDaily {
                                sectionTitle("Continuar")
                                dailyTile(next, large: true)
                            } else {
                                dailyCompleteBanner
                            }

                            if !gridDailies.isEmpty {
                                sectionTitle("Diários de hoje")
                                    .padding(.top, 8)

                                // Pares lado a lado; se sobrar um, ele ocupa a linha inteira
                                VStack(spacing: 12) {
                                    ForEach(Array(stride(from: 0, to: gridDailies.count, by: 2)), id: \.self) { index in
                                        if index + 1 < gridDailies.count {
                                            HStack(spacing: 12) {
                                                dailyTile(gridDailies[index], large: false)
                                                dailyTile(gridDailies[index + 1], large: false)
                                            }
                                        } else {
                                            dailyTile(gridDailies[index], large: false, wide: true)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Mais jogos")
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    hubTile(
                                        title: "DevLeet",
                                        accent: .orange,
                                        destination: .devLeet,
                                        badge: { devLeetStatusBadge }
                                    ) {
                                        DevLeetHubPreview(summary: weeklySummary, compact: true)
                                    }
                                    .frame(width: 168)

                                    hubTile(
                                        title: "DevSpot",
                                        accent: .mint,
                                        destination: .devSpot,
                                        previewAlignment: .bottom
                                    ) {
                                        DevSpotPreview()
                                    }
                                    .frame(width: 168)

                                    hubTile(
                                        title: "Color Match",
                                        accent: .pink,
                                        destination: .arcade(.color)
                                    ) {
                                        ColorMatchHubPreview()
                                    }
                                    .frame(width: 168)

                                    hubTile(
                                        title: "Sound Match",
                                        accent: .cyan,
                                        destination: .arcade(.sound),
                                        immersivePreview: true
                                    ) {
                                        SoundMatchHubPreview()
                                    }
                                    .frame(width: 168)
                                }
                                .padding(.horizontal, 20)
                            }
                            .scrollClipDisabled()
                        }
                        .padding(.horizontal, -20)

                        RestGameFreeModeHubSetting()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .animation(RestGameTheme.spring, value: nextDaily)
                }
                .scrollEdgeEffectStyle(.hard, for: .top)
            }
            // safeAreaBar (e não safeAreaInset) para ganhar o efeito de borda do iOS 26:
            // o conteúdo esmaece por baixo dos botões em vez de passar por cima do relógio
            .safeAreaBar(edge: .top, spacing: 0) {
                if destination == nil {
                    HStack {
                        rankingsButton
                        Spacer()
                        closeButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .navigationDestination(item: $destination) { item in
                switch item {
                case .devWordle:
                    DevWordleView()
                case .devLeet:
                    DevLeetView()
                case .devSpot:
                    DevSpotView()
                case .bigO:
                    BigOView()
                case .algoSpot:
                    AlgoSpotView()
                case .httpStatus:
                    HttpStatusView()
                case .gitRescue:
                    GitRescueView()
                case .regexGolf:
                    RegexGolfView()
                case .arcade(let gameType):
                    switch gameType {
                    case .color:
                        ColorMatchView()
                    case .sound:
                        SoundMatchView()
                    }
                }
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            refreshSummaries()
        }
        .onChange(of: destination) { _, newValue in
            // Ao voltar de um jogo, o próximo diário sobe para "Continuar"
            if newValue == nil {
                refreshSummaries()
            }
        }
        .sheet(isPresented: $showLeaderboards) {
            RestGameLeaderboardsSheet()
        }
    }

    private func refreshSummaries() {
        dailySummary = DevWordleViewModel.todaySummary()
        bigOSummary = BigOViewModel.todaySummary()
        algoSpotSummary = AlgoSpotViewModel.todaySummary()
        httpStatusSummary = ScenarioQuizViewModel.todaySummary(for: .httpStatus)
        gitRescueSummary = ScenarioQuizViewModel.todaySummary(for: .gitRescue)
        regexGolfSummary = RegexGolfViewModel.todaySummary()
        weeklySummary = DevLeetHubSummary.current()
        hubStreak = RestGamesHubStreak.update(playedToday: playedDailyCount > 0)
    }

    // MARK: - Diários

    private enum DailyGame: CaseIterable, Identifiable {
        case devWordle, bigO, algoSpot, regexGolf, httpStatus, gitRescue

        var id: Self { self }
    }

    private func isPlayed(_ game: DailyGame) -> Bool {
        switch game {
        case .devWordle: return dailySummary.played
        case .bigO: return bigOSummary.played
        case .algoSpot: return algoSpotSummary.played
        case .regexGolf: return regexGolfSummary.played
        case .httpStatus: return httpStatusSummary.played
        case .gitRescue: return gitRescueSummary.played
        }
    }

    private var playedDailyCount: Int {
        DailyGame.allCases.filter(isPlayed).count
    }

    /// Primeiro diário ainda não jogado hoje (vai para o card grande)
    private var nextDaily: DailyGame? {
        DailyGame.allCases.first { !isPlayed($0) }
    }

    /// Demais diários: pendentes primeiro, jogados (esmaecidos) no fim
    private var gridDailies: [DailyGame] {
        let rest = DailyGame.allCases.filter { $0 != nextDaily }
        return rest.filter { !isPlayed($0) } + rest.filter(isPlayed)
    }

    @ViewBuilder
    private func dailyTile(_ game: DailyGame, large: Bool, wide: Bool = false) -> some View {
        let ratio: CGFloat = large || wide ? 2 : 1
        let played = isPlayed(game)

        Group {
            switch game {
            case .devWordle:
                hubTile(
                    title: "DevWordle",
                    accent: .green,
                    destination: .devWordle,
                    aspectRatio: ratio,
                    badge: { wordleBadge },
                    footer: {
                        if dailySummary.played {
                            DevWordleCountdownLabel(prefix: "Próxima em")
                        }
                    }
                ) {
                    DevWordleHubPreview()
                }
            case .bigO:
                hubTile(title: "Big O", accent: BigOTheme.accent, destination: .bigO, aspectRatio: ratio, badge: { bigODailyBadge }) {
                    BigOHubPreview()
                }
            case .algoSpot:
                hubTile(title: "AlgoSpot", accent: AlgoSpotTheme.accent, destination: .algoSpot, aspectRatio: ratio, badge: { algoSpotDailyBadge }) {
                    AlgoSpotHubPreview()
                }
            case .regexGolf:
                hubTile(
                    title: "Regex Golf",
                    accent: RegexGolfTheme.accent,
                    destination: .regexGolf,
                    aspectRatio: ratio,
                    badge: { dailyBadge(regexGolfSummary, accent: RegexGolfTheme.accentLight) }
                ) {
                    RegexGolfHubPreview()
                }
            case .httpStatus:
                hubTile(
                    title: "HTTP Status",
                    accent: HttpStatusTheme.accent,
                    destination: .httpStatus,
                    aspectRatio: ratio,
                    badge: { dailyBadge(httpStatusSummary, accent: HttpStatusTheme.accentLight) }
                ) {
                    HttpStatusHubPreview()
                }
            case .gitRescue:
                hubTile(
                    title: "Git Rescue",
                    accent: GitRescueTheme.accent,
                    destination: .gitRescue,
                    aspectRatio: ratio,
                    badge: { dailyBadge(gitRescueSummary, accent: GitRescueTheme.accentLight) }
                ) {
                    GitRescueHubPreview()
                }
            }
        }
        .saturation(played && !large ? 0.35 : 1)
        .opacity(played && !large ? 0.6 : 1)
    }

    // MARK: - Header

    private var hubHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TABNEWS")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
                Text("Jogos Dev")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                if hubStreak > 0 {
                    Label("\(hubStreak) \(hubStreak == 1 ? "dia" : "dias")", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Sequência de \(hubStreak) \(hubStreak == 1 ? "dia" : "dias")")
                }

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(0..<DailyGame.allCases.count, id: \.self) { index in
                            Circle()
                                .fill(index < playedDailyCount ? Color.green : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                        }
                    }
                    Text("\(playedDailyCount)/\(DailyGame.allCases.count)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(playedDailyCount) de \(DailyGame.allCases.count) diários jogados hoje")
            }
        }
        .padding(.top, 4)
    }

    private var dailyCompleteBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("Diários de hoje completos")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                DevWordleCountdownLabel(prefix: "Novos em")
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        }
    }

    private var rankingsButton: some View {
        Button {
            RestFeedbackManager.shared.tap()
            showLeaderboards = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                Text("Rankings")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
        }
        .accessibilityLabel("Ver rankings")
    }

    private var closeButton: some View {
        Button {
            RestFeedbackManager.shared.tap()
            closeHub()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
        .accessibilityLabel("Fechar")
    }

    private func closeHub() {
        onClose?()
        dismiss()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.45))
    }

    private var wordleBadge: some View {
        statusBadge
    }

    private var statusBadge: some View {
        Group {
            if dailySummary.won {
                Label("Acertou", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if dailySummary.played {
                Label("Errou", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("Novo")
                    .foregroundStyle(.green)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
        .accessibilityElement(children: .combine)
    }

    private var devLeetStatusBadge: some View {
        Group {
            if weeklySummary.solved {
                Label("Resolvido", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Novo")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
        .accessibilityElement(children: .combine)
    }

    private var bigODailyBadge: some View {
        Group {
            if bigOSummary.won {
                Label("Acertou", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if bigOSummary.played {
                Label("Errou", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("Novo")
                    .foregroundStyle(BigOTheme.accentLight)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
    }

    private func dailyBadge(_ summary: ScenarioQuizDailySummary, accent: Color) -> some View {
        Group {
            if summary.won {
                Label("Acertou", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if summary.played {
                Label("Errou", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("Novo")
                    .foregroundStyle(accent)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
    }

    private var algoSpotDailyBadge: some View {
        Group {
            if algoSpotSummary.won {
                Label("Acertou", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if algoSpotSummary.played {
                Label("Errou", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text("Novo")
                    .foregroundStyle(AlgoSpotTheme.accentLight)
            }
        }
        .font(.caption2.weight(.bold))
        .labelStyle(.titleAndIcon)
    }

    private func hubTile<Preview: View, Badge: View, Footer: View>(
        title: String,
        accent: Color,
        destination hubDestination: HubDestination,
        aspectRatio: CGFloat = 1,
        previewAlignment: Alignment = .center,
        immersivePreview: Bool = false,
        @ViewBuilder badge: () -> Badge = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        Button {
            RestFeedbackManager.shared.cardPress()
            destination = hubDestination
        } label: {
            Group {
                if immersivePreview {
                    ZStack(alignment: .top) {
                        preview()
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(spacing: 0) {
                            hubTileHeader(title: title, badge: badge)
                                .padding(14)
                                .allowsHitTesting(false)
                                .background {
                                    LinearGradient(
                                        colors: [.black.opacity(0.72), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                }

                            Spacer(minLength: 0)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        hubTileHeader(title: title, badge: badge)
                            .allowsHitTesting(false)

                        preview()
                            .allowsHitTesting(false)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: previewAlignment)

                        footer()
                            .allowsHitTesting(false)
                    }
                    .padding(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                HubGameTileBackground(accent: accent)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(0.2), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    private func hubTileHeader<Badge: View>(
        title: String,
        @ViewBuilder badge: () -> Badge
    ) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            badge()
        }
    }
}

private struct HubGameTileBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.05)

            LinearGradient(
                colors: [accent.opacity(0.18), .clear, accent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("ruido")
                .resizable()
                .scaledToFill()
                .opacity(0.24)
                .blendMode(.softLight)
        }
        .colorScheme(.dark)
    }
}

private struct DevWordleHubPreview: View {
    private struct Tile: Equatable {
        var letter: Character?
        var result: DevWordleLetterResult?
    }

    @State private var tiles = Array(repeating: Tile(letter: nil, result: nil), count: 5)
    @State private var shake = false

    private let prefix: [Character] = Array("CODE")
    private let swapLetters: [Character] = ["T", "Z", "Q", "J", "V", "W", "Y", "H", "G", "B"]
    private let prefixResults: [DevWordleLetterResult] = [.correct, .present, .absent, .present]

    var body: some View {
        GeometryReader { geo in
            let spacing = max(geo.size.width * 0.02, 8)
            let maxTileWidth = min((geo.size.width - spacing * 4) / 5, geo.size.height * 0.88)
            let tileWidth = maxTileWidth * 0.729
            let tileHeight = tileWidth * 1.12
            let fontSize = tileWidth * 0.42
            let cornerRadius = tileWidth * 0.2

            HStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { index in
                    hubTile(
                        letter: tiles[index].letter,
                        result: tiles[index].result,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        fontSize: fontSize,
                        cornerRadius: cornerRadius
                    )
                }
            }
            .modifier(HubPreviewShakeEffect(animating: shake))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await runLoop() }
    }

    @ViewBuilder
    private func hubTile(
        letter: Character?,
        result: DevWordleLetterResult?,
        tileWidth: CGFloat,
        tileHeight: CGFloat,
        fontSize: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let background = tileBackground(for: result)
        let foreground: Color = result == nil ? .white : .white
        let border = result == nil
            ? Color.white.opacity(letter == nil ? 0.18 : 0.35)
            : background

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(background)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(border, lineWidth: max(1.5, tileWidth * 0.04))
                }

            if let letter {
                Text(String(letter))
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(foreground)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: tileWidth, height: tileHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: letter)
        .animation(.easeInOut(duration: 0.22), value: result)
    }

    private func tileBackground(for result: DevWordleLetterResult?) -> Color {
        guard let result else {
            return Color.white.opacity(0.06)
        }
        switch result {
        case .correct: return Color(red: 0.42, green: 0.67, blue: 0.36).opacity(0.85)
        case .present: return Color(red: 0.78, green: 0.68, blue: 0.30).opacity(0.85)
        case .absent: return Color.white.opacity(0.14)
        }
    }

    @MainActor
    private func resetTiles() {
        withAnimation(.easeOut(duration: 0.2)) {
            tiles = Array(repeating: Tile(letter: nil, result: nil), count: 5)
        }
    }

    @MainActor
    private func typeLetter(at index: Int, _ letter: Character) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            tiles[index].letter = letter
            tiles[index].result = nil
        }
    }

    @MainActor
    private func removeLastLetter() {
        guard tiles[4].letter != nil else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            tiles[4].letter = nil
            tiles[4].result = nil
        }
    }

    @MainActor
    private func revealPrefixColors() {
        withAnimation(.easeInOut(duration: 0.24)) {
            for index in 0..<prefixResults.count {
                tiles[index].result = prefixResults[index]
            }
        }
    }

    @MainActor
    private func revealLastLetter(_ result: DevWordleLetterResult) {
        withAnimation(.easeInOut(duration: 0.22)) {
            tiles[4].result = result
        }
    }

    @MainActor
    private func performShake() async {
        shake = true
        try? await Task.sleep(for: .milliseconds(380))
        shake = false
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await resetTiles()
            try? await Task.sleep(for: .milliseconds(450))

            for (index, letter) in prefix.enumerated() {
                await typeLetter(at: index, letter)
                try? await Task.sleep(for: .milliseconds(260))
            }

            await typeLetter(at: 4, swapLetters[0])
            try? await Task.sleep(for: .milliseconds(320))
            await revealPrefixColors()
            await revealLastLetter(.absent)
            try? await Task.sleep(for: .milliseconds(380))
            await performShake()
            try? await Task.sleep(for: .milliseconds(520))

            for letter in swapLetters.dropFirst() {
                await removeLastLetter()
                try? await Task.sleep(for: .milliseconds(200))
                await typeLetter(at: 4, letter)
                try? await Task.sleep(for: .milliseconds(240))
                await revealLastLetter(.absent)
                try? await Task.sleep(for: .milliseconds(220))
                await performShake()
                try? await Task.sleep(for: .milliseconds(420))
            }

            try? await Task.sleep(for: .milliseconds(700))
        }
    }
}

private struct HubPreviewShakeEffect: ViewModifier {
    var animating: Bool

    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: animating) { _, shouldShake in
                guard shouldShake else {
                    shakeOffset = 0
                    return
                }
                withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) {
                    shakeOffset = 4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    shakeOffset = 0
                }
            }
    }
}

private struct DevLeetHubPreview: View {
    let summary: DevLeetWeeklySummary
    /// Card pequeno da linha "Mais jogos": só título, dificuldade e código
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(summary.problemTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(compact ? 3 : 2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(summary.difficulty.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(summary.difficulty.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(summary.difficulty.color.opacity(0.14), in: Capsule())

                    if summary.currentStreak > 0, !compact {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(summary.currentStreak) sem.")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("class Solution {")
                    Text("  func solve(_ nums: [Int]) -> [Int] {")
                    Text("    // hash map")
                    Text("  }")
                    Text("}")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.34))

                if !compact {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IN")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.55))
                        Text("[2, 7, 11, 15]")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("OUT")
                            .font(.system(size: 7, weight: .black, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.55))
                        Text("[0, 1]")
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                }
            }

            Spacer(minLength: 0)

            if !compact {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 52, height: 64)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        }

                    VStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 28, height: 3)
                        }
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "pencil.and.outline")
                        .font(.caption2.weight(.semibold))
                    Text("papel")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.orange.opacity(0.75))
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct BigOHubPreview: View {
    @State private var highlightIndex = 0
    private let options = ["O(n)", "O(log n)", "O(n²)", "O(1)"]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.08))
                    .frame(width: 22, height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(BigOTheme.accent.opacity(0.35))
                    .frame(width: 56, height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(index == highlightIndex ? 1 : 0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            (index == highlightIndex ? BigOTheme.accent : Color.white).opacity(index == highlightIndex ? 0.25 : 0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.2))
                highlightIndex = (highlightIndex + 1) % options.count
            }
        }
        .animation(.easeInOut(duration: 0.7), value: highlightIndex)
    }
}

private struct AlgoSpotHubPreview: View {
    var body: some View {
        GeometryReader { geo in
            let fontSize = min(max(geo.size.width * 0.085, 10), geo.size.height * 0.13)
            let lineSpacing = max(geo.size.height * 0.045, 5)
            let questionSize = min(geo.size.width * 0.42, geo.size.height * 0.72)

            ZStack {
                VStack(alignment: .leading, spacing: lineSpacing) {
                    HubShineCodeLine(text: "for u in graph:", fontSize: fontSize)
                    HubShineCodeLine(text: "  dist[u] = inf", fontSize: fontSize)
                    HubShineCodeLine(text: "  heap.push(u)", fontSize: fontSize * 0.92, dimmed: true)
                    HubShineCodeLine(text: "return path", fontSize: fontSize * 0.92, dimmed: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Text("?")
                    .font(.system(size: questionSize, weight: .black, design: .rounded))
                    .foregroundStyle(AlgoSpotTheme.accentLight.opacity(0.9))
                    .shadow(color: AlgoSpotTheme.accent.opacity(0.5), radius: 14)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HubShineCodeLine: View {
    let text: String
    var fontSize: CGFloat = 8.5
    var dimmed = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 6.5) / 6.5

            Text(text)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(dimmed ? 0.28 : 0.42))
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, AlgoSpotTheme.accentLight.opacity(0.9), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(geo.size.width * 0.5, 24))
                        .offset(x: geo.size.width * 1.35 * phase - geo.size.width * 0.25)
                    }
                    .mask {
                        Text(text)
                            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    }
                }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct ColorMatchHubPreview: View {
    @State private var hue: Double = 0
    @State private var saturation: Double = 68
    @State private var lightness: Double = 54

    private var normalizedHue: Double {
        hue.truncatingRemainder(dividingBy: 360)
    }

    var body: some View {
        let color = HSLColor(hue: normalizedHue, saturation: saturation, lightness: lightness)

        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.swiftUIColor)
                .frame(width: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }

            HubHueStrip(hue: normalizedHue, saturation: saturation, lightness: lightness)
                .frame(width: 16)

            HubValueStrip(
                value: saturation / 100,
                gradient: HubColorStripGradients.saturation(hue: normalizedHue, lightness: lightness)
            )
            .frame(width: 12)

            HubValueStrip(
                value: lightness / 100,
                gradient: HubColorStripGradients.lightness(hue: normalizedHue, saturation: saturation)
            )
            .frame(width: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                hue = 360
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                saturation = 88
            }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                lightness = 66
            }
        }
    }
}

private enum HubColorStripGradients {
    static func saturation(hue: Double, lightness: Double) -> [Color] {
        [
            HSLColor(hue: hue, saturation: 0, lightness: lightness).swiftUIColor,
            HSLColor(hue: hue, saturation: 100, lightness: lightness).swiftUIColor
        ]
    }

    static func lightness(hue: Double, saturation: Double) -> [Color] {
        [
            HSLColor(hue: hue, saturation: saturation, lightness: 12).swiftUIColor,
            HSLColor(hue: hue, saturation: saturation, lightness: 88).swiftUIColor
        ]
    }
}

private struct HubHueStrip: View {
    let hue: Double
    let saturation: Double
    let lightness: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Canvas { context, size in
                    let rows = max(Int(size.height), 1)
                    for row in 0..<rows {
                        let inverted = 1 - (Double(row) / Double(max(rows - 1, 1)))
                        let stripHue = inverted * 360
                        let stripColor = HSLColor(
                            hue: stripHue,
                            saturation: saturation,
                            lightness: lightness
                        ).swiftUIColor
                        let rect = CGRect(x: 0, y: CGFloat(row), width: size.width, height: 1)
                        context.fill(Path(rect), with: .color(stripColor))
                    }
                }
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))

                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .position(
                        x: geo.size.width / 2,
                        y: (1 - hue / 360) * geo.size.height
                    )
            }
        }
    }
}

private struct HubValueStrip: View {
    let value: Double
    let gradient: [Color]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: gradient, startPoint: .bottom, endPoint: .top))
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))

                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .position(
                        x: geo.size.width / 2,
                        y: (1 - value) * geo.size.height
                    )
            }
        }
    }
}

private struct SoundMatchHubPreview: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.05, blue: 0.13),
                    Color(red: 0.03, green: 0.04, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    SoundRibbonRenderer.draw(
                        context: &context,
                        size: size,
                        visualNorm: 0.5,
                        time: time,
                        compact: false,
                        profile: .hubBanner,
                        isInteractive: false
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DevSpotPreview: View {
    @State private var highlightLeft = true

    var body: some View {
        HStack(spacing: 8) {
            previewWord("Container", highlighted: highlightLeft)
            Text("VS")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.3))
            previewWord("Conductor", highlighted: !highlightLeft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                highlightLeft.toggle()
            }
        }
        .animation(.easeInOut(duration: 0.45), value: highlightLeft)
    }

    private func previewWord(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(highlighted ? 1 : 0.45))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                (highlighted ? Color.mint : Color.white).opacity(highlighted ? 0.2 : 0.06),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke((highlighted ? Color.mint : Color.white).opacity(highlighted ? 0.35 : 0.08), lineWidth: 1)
            }
    }
}

extension RestGameType: Identifiable {
    var id: Self { self }
}

/// Sequência de dias com pelo menos um desafio diário jogado (qualquer jogo)
enum RestGamesHubStreak {
    private static let countKey = "restGamesHubStreakCount"
    private static let lastDayKey = "restGamesHubStreakLastDay"

    static var current: Int {
        let defaults = UserDefaults.standard
        guard let last = defaults.string(forKey: lastDayKey),
              last == dayKey(.now) || last == dayKey(yesterday) else { return 0 }
        return defaults.integer(forKey: countKey)
    }

    static func update(playedToday: Bool) -> Int {
        let defaults = UserDefaults.standard
        let today = dayKey(.now)
        guard playedToday, defaults.string(forKey: lastDayKey) != today else { return current }

        let continues = defaults.string(forKey: lastDayKey) == dayKey(yesterday)
        defaults.set(continues ? defaults.integer(forKey: countKey) + 1 : 1, forKey: countKey)
        defaults.set(today, forKey: lastDayKey)
        return current
    }

    private static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    }

    private static func dayKey(_ date: Date) -> String {
        ScenarioQuizEngine.dateKey(for: date)
    }
}
