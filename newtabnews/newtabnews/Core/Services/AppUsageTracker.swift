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

class AppUsageTracker: ObservableObject {
    static let shared = AppUsageTracker()
    
    @Published var totalSecondsInApp: Int = 0
    @Published var shouldShowRestFolder: Bool = false
    @Published var shouldShowGameButton: Bool = false
    
    private var timer: Timer?
    private let gameButtonThreshold = 3600 // 1 hora (60 minutos)
    private let restFolderThreshold = 7200 // 2 horas (120 minutos)
    
    private init() {
        loadUsageData()
        startTracking()
    }
    
    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.totalSecondsInApp += 1
            self.saveUsageData()
            self.checkThresholds()
        }
    }
    
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkThresholds() {
        // Mostrar botão de jogo após 1 hora (easter egg raro)
        if totalSecondsInApp >= gameButtonThreshold && !shouldShowGameButton {
            shouldShowGameButton = true
            UserDefaults.standard.set(true, forKey: "hasShownGameButton")
        }
        
        // Mostrar pasta "Descanse" após 2 horas (easter egg muito raro)
        if totalSecondsInApp >= restFolderThreshold && !shouldShowRestFolder {
            shouldShowRestFolder = true
            UserDefaults.standard.set(true, forKey: "hasShownRestFolder")
        }
    }
    
    private func saveUsageData() {
        UserDefaults.standard.set(totalSecondsInApp, forKey: "totalSecondsInApp")
    }
    
    private func loadUsageData() {
        totalSecondsInApp = UserDefaults.standard.integer(forKey: "totalSecondsInApp")
        shouldShowGameButton = UserDefaults.standard.bool(forKey: "hasShownGameButton")
        shouldShowRestFolder = UserDefaults.standard.bool(forKey: "hasShownRestFolder")
    }
    
    func resetUsageForTesting() {
        totalSecondsInApp = 0
        shouldShowGameButton = false
        shouldShowRestFolder = false
        UserDefaults.standard.set(0, forKey: "totalSecondsInApp")
        UserDefaults.standard.set(false, forKey: "hasShownGameButton")
        UserDefaults.standard.set(false, forKey: "hasShownRestFolder")
    }
    
    var formattedTime: String {
        let minutes = totalSecondsInApp / 60
        let seconds = totalSecondsInApp % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

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

