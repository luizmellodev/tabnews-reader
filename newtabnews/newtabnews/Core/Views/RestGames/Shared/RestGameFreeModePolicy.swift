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
        if !isAllowed {
            ToastManager.shared.show(
                text: "Modo livre bloqueado por padrão para manter a diversão do diário. Ative em Ajustes se quiser.",
                icon: "lock.fill"
            )
        } else if !dailyComplete {
            ToastManager.shared.show(
                text: "Complete o desafio diário para liberar o modo livre.",
                icon: "calendar"
            )
        }
        RestFeedbackManager.shared.wrong()
    }

    static func modeSubtitle(
        isFreeModeActive: Bool,
        dailyComplete: Bool,
        isAllowed: Bool,
        freeModeDetail: String,
        dailyCompleteDetail: String
    ) -> String {
        if isFreeModeActive {
            return freeModeDetail
        }
        if !isAllowed {
            return "Modo livre desativado · ative em Ajustes"
        }
        if dailyComplete {
            return dailyCompleteDetail
        }
        return "Complete o diário para liberar o modo livre"
    }

    static func lockedCaption(dailyComplete: Bool, isAllowed: Bool) -> String {
        if !isAllowed {
            return "Modo livre desativado · ative em Ajustes"
        }
        if !dailyComplete {
            return "Complete o desafio diário para liberar o modo livre"
        }
        return ""
    }
}
