//
//  NotificationHandler.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation

class NotificationHandler {
        
    static let shared = NotificationHandler()
    
    private init() {}
    
    /// Processa o toque na notificação e navega para o destino apropriado
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let notificationType = NotificationType(rawValue: typeString) else {
            #if DEBUG
            print("⚠️ Tipo de notificação inválido ou não encontrado")
            #endif
            return
        }
        
        // Extrair dados do post (se disponíveis)
        let owner = userInfo["owner"] as? String ?? ""
        let slug = userInfo["slug"] as? String ?? ""
        
        // Se tem dados completos do post, abrir post específico
        if !owner.isEmpty && !slug.isEmpty {
            openPost(owner: owner, slug: slug, type: notificationType)
        } else {
            // Fallback: apenas abrir aba correspondente
            if notificationType.isNewsletter {
                openNewsletterTab()
            } else if notificationType.isDigest {
                openDigestTab()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Abre um post específico via deep link
    private func openPost(owner: String, slug: String, type: NotificationType) {
        #if DEBUG
        let icon: String
        let destination: String
        
        if type.isNewsletter {
            icon = "📰"
            destination = "Newsletter"
        } else if type.isDigest {
            icon = "🔥"
            destination = "Resumo"
        } else {
            icon = "🔥"
            destination = "Home"
        }
        
        print("\(icon) Abrindo post em \(destination): \(owner)/\(slug)")
        #endif
        
        let postData = PostDeepLinkData(owner: owner, slug: slug, type: type)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: .openPostFromNotification,
                object: postData
            )
        }
    }
    
    /// Abre apenas a aba Newsletter (sem post específico)
    private func openNewsletterTab() {
        #if DEBUG
        print("📰 Abrindo aba Newsletter")
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openNewsletterTab, object: nil)
        }
    }
    
    /// Abre apenas a aba Digest (sem post específico)
    private func openDigestTab() {
        #if DEBUG
        print("🔥 Abrindo aba Resumo")
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .navigateToDigest, object: nil)
        }
    }
}
