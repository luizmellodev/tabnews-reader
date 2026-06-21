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
