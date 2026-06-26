import Foundation

enum RestGameFreeModePolicy {
    static let storageKey = "restGamesAllowFreeMode"

    static var isAllowed: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func isUnlocked(dailyComplete: Bool, isAllowed: Bool = UserDefaults.standard.bool(forKey: storageKey)) -> Bool {
        isAllowed && dailyComplete
    }

    @MainActor
    static func handleLockedAttempt(dailyComplete: Bool, isAllowed: Bool = UserDefaults.standard.bool(forKey: storageKey)) {
        RestFeedbackManager.shared.wrong()
    }

    static func modeSubtitle(
        isFreeModeActive: Bool,
        dailyComplete: Bool,
        isAllowed: Bool,
        freeModeDetail: String,
        dailyCompleteDetail: String,
        showLockedHint: Bool = false
    ) -> String {
        if isFreeModeActive {
            return freeModeDetail
        }
        if showLockedHint {
            return lockedCaption(dailyComplete: dailyComplete, isAllowed: isAllowed)
        }
        if dailyComplete && isAllowed {
            return dailyCompleteDetail
        }
        return ""
    }

    static func lockedCaption(dailyComplete: Bool, isAllowed: Bool) -> String {
        if !isAllowed {
            return "Modo livre desativado · ative na hub de jogos"
        }
        if !dailyComplete {
            return "Complete o desafio diário para liberar o modo livre"
        }
        return ""
    }
}
