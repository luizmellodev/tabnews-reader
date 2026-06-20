//
//  WatchSyncManager.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/11/25.
//

import Foundation
import WatchConnectivity
#if os(iOS)
import UIKit
#endif

class WatchSyncManager: NSObject {
    static let shared = WatchSyncManager()
    
    private var session: WCSession?
    private var isActivated = false
    private var pendingSyncData: (() -> Void)?
    
    private override init() {
        super.init()
        
        #if !os(watchOS)
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        #else
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        #endif
    }
    
    // MARK: - Enviar (iOS → Watch)
    #if !os(watchOS)
    func syncToWatch(posts: [PostRequest], likedPosts: [PostRequest], stats: [String: Int]) {
        guard let session = session else {
            return
        }
        
        let state = session.activationState
        
        if state != .activated {
            pendingSyncData = { [weak self] in
                self?.performSync(posts: posts, likedPosts: likedPosts, stats: stats)
            }
            session.activate()
            return
        }
        
        #if os(iOS)
        guard session.isPaired && session.isWatchAppInstalled else {
            return
        }
        #endif
        
        performSync(posts: posts, likedPosts: likedPosts, stats: stats)
    }
    
    private func performSync(posts: [PostRequest], likedPosts: [PostRequest], stats: [String: Int]) {
        guard let session = session, session.activationState == .activated else {
            return
        }
        
        guard let postsData = try? JSONEncoder().encode(posts),
              let postsJSON = String(data: postsData, encoding: .utf8) else {
            return
        }
        
        guard let likedData = try? JSONEncoder().encode(likedPosts),
              let likedJSON = String(data: likedData, encoding: .utf8) else {
            return
        }
        
        let message: [String: Any] = [
            "posts": postsJSON,
            "likedPosts": likedJSON,
            "stats": stats
        ]
        
        try? session.updateApplicationContext(message)
    }
    
    func forwardNotificationToWatch(userInfo: [AnyHashable: Any]) {
        guard shouldForwardNotificationToWatch() else { return }
        
        guard let session = session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }
        
        let payload = NotificationPayloadParser.parse(userInfo)
        guard payload.hasContent else { return }
        
        var message: [String: Any] = [
            "notificationForward": true,
            "title": payload.title,
            "body": payload.body,
            "id": payload.stableId
        ]
        
        if let type = payload.type { message["type"] = type }
        if let owner = payload.owner { message["owner"] = owner }
        if let slug = payload.slug { message["slug"] = slug }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }
    
    private func shouldForwardNotificationToWatch() -> Bool {
        #if os(iOS)
        // Quando o iPhone está em uso, a Apple não espelha pro Watch — encaminhamos manualmente.
        // Quando bloqueado/em background, o espelhamento nativo cuida disso.
        return UIApplication.shared.applicationState == .active
        #else
        return false
        #endif
    }
    
    #endif
    
    // MARK: - Helper
    private func stateDescription(_ state: WCSessionActivationState) -> String {
        switch state {
        case .notActivated:
            return "Not Activated"
        case .inactive:
            return "Inactive"
        case .activated:
            return "Activated"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Delegate
extension WatchSyncManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if error != nil {
            isActivated = false
            return
        }
        
        isActivated = (activationState == .activated)
        
        #if !os(watchOS)
        if isActivated, let pendingSync = pendingSyncData {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pendingSync()
                self.pendingSyncData = nil
            }
        }
        #endif
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        #if os(watchOS)
        handleWatchNotificationForward(applicationContext)
        
        if let postsJSON = applicationContext["posts"] as? String,
           let postsData = postsJSON.data(using: .utf8) {
            UserDefaults.standard.set(postsData, forKey: "WatchPosts")
        }
        
        if let likedJSON = applicationContext["likedPosts"] as? String,
           let likedData = likedJSON.data(using: .utf8) {
                UserDefaults.standard.set(likedData, forKey: "WatchLikedPosts")
        }
        
        if let stats = applicationContext["stats"] as? [String: Int] {
            UserDefaults.standard.set(stats["liked"] ?? 0, forKey: "WatchLiked")
            UserDefaults.standard.set(stats["highlights"] ?? 0, forKey: "WatchHighlights")
            UserDefaults.standard.set(stats["notes"] ?? 0, forKey: "WatchNotes")
            UserDefaults.standard.set(stats["folders"] ?? 0, forKey: "WatchFolders")
        }
        
        UserDefaults.standard.synchronize()
        #else
        if let likedJSON = applicationContext["watchLikedPosts"] as? String,
           let likedData = likedJSON.data(using: .utf8),
           let watchLikedPosts = try? JSONDecoder().decode([PostRequest].self, from: likedData) {
            
            NotificationCenter.default.post(
                name: .watchLikedPostsReceived,
                object: watchLikedPosts
            )
        }
        #endif
    }
    
    #if os(watchOS)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchNotificationForward(message)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleWatchNotificationForward(userInfo)
    }
    
    private func handleWatchNotificationForward(_ data: [String: Any]) {
        guard data["notificationForward"] as? Bool == true else { return }
        
        let payload = ParsedNotificationPayload(
            title: data["title"] as? String ?? "TabNews",
            body: data["body"] as? String ?? "",
            type: data["type"] as? String,
            owner: data["owner"] as? String,
            slug: data["slug"] as? String,
            stableId: data["id"] as? String ?? UUID().uuidString
        )
        
        WatchNotificationManager.shared.displayNotification(from: payload)
    }
    #endif
    
    #if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

