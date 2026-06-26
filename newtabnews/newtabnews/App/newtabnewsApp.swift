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
        #if DEBUG
        print("📬 Push handlers registrados (AppDelegate + UNUserNotificationCenter)")
        #endif

        registerForPushIfNeeded(application)

        return true
    }

    private func registerForPushIfNeeded(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                #if DEBUG
                print("🔔 Permissão de notificação: \(settings.authorizationStatus.rawValue)")
                #endif
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    application.registerForRemoteNotifications()
                default:
                    break
                }
            }
        }
    }

    static func registerForPushNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        print("📱 APNs token registrado (sandbox): \(deviceToken.map { String(format: "%02x", $0) }.joined())")
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        #endif

        refreshFCMTokenAfterAPNS()
    }

    private func refreshFCMTokenAfterAPNS() {
        Messaging.messaging().token { token, error in
            guard let token, error == nil else {
                #if DEBUG
                if let error {
                    print("❌ Erro ao atualizar FCM token: \(error.localizedDescription)")
                }
                #endif
                return
            }

            DispatchQueue.main.async {
                #if DEBUG
                print("📱 FCM Token (atualizado): \(token)")
                print("📱 APNs vinculado ao FCM: sim")
                #endif
                FirebasePushNotificationService.shared.saveDeviceToken(token)
                Messaging.messaging().subscribe(toTopic: "all_users") { error in
                    #if DEBUG
                    if let error {
                        print("❌ Erro ao inscrever no tópico: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
        }
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("❌ Falha ao registrar para notificações: \(error.localizedDescription)")
        #endif
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        #if DEBUG
        print("📬 Push remoto recebido (background): \(userInfo)")
        #endif
        Messaging.messaging().appDidReceiveMessage(userInfo)
        WatchSyncManager.shared.forwardNotificationToWatch(userInfo: userInfo)
        completionHandler(.newData)
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        guard Messaging.messaging().apnsToken != nil else {
            #if DEBUG
            print("⚠️ FCM token ignorado — APNs ainda não registrado")
            #endif
            return
        }

        #if DEBUG
        print("📱 FCM Token: \(token)")
        print("📱 APNs vinculado ao FCM: sim")
        #endif

        FirebasePushNotificationService.shared.saveDeviceToken(token)

        Messaging.messaging().subscribe(toTopic: "all_users") { error in
            #if DEBUG
            if let error {
                print("❌ Erro ao inscrever no tópico: \(error.localizedDescription)")
            }
            #endif
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        #if DEBUG
        print("📬 Push remoto recebido (foreground): \(userInfo)")
        #endif
        Messaging.messaging().appDidReceiveMessage(userInfo)
        WatchSyncManager.shared.forwardNotificationToWatch(userInfo: userInfo)
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
            #if DEBUG
            if let error {
                print("❌ Erro ao limpar badge: \(error.localizedDescription)")
            }
            #endif
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
