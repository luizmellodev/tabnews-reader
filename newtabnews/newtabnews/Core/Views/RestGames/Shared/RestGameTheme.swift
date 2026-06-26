import SwiftUI

enum RestGameTheme {
    static let spring = Animation.spring(response: 0.48, dampingFraction: 0.82)
    static let quickSpring = Animation.spring(response: 0.32, dampingFraction: 0.78)

    static func scoreGradient(_ score: Double) -> LinearGradient {
        let color = RestGameScoring.scoreColor(score)
        return LinearGradient(
            colors: [color.opacity(0.9), color.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

protocol RestGamePlayMode: Equatable {
    var title: String { get }
    var iconName: String { get }
}

struct RestGameModeToggle<Mode: RestGamePlayMode>: View {
    let selection: Mode
    let isFreeUnlocked: Bool
    let daily: Mode
    let free: Mode
    let onSelect: (Mode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment(daily, locked: false)
            segment(free, locked: !isFreeUnlocked)
        }
        .padding(4)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func segment(_ mode: Mode, locked: Bool) -> some View {
        let isSelected = selection == mode
        let isDisabled = locked && mode == free

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

struct RestGameBackground: View {
    var animated: Bool = true

    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(
                    x: animated ? (animate ? -80 : -40) : -60,
                    y: animated ? (animate ? -180 : -140) : -160
                )

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(
                    x: animated ? (animate ? 120 : 80) : 100,
                    y: animated ? (animate ? 220 : 180) : 200
                )
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct RestGamePhaseLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(2.4)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial.opacity(0.35), in: Capsule())
    }
}

struct RestGamePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            RestFeedbackManager.shared.tap()
            action()
        }) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(.white, in: Capsule())
                .shadow(color: .white.opacity(0.15), radius: 16, y: 8)
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }
}

struct RestGameSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            RestFeedbackManager.shared.tap()
            action()
        }) {
            Text(title)
                .font(.headline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }
}

struct RestGameDailyCompleteEmptyState<Countdown: View>: View {
    let wasCorrect: Bool
    @ViewBuilder let countdown: () -> Countdown

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: wasCorrect ? "checkmark.circle" : "xmark.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(wasCorrect
                    ? Color(red: 0.42, green: 0.67, blue: 0.36)
                    : .red)

            Text(wasCorrect ? "Boa!! Amanhã tem mais!" : "Relaxa.. amanhã tem mais!")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            countdown()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct RestGameFreeModeHubSetting: View {
    @AppStorage(RestGameFreeModePolicy.storageKey) private var restGamesAllowFreeMode = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "infinity")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Modo livre")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Prática extra após o desafio diário")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $restGamesAllowFreeMode)
                .labelsHidden()
                .tint(Color(red: 0.42, green: 0.67, blue: 0.36))
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Modo livre nos jogos")
        .accessibilityValue(restGamesAllowFreeMode ? "Ativado" : "Desativado")
    }
}

struct RestGameConfirmFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 64, height: 64)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }
}

struct RestGameScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(RestGameTheme.quickSpring, value: configuration.isPressed)
    }
}

struct RoundIndicatorView: View {
    let currentRound: Int
    let totalRounds: Int
    var lightStyle: Bool = false

    var body: some View {
        Text("\(currentRound) / \(totalRounds)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(lightStyle ? .black.opacity(0.55) : .white.opacity(0.7))
            .monospacedDigit()
    }
}

struct MemorizeCountdownRing: View {
    let timeRemaining: TimeInterval
    let total: TimeInterval
    var lightStyle: Bool = false

    private var progress: Double {
        1 - (timeRemaining / total)
    }

    private var displayedSecond: Int {
        max(0, Int(ceil(timeRemaining)))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke((lightStyle ? Color.black : Color.white).opacity(0.15), lineWidth: 5)
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(lightStyle ? Color.black.opacity(0.7) : Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            Text("\(displayedSecond)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(lightStyle ? .black.opacity(0.75) : .white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}
