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

                    Text("Wordle · Leet · Spot · Color · Sound")
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
            return "DevWordle e DevLeet novos · toque para jogar"
        case (true, false):
            return "Novo DevWordle hoje · toque para jogar"
        case (false, true):
            return "Novo DevLeet esta semana · toque para jogar"
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

struct RestGamesNewPuzzleBanner: View {
    let state: RestGamesNewPuzzlePrompt.State
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 5) {
                    Text(state.message)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 28, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar aviso")
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .background(Color(red: 0.04, green: 0.04, blue: 0.05))
        .colorScheme(.dark)
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
