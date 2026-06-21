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
    let onPlayAgain: () -> Void
    let onClose: () -> Void

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
                    RestGameSecondaryButton(title: "Voltar", action: onClose)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.vertical, 32)
        }
    }
}
