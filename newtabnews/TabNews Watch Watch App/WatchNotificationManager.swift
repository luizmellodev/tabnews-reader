//
//  WatchNotificationManager.swift
//  TabNews Watch Watch App
//

import Foundation
import UserNotifications

final class WatchNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WatchNotificationManager()
    
    private var recentNotificationIds = Set<String>()
    
    private override init() {
        super.init()
    }
    
    func setup() {
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("⌚ Erro ao solicitar permissão de notificação: \(error.localizedDescription)")
                return
            }
            print("⌚ Permissão de notificação: \(granted ? "concedida" : "negada")")
        }
    }
    
    func displayNotification(from payload: ParsedNotificationPayload) {
        guard payload.hasContent else { return }
        guard !recentNotificationIds.contains(payload.stableId) else { return }
        
        recentNotificationIds.insert(payload.stableId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.recentNotificationIds.remove(payload.stableId)
        }
        
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.userInfo = payload.userInfo
        
        let request = UNNotificationRequest(
            identifier: payload.stableId,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("⌚ Erro ao exibir notificação: \(error.localizedDescription)")
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
