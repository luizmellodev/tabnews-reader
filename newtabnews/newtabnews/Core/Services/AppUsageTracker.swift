//
//  AppUsageTracker.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/11/25.
//

import Foundation
import Combine
import SwiftUI
import StoreKit
import UIKit

@MainActor
final class AppReviewManager: ObservableObject {
    static let shared = AppReviewManager()
    
    static let appStoreID = "6755933359"
    
    @Published var showPrePrompt = false
    
    private enum Keys {
        static let newsletterVisits = "newsletterOpenCount"
        static let sessionCount = "appReviewSessionCount"
        static let lastPrePromptDate = "lastReviewPrePromptDate"
        static let lastReviewRequestDate = "lastReviewRequestDate"
    }
    
    private let minNewsletterVisits = 3
    private let minAppSessions = 5
    private let prePromptCooldownDays = 60
    
    private var countedCurrentForegroundSession = false
    
    private init() {}
    
    private var appStoreReviewDeepLink: URL {
        URL(string: "itms-apps://itunes.apple.com/app/id\(Self.appStoreID)?action=write-review")!
    }
    
    private var appStoreReviewWebURL: URL {
        let region = Locale.current.region?.identifier.lowercased() ?? "br"
        return URL(string: "https://apps.apple.com/\(region)/app/tabnews-reader/id\(Self.appStoreID)?action=write-review")!
    }
    
    func handleAppBecameActive() {
        guard !countedCurrentForegroundSession else { return }
        countedCurrentForegroundSession = true
        
        let sessions = UserDefaults.standard.integer(forKey: Keys.sessionCount) + 1
        UserDefaults.standard.set(sessions, forKey: Keys.sessionCount)
        
        evaluatePrePrompt()
    }
    
    func handleAppEnteredBackground() {
        countedCurrentForegroundSession = false
    }
    
    func recordNewsletterVisit() {
        let visits = UserDefaults.standard.integer(forKey: Keys.newsletterVisits) + 1
        UserDefaults.standard.set(visits, forKey: Keys.newsletterVisits)
        
        evaluatePrePrompt()
    }
    
    func openAppStoreReviewPage() {
        UIApplication.shared.open(appStoreReviewDeepLink) { [appStoreReviewWebURL] opened in
            if !opened {
                UIApplication.shared.open(appStoreReviewWebURL)
            }
        }
    }
    
    func confirmPositiveReview() {
        showPrePrompt = false
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastReviewRequestDate)
    }
    
    func dismissPrePrompt() {
        showPrePrompt = false
    }
    
    #if DEBUG
    func resetForTesting() {
        UserDefaults.standard.set(0, forKey: Keys.newsletterVisits)
        UserDefaults.standard.set(0, forKey: Keys.sessionCount)
        UserDefaults.standard.set(0, forKey: Keys.lastPrePromptDate)
        UserDefaults.standard.set(0, forKey: Keys.lastReviewRequestDate)
        showPrePrompt = false
        countedCurrentForegroundSession = false
    }
    #endif
    
    private func evaluatePrePrompt() {
        guard !showPrePrompt else { return }
        guard qualifiesForPrePrompt else { return }
        guard isPrePromptCooldownElapsed else { return }
        
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastPrePromptDate)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showPrePrompt = true
        }
    }
    
    private var qualifiesForPrePrompt: Bool {
        let newsletterVisits = UserDefaults.standard.integer(forKey: Keys.newsletterVisits)
        let sessions = UserDefaults.standard.integer(forKey: Keys.sessionCount)
        return newsletterVisits >= minNewsletterVisits || sessions >= minAppSessions
    }
    
    private var isPrePromptCooldownElapsed: Bool {
        let lastPrePrompt = UserDefaults.standard.double(forKey: Keys.lastPrePromptDate)
        guard lastPrePrompt > 0 else { return true }
        
        let daysSince = (Date().timeIntervalSince1970 - lastPrePrompt) / 86_400
        return daysSince >= Double(prePromptCooldownDays)
    }
}
