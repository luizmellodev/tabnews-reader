import SwiftUI

struct RestGamesHubBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JOGOS DEV")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)

                    Text("Wordle · Leet · Big O · AlgoSpot · Spot · Descanso")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background {
                ArcadeBlackBannerBackground()
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RestGamesRankingsBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.9), Color.yellow.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rankings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Game Center · 4 leaderboards")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color("CardColor"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

enum RestGamesNewPuzzlePrompt {
    private enum Keys {
        static let dismissedWordleDate = "restGamesHomeBannerDismissedWordleDate"
        static let dismissedLeetWeek = "restGamesHomeBannerDismissedLeetWeek"
    }

    struct State: Equatable {
        let message: String
        let hasWordle: Bool
        let hasLeet: Bool
    }

    @MainActor
    static func current() -> State? {
        guard RestGamesAnnouncement.hasSeen else { return nil }

        let wordleSummary = DevWordleViewModel.todaySummary()
        let leetSummary = DevLeetHubSummary.current()
        let dateKey = devWordleDateKey()
        let weekKey = DevLeetSchedule.weekKey()

        let newWordle = !wordleSummary.played && !isWordleDismissed(dateKey: dateKey)
        let newLeet = !leetSummary.solved && !isLeetDismissed(weekKey: weekKey)

        guard newWordle || newLeet else { return nil }

        return State(
            message: bannerMessage(wordle: newWordle, leet: newLeet),
            hasWordle: newWordle,
            hasLeet: newLeet
        )
    }

    static func dismiss(_ state: State) {
        let defaults = UserDefaults.standard
        if state.hasWordle {
            defaults.set(devWordleDateKey(), forKey: Keys.dismissedWordleDate)
        }
        if state.hasLeet {
            defaults.set(DevLeetSchedule.weekKey(), forKey: Keys.dismissedLeetWeek)
        }
    }

    private static func bannerMessage(wordle: Bool, leet: Bool) -> String {
        switch (wordle, leet) {
        case (true, true):
            return "DevWordle e DevLeet novos"
        case (true, false):
            return "Novo DevWordle hoje"
        case (false, true):
            return "Novo DevLeet esta semana"
        default:
            return ""
        }
    }

    private static func devWordleDateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isWordleDismissed(dateKey: String) -> Bool {
        UserDefaults.standard.string(forKey: Keys.dismissedWordleDate) == dateKey
    }

    private static func isLeetDismissed(weekKey: String) -> Bool {
        UserDefaults.standard.string(forKey: Keys.dismissedLeetWeek) == weekKey
    }

    #if DEBUG
    static func resetDismissalsForTesting() {
        UserDefaults.standard.removeObject(forKey: Keys.dismissedWordleDate)
        UserDefaults.standard.removeObject(forKey: Keys.dismissedLeetWeek)
    }
    #endif
}

private struct RestGamesAttentionBorder: View {
    let colors: [Color]
    let rotation: Double
    let cornerRadius: CGFloat

    private var gradientColors: [Color] {
        colors + [colors[0].opacity(0.25)]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: gradientColors,
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: 1.5
            )
    }
}

struct RestGamesNewPuzzleBanner: View {
    let state: RestGamesNewPuzzlePrompt.State
    let onTap: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gradientRotation: Double = 0
    @State private var autoDismissTask: Task<Void, Never>?

    private let autoDismissDuration: TimeInterval = 5
    private let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        if state.hasWordle {
                            gameIcon("character.textbox", color: .green)
                        }
                        if state.hasLeet {
                            gameIcon("pencil.and.outline", color: .orange)
                        }
                    }

                    Text(state.message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: dismissBanner) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar aviso")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color("CardColor"), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if reduceMotion {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(attentionBorderColors.first?.opacity(0.55) ?? Color.green.opacity(0.55), lineWidth: 1.5)
            } else {
                RestGamesAttentionBorder(
                    colors: attentionBorderColors,
                    rotation: gradientRotation,
                    cornerRadius: cornerRadius
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .onAppear {
            startBorderAnimationIfNeeded()
            scheduleAutoDismiss()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    private var attentionBorderColors: [Color] {
        var colors: [Color] = []
        if state.hasWordle { colors.append(.green) }
        if state.hasLeet { colors.append(.orange) }
        if colors.isEmpty { colors = [.green, .cyan] }
        return colors
    }

    private func startBorderAnimationIfNeeded() {
        guard !reduceMotion else { return }

        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismissBanner()
            }
        }
    }

    private func dismissBanner() {
        autoDismissTask?.cancel()
        onDismiss()
    }

    private func gameIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct ArcadeBlackBannerBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.05)

            GeometryReader { _ in
                Canvas { context, size in
                    let spacing: CGFloat = 14
                    var offset: CGFloat = -size.height

                    while offset < size.width + size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset + size.height * 0.55, y: size.height))
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(0.08)),
                            lineWidth: 1
                        )
                        offset += spacing
                    }
                }
            }

            LinearGradient(
                colors: [.green.opacity(0.14), .clear, .cyan.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("ruido")
                .resizable()
                .scaledToFill()
                .opacity(0.28)
                .blendMode(.softLight)
        }
        .colorScheme(.dark)
    }
}
