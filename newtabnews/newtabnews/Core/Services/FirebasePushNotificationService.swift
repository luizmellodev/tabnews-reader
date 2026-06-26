//
//  FirebasePushNotificationService.swift
//  newtabnews
//
//  Created by Luiz Mello on 23/12/25.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

class FirebasePushNotificationService {
    static let shared = FirebasePushNotificationService()
    
    private let db = Firestore.firestore()
    private let collectionName = "tabnews_deviceTokens"
    
    private init() {}
    
    func saveDeviceToken(_ token: String) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
        let tokenData: [String: Any] = [
            "token": token,
            "deviceId": deviceId,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection(collectionName)
            .document(token)
            .setData(tokenData, merge: true) { error in
                if let error = error {
                    print("❌ Erro ao salvar token: \(error.localizedDescription)")
                }
            }
    }
    
    func removeDeviceToken() {
        Messaging.messaging().token { token, error in
            guard let token = token, error == nil else { return }
            
            self.db.collection(self.collectionName)
                .document(token)
                .delete { error in
                    if let error = error {
                        print("❌ Erro ao remover token: \(error.localizedDescription)")
                    }
                }
        }
    }
    
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    struct DebugInfo: Identifiable {
        let id = UUID()
        let fcmToken: String
        let deviceId: String
        let permissionStatus: String
        let apnsTokenRegistered: Bool
    }

    func fetchDebugInfo(completion: @escaping (DebugInfo) -> Void) {
        Messaging.messaging().token { token, error in
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            let fcmToken = token ?? "indisponível (\(error?.localizedDescription ?? "erro desconhecido"))"
            let apnsRegistered = Messaging.messaging().apnsToken != nil

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    completion(DebugInfo(
                        fcmToken: fcmToken,
                        deviceId: deviceId,
                        permissionStatus: Self.permissionLabel(settings.authorizationStatus),
                        apnsTokenRegistered: apnsRegistered
                    ))
                }
            }
        }
    }

    func sendLocalTestNotification(completion: @escaping (String) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "🧪 Teste local"
        content.body = "Se você viu isso, o iOS exibe notificações deste app."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "push-debug-local-test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    completion("Erro: \(error.localizedDescription)")
                } else {
                    completion("Agendada — deve aparecer em ~1s")
                }
            }
        }
    }

    private static func permissionLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: "autorizado"
        case .denied: "negado"
        case .notDetermined: "não solicitado"
        case .provisional: "provisório"
        case .ephemeral: "ephemeral"
        @unknown default: "desconhecido"
        }
    }
}

