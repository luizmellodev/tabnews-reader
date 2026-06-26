//
//  NotificationManager.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import Foundation
import UIKit
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isPermissionGranted = false
    
    private init() {
        checkPermission()
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = success
                if success {
                    AppDelegate.registerForPushNotifications()
                    #if DEBUG
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        print("🔔 Permissão após autorizar: \(settings.authorizationStatus.rawValue) (2=autorizado)")
                    }
                    #endif
                }
            }
            if let error = error {
                print("Erro ao solicitar permissão: \(error.localizedDescription)")
            }
        }
    }
}
