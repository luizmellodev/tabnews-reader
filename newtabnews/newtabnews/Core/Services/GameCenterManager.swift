import Foundation
import GameKit
import UIKit

enum RestGameLeaderboard: String, CaseIterable, Identifiable {
    case devWordle = "tabnews.devwordle.best"
    case devSpot = "tabnews.devspot.best"
    case colorMatch = "tabnews.colormatch.best"
    case soundMatch = "tabnews.soundmatch.best"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .devWordle: return "DevWordle"
        case .devSpot: return "DevSpot"
        case .colorMatch: return "Color Match"
        case .soundMatch: return "Sound Match"
        }
    }

    var icon: String {
        switch self {
        case .devWordle: return "character.textbox"
        case .devSpot: return "brain.head.profile"
        case .colorMatch: return "paintpalette.fill"
        case .soundMatch: return "waveform"
        }
    }
}

@MainActor
final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var authenticationError: String?

    private init() {}

    func authenticate() {
        GKAccessPoint.shared.isActive = false

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }

                if let viewController {
                    self.presentAuthViewController(viewController)
                    return
                }

                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.authenticationError = self.isAuthenticated ? nil : error?.localizedDescription
            }
        }
    }

    func submitScore(_ score: Int, to leaderboard: RestGameLeaderboard) {
        guard GKLocalPlayer.local.isAuthenticated, score > 0 else { return }

        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard.rawValue]
        ) { error in
            if let error {
                print("Game Center score submit failed (\(leaderboard.rawValue)): \(error.localizedDescription)")
            }
        }
    }

    func submitDevWordleScore(attempts: Int) {
        submitScore(7 - attempts, to: .devWordle)
    }

    func submitDevSpotScore(correctCount: Int) {
        submitScore(correctCount * 100, to: .devSpot)
    }

    func submitArcadeScore(totalScore: Double, gameType: RestGameType) {
        let leaderboard: RestGameLeaderboard = gameType == .color ? .colorMatch : .soundMatch
        submitScore(Int(totalScore * 100), to: leaderboard)
    }

    func showLeaderboard(_ leaderboard: RestGameLeaderboard) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        GKAccessPoint.shared.trigger(
            leaderboardID: leaderboard.rawValue,
            playerScope: .global,
            timeScope: .allTime
        ) { }
    }

    private func presentAuthViewController(_ viewController: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return
        }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        presenter.present(viewController, animated: true)
    }
}
