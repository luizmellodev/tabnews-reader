import SwiftUI

struct MemorizePhaseView: View {
    let gameType: RestGameType
    let targetColor: HSLColor?
    let targetFrequency: Double?
    let timeRemaining: TimeInterval

    @State private var breathe = false

    var body: some View {
        ZStack {
            switch gameType {
            case .color:
                if let targetColor {
                    targetColor.swiftUIColor
                        .ignoresSafeArea()
                        .scaleEffect(breathe ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: breathe)
                }
            case .sound:
                Color.black.ignoresSafeArea()

                if let targetFrequency {
                    SoundRibbonView(
                        frequency: .constant(targetFrequency),
                        isInteractive: false
                    )
                    .allowsHitTesting(false)
                }
            }

            VStack {
                Spacer()

                MemorizeCountdownRing(
                    timeRemaining: timeRemaining,
                    total: RestGameScoring.memorizeDuration,
                    lightStyle: gameType == .color
                )
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            breathe = true
        }
    }
}

struct ScoreRevealView: View {
    let score: Double
    let round: Int
    let onContinue: () -> Void

    @State private var displayedScore: Double = 0
    @State private var hasAnimated = false
    @State private var showButton = false
    @State private var ringScale: CGFloat = 0.6

    var body: some View {
        VStack(spacing: 28) {
            RestGamePhaseLabel(text: "Round \(round)")

            ZStack {
                Circle()
                    .stroke(RestGameScoring.scoreColor(score).opacity(0.25), lineWidth: 10)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ringScale)

                Circle()
                    .fill(RestGameScoring.scoreColor(score).opacity(0.12))
                    .frame(width: 160, height: 160)
                    .scaleEffect(ringScale)

                VStack(spacing: 4) {
                    Text(RestGameScoring.formattedScore(displayedScore))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(RestGameScoring.scoreColor(score))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text("/ 10")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if showButton {
                RestGamePrimaryButton(title: "Continuar", action: onContinue)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true

            withAnimation(RestGameTheme.spring) {
                ringScale = 1
            }
            animateScore()
        }
    }

    private func animateScore() {
        let steps = 36
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.028) {
                let progress = Double(step) / Double(steps)
                displayedScore = score * progress
                if step == steps {
                    RestFeedbackManager.shared.scoreReveal(score: score)
                    withAnimation(RestGameTheme.spring) {
                        showButton = true
                    }
                }
            }
        }
    }
}

struct FinalResultsView: View {
    let scores: [Double]
    let leaderboard: RestGameLeaderboard
    let onPlayAgain: () -> Void
    let onClose: () -> Void

    @StateObject private var gameCenter = GameCenterManager.shared

    private var total: Double {
        scores.reduce(0, +)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                RestGamePhaseLabel(text: "Resultado")

                VStack(spacing: 6) {
                    Text(RestGameScoring.formattedScore(total))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(RestGameScoring.scoreColor(total / Double(max(scores.count, 1))))
                        .monospacedDigit()

                    Text("/ 50")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                VStack(spacing: 10) {
                    ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 22, height: 22)
                                .background(.white.opacity(0.08), in: Circle())

                            Capsule()
                                .fill(RestGameScoring.scoreColor(score).opacity(0.85))
                                .frame(width: max(8, CGFloat(score / 10) * 120), height: 8)

                            Spacer(minLength: 0)

                            Text(RestGameScoring.formattedScore(score))
                                .foregroundStyle(RestGameScoring.scoreColor(score))
                                .monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    RestGamePrimaryButton(title: "Jogar de novo", action: onPlayAgain)
                    if gameCenter.isAuthenticated {
                        RestGameSecondaryButton(title: "Ver ranking") {
                            gameCenter.showLeaderboard(leaderboard)
                        }
                    }
                    RestGameSecondaryButton(title: "Voltar", action: onClose)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
        }
    }
}

// MARK: - Onboarding

enum RestGameOnboardingID: String {
    case colorMatch
    case soundMatch
    case devWordle
    case devSpot
}

enum RestGameOnboarding {
    private static func key(for id: RestGameOnboardingID) -> String {
        "restGameOnboardingSeen_\(id.rawValue)"
    }

    static func hasSeen(_ id: RestGameOnboardingID) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: id))
    }

    static func markSeen(_ id: RestGameOnboardingID) {
        UserDefaults.standard.set(true, forKey: key(for: id))
    }
}

struct RestGameOnboardingOverlay: View {
    let title: String
    let icon: String
    let accent: Color
    let steps: [String]
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(accent)
                    .frame(width: 88, height: 88)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accent)
                                    .frame(width: 22, height: 22)
                                    .background(accent.opacity(0.15), in: Circle())

                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }

                RestGamePrimaryButton(title: "Jogar", action: onPlay)
            }
            .padding(28)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .padding(.horizontal, 24)
        }
    }
}

extension RestGameOnboardingOverlay {
    static func colorMatch(onPlay: @escaping () -> Void) -> RestGameOnboardingOverlay {
        RestGameOnboardingOverlay(
            title: "Color Match",
            icon: "paintpalette.fill",
            accent: .pink,
            steps: [
                "Memorize a cor por 5 segundos — preste atenção no tom.",
                "Recrie a cor com os sliders à esquerda.",
                "Toque ✓ quando achar que acertou. São 5 rounds."
            ],
            onPlay: onPlay
        )
    }

    static func soundMatch(onPlay: @escaping () -> Void) -> RestGameOnboardingOverlay {
        RestGameOnboardingOverlay(
            title: "Sound Match",
            icon: "waveform",
            accent: .cyan,
            steps: [
                "Ouça o som por 5 segundos — grave o pitch na cabeça.",
                "Arraste ↑↓ na onda para recriar a frequência.",
                "Toque ✓ para confirmar. São 5 rounds."
            ],
            onPlay: onPlay
        )
    }

    static func devWordle(onPlay: @escaping () -> Void) -> RestGameOnboardingOverlay {
        RestGameOnboardingOverlay(
            title: "DevWordle",
            icon: "character.textbox",
            accent: .green,
            steps: [
                "Adivinhe o termo dev de 5 letras.",
                "Verde = certo · Amarelo = existe · Cinza = não existe.",
                "Você tem 6 tentativas. Um puzzle novo por dia."
            ],
            onPlay: onPlay
        )
    }

    static func devSpot(onPlay: @escaping () -> Void) -> RestGameOnboardingOverlay {
        RestGameOnboardingOverlay(
            title: "DevSpot",
            icon: "brain.head.profile",
            accent: .mint,
            steps: [
                "Dois termos aparecem — só um é de dev.",
                "Toque no termo certo o mais rápido que puder.",
                "São 10 rounds. Quanto mais acertos seguidos, melhor."
            ],
            onPlay: onPlay
        )
    }
}
