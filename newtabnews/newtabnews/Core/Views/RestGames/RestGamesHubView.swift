import SwiftUI

private enum HubDestination: Hashable {
    case devWordle
    case devLeet
    case devSpot
    case bigO
    case algoSpot
    case arcade(RestGameType)
}

struct RestGamesHubView: View {
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    @State private var destination: HubDestination?
    @State private var dailySummary = DevWordleViewModel.todaySummary()
    @State private var bigOSummary = BigOViewModel.todaySummary()
    @State private var algoSpotSummary = AlgoSpotViewModel.todaySummary()
    @State private var weeklySummary = DevLeetHubSummary.current()
    @State private var showLeaderboards = false

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        VStack(spacing: 10) {
                            RestGamePhaseLabel(text: "TabNews")

                            Text("Jogos Dev")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Hoje")

                            VStack(spacing: 12) {
                                hubTile(
                                    title: "DevWordle",
                                    accent: .green,
                                    destination: .devWordle,
                                    aspectRatio: 2,
                                    badge: { wordleBadge },
                                    footer: {
                                        if dailySummary.played {
                                            DevWordleCountdownLabel(prefix: "Próxima em")
                                        }
                                    }
                                ) {
                                    DevWordleHubPreview()
                                }

                                HStack(spacing: 12) {
                                    hubTile(
                                        title: "Big O",
                                        accent: BigOTheme.accent,
                                        destination: .bigO,
                                        previewAlignment: .bottom,
                                        badge: { bigODailyBadge }
                                    ) {
                                        BigOHubPreview()
                                    }

                                    hubTile(
                                        title: "AlgoSpot",
                                        accent: AlgoSpotTheme.accent,
                                        destination: .algoSpot,
                                        badge: { algoSpotDailyBadge }
                                    ) {
                                        AlgoSpotHubPreview()
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Esta semana")

                            hubTile(
                                title: "DevLeet",
                                accent: .orange,
                                destination: .devLeet,
                                aspectRatio: 1.15,
                                badge: { devLeetStatusBadge },
                                footer: {
                                    if weeklySummary.solved {
                                        DevLeetCountdownLabel(prefix: "Próximo em")
                                    }
                                }
                            ) {
                                DevLeetHubPreview(summary: weeklySummary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Mais")

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    hubTile(
                                        title: "DevSpot",
                                        accent: .mint,
                                        destination: .devSpot,
                                        previewAlignment: .bottom
                                    ) {
                                        DevSpotPreview()
                                    }

                                    hubTile(
                                        title: "Color Match",
                                        accent: .pink,
                                        destination: .arcade(.color)
                                    ) {
                                        ColorMatchHubPreview()
                                    }
                                }

                                hubTile(
                                    title: "Sound Match",
                                    accent: .cyan,
                                    destination: .arcade(.sound),
                                    aspectRatio: 2,
                                    immersivePreview: true
                                ) {
                                    SoundMatchHubPreview()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
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
            dailySummary = DevWordleViewModel.todaySummary()
            bigOSummary = BigOViewModel.todaySummary()
            algoSpotSummary = AlgoSpotViewModel.todaySummary()
            weeklySummary = DevLeetHubSummary.current()
        }
        .sheet(isPresented: $showLeaderboards) {
            RestGameLeaderboardsSheet()
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
                Text("New")
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
    var body: some View {
        HStack(spacing: 6) {
            ForEach(["R", "E", "A", "C", "T"], id: \.self) { letter in
                let color: Color = switch letter {
                case "E": .yellow
                case "A": .gray
                default: .green
                }

                Text(letter)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color.opacity(color == .gray ? 0.25 : 0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DevLeetHubPreview: View {
    let summary: DevLeetWeeklySummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.problemTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(summary.difficulty.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(summary.difficulty.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(summary.difficulty.color.opacity(0.14), in: Capsule())

                    if summary.currentStreak > 0 {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("function solve(_ nums: [Int]) {")
                    Text("  // papel e caneta")
                    Text("}")
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.32))
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Image(systemName: "pencil.and.outline")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("semanal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                highlightIndex = (highlightIndex + 1) % options.count
            }
        }
        .animation(.easeInOut(duration: 0.45), value: highlightIndex)
    }
}

private struct AlgoSpotHubPreview: View {
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 7) {
                HubShineCodeLine(text: "for u in graph:", fontSize: 11)
                HubShineCodeLine(text: "  dist[u] = inf", fontSize: 11)
                HubShineCodeLine(text: "  heap.push(u)", fontSize: 10.5, dimmed: true)
                HubShineCodeLine(text: "return path", fontSize: 10.5, dimmed: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 2)

            Text("?")
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(AlgoSpotTheme.accentLight.opacity(0.92))
                .shadow(color: AlgoSpotTheme.accent.opacity(0.5), radius: 14)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HubShineCodeLine: View {
    let text: String
    var fontSize: CGFloat = 8.5
    var dimmed = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.4) / 2.4

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

            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                Canvas { context, size in
                    SoundRibbonRenderer.draw(
                        context: &context,
                        size: size,
                        visualNorm: 0.52,
                        time: timeline.date.timeIntervalSinceReferenceDate,
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
