import Foundation
import GameKit
import UIKit

enum RestGameAchievement: String, CaseIterable, Identifiable {
    // DevWordle
    case wordleFirstWin = "tabnews.devwordle.first_win"
    case wordleWins5 = "tabnews.devwordle.wins_5"
    case wordleWins10 = "tabnews.devwordle.wins_10"
    case wordleWins25 = "tabnews.devwordle.wins_25"
    case wordleWins50 = "tabnews.devwordle.wins_50"
    case wordleStreak7 = "tabnews.devwordle.streak_7"
    case wordleStreak30 = "tabnews.devwordle.streak_30"
    case wordleGenius = "tabnews.devwordle.genius"
    case wordleSharp = "tabnews.devwordle.sharp"

    // DevLeet
    case leetFirstSolve = "tabnews.devleet.first_solve"
    case leetSolves5 = "tabnews.devleet.solves_5"
    case leetSolves10 = "tabnews.devleet.solves_10"
    case leetSolves25 = "tabnews.devleet.solves_25"
    case leetStreak3 = "tabnews.devleet.streak_3"
    case leetStreak5 = "tabnews.devleet.streak_5"
    case leetStreak10 = "tabnews.devleet.streak_10"
    case leetHardMode = "tabnews.devleet.hard_mode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wordleFirstWin: return "Primeiro DevWordle"
        case .wordleWins5: return "Palpiteiro"
        case .wordleWins10: return "Cracker de Código"
        case .wordleWins25: return "Lexicógrafo Dev"
        case .wordleWins50: return "Mestre das Letras"
        case .wordleStreak7: return "Sequência Semanal"
        case .wordleStreak30: return "Imparável"
        case .wordleGenius: return "Gênio"
        case .wordleSharp: return "Precisão"
        case .leetFirstSolve: return "Primeiro Algoritmo"
        case .leetSolves5: return "Coder Iniciante"
        case .leetSolves10: return "Problem Solver"
        case .leetSolves25: return "Engenheiro Dev"
        case .leetStreak3: return "Leet Consistente"
        case .leetStreak5: return "Leet Dedicado"
        case .leetStreak10: return "Veterano Leet"
        case .leetHardMode: return "Modo Hard"
        }
    }

    var goal: Int {
        switch self {
        case .wordleFirstWin, .wordleGenius, .leetFirstSolve, .leetHardMode: return 1
        case .wordleWins5, .wordleSharp, .leetSolves5: return 5
        case .wordleWins10, .leetSolves10: return 10
        case .wordleWins25, .leetSolves25: return 25
        case .wordleWins50: return 50
        case .wordleStreak7: return 7
        case .wordleStreak30: return 30
        case .leetStreak3: return 3
        case .leetStreak5: return 5
        case .leetStreak10: return 10
        }
    }

    func progress(from stats: GamificationStats) -> Int {
        switch self {
        case .wordleFirstWin, .wordleWins5, .wordleWins10, .wordleWins25, .wordleWins50:
            return stats.devWordleWins
        case .wordleStreak7, .wordleStreak30:
            return stats.devWordleStreak
        case .wordleGenius:
            return stats.devWordleFirstTryWins
        case .wordleSharp:
            return stats.devWordleTwoOrLessWins
        case .leetFirstSolve, .leetSolves5, .leetSolves10, .leetSolves25:
            return stats.devLeetSolves
        case .leetStreak3, .leetStreak5, .leetStreak10:
            return stats.devLeetStreak
        case .leetHardMode:
            return stats.devLeetHardSolves
        }
    }
}

enum RestGameLeaderboard: String, CaseIterable, Identifiable {
    case devWordle = "tabnews.devwordle.best"
    case devSpot = "tabnews.devspot.best"
    case bigO = "tabnews.bigo.best"
    case colorMatch = "tabnews.colormatch.best"
    case soundMatch = "tabnews.soundmatch.best"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .devWordle: return "DevWordle"
        case .devSpot: return "DevSpot"
        case .bigO: return "Big O"
        case .colorMatch: return "Color Match"
        case .soundMatch: return "Sound Match"
        }
    }

    var icon: String {
        switch self {
        case .devWordle: return "character.textbox"
        case .devSpot: return "brain.head.profile"
        case .bigO: return "function"
        case .colorMatch: return "paintpalette.fill"
        case .soundMatch: return "waveform"
        }
    }

    var preferredTimeScope: GKLeaderboard.TimeScope {
        switch self {
        case .devWordle: return .week
        case .devSpot, .bigO, .colorMatch, .soundMatch: return .allTime
        }
    }
}

@MainActor
final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    /// Flip to `true` after achievements are configured in App Store Connect.
    static let achievementsEnabled = false

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

    func syncRestGameAchievements(from stats: GamificationStats) {
        guard Self.achievementsEnabled else { return }
        guard GKLocalPlayer.local.isAuthenticated else { return }

        let achievements = RestGameAchievement.allCases.compactMap { type -> GKAchievement? in
            let progress = type.progress(from: stats)
            guard progress > 0 else { return nil }

            let percent = min(100.0, Double(progress) / Double(type.goal) * 100.0)
            let achievement = GKAchievement(identifier: type.rawValue)
            achievement.percentComplete = percent
            achievement.showsCompletionBanner = percent >= 100
            return achievement
        }

        guard !achievements.isEmpty else { return }

        GKAchievement.report(achievements) { error in
            if let error {
                print("Game Center achievements sync failed: \(error.localizedDescription)")
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

    func submitBigOScore(correctCount: Int) {
        submitScore(correctCount * 100, to: .bigO)
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
            timeScope: leaderboard.preferredTimeScope
        ) { }
    }

    func showAchievements() {
        guard Self.achievementsEnabled else { return }
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .achievements) { }
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
