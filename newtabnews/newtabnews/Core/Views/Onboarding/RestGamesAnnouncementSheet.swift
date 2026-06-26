import SwiftUI

enum RestGamesAnnouncement {
    static let storageKey = "hasSeenRestGamesAnnouncement"
    static let seenVersionKey = "restGamesAnnouncementSeenVersion"
    static let introVersion = "3.0"

    static var shouldShow: Bool {
        UserDefaults.standard.string(forKey: seenVersionKey) != introVersion
    }

    static var hasSeen: Bool {
        !shouldShow
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: storageKey)
        UserDefaults.standard.set(introVersion, forKey: seenVersionKey)
    }

    /// Corrige estado legado (ex.: onboarding marcava como visto antes da sheet aparecer).
    static func prepareForLaunchIfNeeded() {
        guard UserDefaults.standard.string(forKey: seenVersionKey) == nil else { return }
        guard UserDefaults.standard.bool(forKey: storageKey) else { return }

        UserDefaults.standard.set(false, forKey: storageKey)
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.set(false, forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: seenVersionKey)
    }
    #endif
}

struct RestGamesAnnouncementSheet: View {
    let onPlay: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                Text("NOVIDADE!")
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(.orange)

                Text("JOGOS DEV")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.white)

                Text("Mini games entre as leituras.\nRankings no Game Center.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onPlay) {
                    Text("Jogar agora")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white, in: Capsule())
                }

                Button(action: onLater) {
                    Text("Ver depois na aba Perfil")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ArcadeBlackBannerBackground()
                .ignoresSafeArea()
        }
    }
}
