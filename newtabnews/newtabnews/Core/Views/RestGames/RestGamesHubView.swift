import SwiftUI

private enum HubDestination: Hashable {
    case devWordle
    case devSpot
    case arcade(RestGameType)
}

struct RestGamesHubView: View {
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    @State private var destination: HubDestination?
    @State private var dailySummary = DevWordleViewModel.todaySummary()
    @State private var showLeaderboards = false

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(spacing: 10) {
                            RestGamePhaseLabel(text: "TabNews")

                            Text("Jogos Dev")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Hoje")

                            Button {
                                RestFeedbackManager.shared.cardPress()
                                destination = .devWordle
                            } label: {
                                devWordleCard
                            }
                            .buttonStyle(RestGameScaleButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            sectionTitle("Arcade")

                            arcadeCard(
                                title: "DevSpot",
                                subtitle: "Container ou Conductor?",
                                icon: "brain.head.profile",
                                accent: .mint,
                                destination: .devSpot
                            ) {
                                DevSpotPreview()
                            }

                            arcadeCard(
                                title: "Color Match",
                                subtitle: "Memorize a cor e recrie",
                                icon: "paintpalette.fill",
                                accent: .pink,
                                destination: .arcade(.color)
                            ) {
                                AnimatedColorPreview()
                            }

                            arcadeCard(
                                title: "Sound Match",
                                subtitle: "Memorize o som e recrie",
                                icon: "waveform",
                                accent: .cyan,
                                destination: .arcade(.sound)
                            ) {
                                SoundRibbonPreview()
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
                case .devSpot:
                    DevSpotView()
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

    private var devWordleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: "character.textbox")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
                    .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("DevWordle")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Termo dev de 5 letras · PT e EN")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                statusBadge
            }

            HStack(spacing: 16) {
                miniTile(color: .green, letter: "R", delay: 0)
                miniTile(color: .yellow, letter: "E", delay: 0.08)
                miniTile(color: .gray, letter: "A", delay: 0.16)
                miniTile(color: .green, letter: "C", delay: 0.24)
                miniTile(color: .green, letter: "T", delay: 0.32)

                Spacer()

                if dailySummary.currentStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(dailySummary.currentStreak)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("streak")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        }
    }

    private var statusBadge: some View {
        Group {
            if dailySummary.won {
                Image(systemName: "checkmark.circle.fill")
            } else if dailySummary.played {
                Text("✗")
                    .font(.headline.weight(.bold))
            } else {
                Text("—")
                    .font(.headline.weight(.bold))
            }
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(dailySummary.won ? .green : .white.opacity(0.45))
    }

    private func miniTile(color: Color, letter: String, delay: Double) -> some View {
        Text(letter)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 32)
            .background(color.opacity(color == .gray ? 0.25 : 0.75), in: RoundedRectangle(cornerRadius: 6))
    }

    private func arcadeCard<Preview: View>(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        destination hubDestination: HubDestination,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        Button {
            RestFeedbackManager.shared.cardPress()
            destination = hubDestination
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 4)
                }

                preview()
            }
            .padding(18)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }
}

private struct DevSpotPreview: View {
    @State private var highlightLeft = true

    var body: some View {
        HStack(spacing: 12) {
            previewWord("Container", highlighted: highlightLeft)
            Text("VS")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.3))
            previewWord("Conductor", highlighted: !highlightLeft)
        }
        .frame(height: 72)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeInOut(duration: 0.5)) {
                    highlightLeft.toggle()
                }
            }
        }
    }

    private func previewWord(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(highlighted ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                (highlighted ? Color.mint : Color.white).opacity(highlighted ? 0.2 : 0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke((highlighted ? Color.mint : Color.white).opacity(highlighted ? 0.4 : 0.08), lineWidth: 1)
            }
            .scaleEffect(highlighted ? 1.02 : 0.98)
    }
}

private struct AnimatedColorPreview: View {
    @State private var hue: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(HSLColor(hue: hue, saturation: 72, lightness: 58).swiftUIColor)
            .frame(height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    hue = 360
                }
            }
    }
}

extension RestGameType: Identifiable {
    var id: Self { self }
}
