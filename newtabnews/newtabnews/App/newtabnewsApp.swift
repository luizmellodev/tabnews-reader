//
//  newtabnewsApp.swift
//  newtabnews
//
//  Created by Luiz Mello on 01/07/23.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Falha ao registrar para notificações: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        WatchSyncManager.shared.forwardNotificationToWatch(userInfo: userInfo)
        completionHandler(.noData)
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        
        FirebasePushNotificationService.shared.saveDeviceToken(token)
        
        Messaging.messaging().subscribe(toTopic: "all_users") { error in
            if let error = error {
                print("❌ Erro ao inscrever no tópico: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        WatchSyncManager.shared.forwardNotificationToWatch(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        clearBadge()
        NotificationHandler.shared.handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("❌ Erro ao limpar badge: \(error.localizedDescription)")
            }
        }
    }
}

@main
struct newtabnewsApp: App {
    private let dependencies = AppDependencies.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        NotificationManager.shared.requestPermission()
        GameCenterManager.shared.authenticate()
        _ = WatchSyncManager.shared
        _ = BetaTesterService.shared
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView(
                contentService: dependencies.contentService,
                viewModel: dependencies.makeMainViewModel(),
                newsletterVM: dependencies.makeNewsletterViewModel()
            )
        }
        .modelContainer(for: [Folder.self, Highlight.self, Note.self, SavedPost.self])
    }
}
