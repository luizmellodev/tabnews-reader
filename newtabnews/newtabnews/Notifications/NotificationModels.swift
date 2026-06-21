//
//  NotificationType.swift
//  newtabnews
//
//  Created by Luiz Mello on 24/12/25.
//

import Foundation

enum NotificationType: String {
    case newsletter
    case testNewsletter = "test_newsletter"
    case relevant
    case testRelevant = "test_relevant"
    case digest
    case testDigest = "test_digest"
    
    var isNewsletter: Bool {
        self == .newsletter || self == .testNewsletter
    }
    
    var isRelevant: Bool {
        self == .relevant || self == .testRelevant
    }
    
    var isDigest: Bool {
        self == .digest || self == .testDigest
    }
}

struct PostDeepLinkData {
    let owner: String
    let slug: String
    let type: NotificationType
}

extension Notification.Name {
    static let openNewsletterTab = Notification.Name("openNewsletterTab")
    static let openPostFromNotification = Notification.Name("openPostFromNotification")
    static let navigateToDigest = Notification.Name("navigateToDigest")
    static let highlightsUpdated = Notification.Name("highlightsUpdated")
    static let notesUpdated = Notification.Name("notesUpdated")
    static let foldersUpdated = Notification.Name("foldersUpdated")
    static let watchLikedPostsReceived = Notification.Name("watchLikedPostsReceived")
    static let showTipsOnboarding = Notification.Name("showTipsOnboarding")
    static let showRestGamesAnnouncement = Notification.Name("showRestGamesAnnouncement")
    static let showRestGamesHub = Notification.Name("showRestGamesHub")
    static let simulateFirstPostLongPress = Notification.Name("simulateFirstPostLongPress")
    static let dismissContextMenu = Notification.Name("dismissContextMenu")
    static let navigateToHome = Notification.Name("navigateToHome")
    static let openLoginWebView = Notification.Name("openLoginWebView")
}
