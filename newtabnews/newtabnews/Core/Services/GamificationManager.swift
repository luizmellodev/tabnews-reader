//
//  GamificationManager.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/02/26.
//

import Foundation
import SwiftUI
import Combine

class GamificationManager: ObservableObject {
    static let shared = GamificationManager()
    
    @Published var unlockedBadges: [Badge] = []
    @Published var weeklyChallenges: [WeeklyChallenge] = []
    @Published var stats: GamificationStats = GamificationStats()
    @Published var showBadgeUnlocked: Badge?
    
    private let badgesKey = "unlocked_badges"
    private let challengesKey = "weekly_challenges"
    private let statsKey = "gamification_stats"
    private let lastWeekResetKey = "last_week_reset"
    
    private init() {
        loadData()
        checkWeeklyReset()
    }
    
    // MARK: - Data Management
    
    private func loadData() {
        if let badgesData = UserDefaults.standard.data(forKey: badgesKey),
           let badges = try? JSONDecoder().decode([Badge].self, from: badgesData) {
            unlockedBadges = badges
        }
        
        if let challengesData = UserDefaults.standard.data(forKey: challengesKey),
           let challenges = try? JSONDecoder().decode([WeeklyChallenge].self, from: challengesData) {
            weeklyChallenges = challenges
        }
        
        if let statsData = UserDefaults.standard.data(forKey: statsKey),
           let loadedStats = try? JSONDecoder().decode(GamificationStats.self, from: statsData) {
            stats = loadedStats
        }
    }
    
    private func saveData() {
        if let badgesData = try? JSONEncoder().encode(unlockedBadges) {
            UserDefaults.standard.set(badgesData, forKey: badgesKey)
        }
        
        if let challengesData = try? JSONEncoder().encode(weeklyChallenges) {
            UserDefaults.standard.set(challengesData, forKey: challengesKey)
        }
        
        if let statsData = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(statsData, forKey: statsKey)
        }
    }
    
    // MARK: - Weekly Challenges
    
    private func checkWeeklyReset() {
        let calendar = Calendar.current
        let now = Date()
        
        if let lastReset = UserDefaults.standard.object(forKey: lastWeekResetKey) as? Date {
            let components = calendar.dateComponents([.weekOfYear], from: lastReset, to: now)
            if let weeks = components.weekOfYear, weeks >= 1 {
                resetWeeklyChallenges()
            }
        } else {
            resetWeeklyChallenges()
        }
    }
    
    private func resetWeeklyChallenges() {
        if !weeklyChallenges.isEmpty, weeklyChallenges.allSatisfy(\.isCompleted) {
            stats.perfectWeeks += 1
            checkAndUnlockBadge(.perfectWeek)
        }

        let calendar = Calendar.current
        let startOfWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let weekStart = calendar.date(from: startOfWeek) else { return }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
        
        let allTypes = ChallengeType.allCases
        let selectedTypes = allTypes.shuffled().prefix(3)
        
        weeklyChallenges = selectedTypes.map { type in
            let goal: Int
            switch type {
            case .readPosts: goal = Int.random(in: 5...12)
            case .commentOnPost: goal = Int.random(in: 1...3)
            case .likeContent: goal = Int.random(in: 3...10)
            case .createHighlights: goal = Int.random(in: 2...6)
            case .saveToFolder: goal = Int.random(in: 2...5)
            case .readCategory: goal = 3
            case .createNotes: goal = Int.random(in: 1...4)
            case .readWeekend: goal = Int.random(in: 2...5)
            case .earlyReader: goal = Int.random(in: 1...3)
            case .nightReader: goal = Int.random(in: 1...3)
            case .shareKnowledge: goal = Int.random(in: 2...4)
            case .discoverNew: goal = Int.random(in: 3...7)
            case .deepDive: goal = Int.random(in: 2...4)
            case .socialButterfly: goal = Int.random(in: 3...8)
            case .curator: goal = Int.random(in: 3...6)
            case .researcher: goal = Int.random(in: 2...4)
            case .winWordle: goal = Int.random(in: 3...5)
            case .playWordle: goal = Int.random(in: 4...7)
            case .solveLeet: goal = 1
            case .wordlePrecision: goal = 1
            }
            
            return WeeklyChallenge(type: type, goal: goal, startDate: weekStart, endDate: weekEnd)
        }
        
        UserDefaults.standard.set(Date(), forKey: lastWeekResetKey)
        saveData()
    }
    
    func updateChallengeProgress(type: ChallengeType, increment: Int = 1) {
        if let index = weeklyChallenges.firstIndex(where: { $0.type == type }) {
            weeklyChallenges[index].progress += increment
            
            if weeklyChallenges[index].isCompleted && weeklyChallenges[index].progress == weeklyChallenges[index].goal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.success)
                }
            }
            
            saveData()
        }
    }
    
    // MARK: - Badge Management
    
    func checkAndUnlockBadge(_ type: BadgeType) {
        guard !hasBadge(type) else { return }
        
        var shouldUnlock = false
        
        switch type {
        case .firstRead: shouldUnlock = stats.postsRead >= 1
        case .reader5: shouldUnlock = stats.postsRead >= 5
        case .reader10: shouldUnlock = stats.postsRead >= 10
        case .reader25: shouldUnlock = stats.postsRead >= 25
        case .reader50: shouldUnlock = stats.postsRead >= 50
        case .reader100: shouldUnlock = stats.postsRead >= 100
        case .reader250: shouldUnlock = stats.postsRead >= 250
        case .reader500: shouldUnlock = stats.postsRead >= 500
        case .firstComment: shouldUnlock = stats.commentsPosted >= 1
        case .commenter5: shouldUnlock = stats.commentsPosted >= 5
        case .commenter10: shouldUnlock = stats.commentsPosted >= 10
        case .commenter25: shouldUnlock = stats.commentsPosted >= 25
        case .commenter50: shouldUnlock = stats.commentsPosted >= 50
        case .firstLike: shouldUnlock = stats.postsLiked >= 1
        case .curator10: shouldUnlock = stats.postsLiked >= 10
        case .curator25: shouldUnlock = stats.postsLiked >= 25
        case .curator50: shouldUnlock = stats.postsLiked >= 50
        case .curator100: shouldUnlock = stats.postsLiked >= 100
        case .firstHighlight: shouldUnlock = stats.highlightsCreated >= 1
        case .highlighter10: shouldUnlock = stats.highlightsCreated >= 10
        case .highlighter25: shouldUnlock = stats.highlightsCreated >= 25
        case .highlighter50: shouldUnlock = stats.highlightsCreated >= 50
        case .firstNote: shouldUnlock = stats.notesCreated >= 1
        case .writer5: shouldUnlock = stats.notesCreated >= 5
        case .writer10: shouldUnlock = stats.notesCreated >= 10
        case .writer25: shouldUnlock = stats.notesCreated >= 25
        case .firstFolder: shouldUnlock = stats.foldersCreated >= 1
        case .organizer5: shouldUnlock = stats.foldersCreated >= 5
        case .organizer10: shouldUnlock = stats.foldersCreated >= 10
        case .weeklyStreak3: shouldUnlock = stats.weeklyStreak >= 3
        case .weeklyStreak5: shouldUnlock = stats.weeklyStreak >= 5
        case .weeklyStreak10: shouldUnlock = stats.weeklyStreak >= 10
        case .weeklyStreak20: shouldUnlock = stats.weeklyStreak >= 20
        case .earlyBird: shouldUnlock = stats.earlyBirdReads >= 1
        case .nightOwl: shouldUnlock = stats.nightOwlReads >= 1
        case .weekendReader: shouldUnlock = stats.weekendReads >= 5
        case .weekendWarrior: shouldUnlock = stats.weekendReads >= 10
        case .speedReader: shouldUnlock = stats.todayReadCount >= 10
        case .perfectWeek: shouldUnlock = stats.perfectWeeks >= 1
        case .socialButterfly: shouldUnlock = (stats.postsLiked + stats.commentsPosted) >= 20
        case .knowledgeSeeker: shouldUnlock = stats.knowledgeSeekerPosts >= 10
        case .masterCurator: shouldUnlock = stats.foldersCreated >= 50
        case .firstWordle: shouldUnlock = stats.devWordleWins >= 1
        case .wordleWins5: shouldUnlock = stats.devWordleWins >= 5
        case .wordleWins10: shouldUnlock = stats.devWordleWins >= 10
        case .wordleWins25: shouldUnlock = stats.devWordleWins >= 25
        case .wordleWins50: shouldUnlock = stats.devWordleWins >= 50
        case .wordleStreak7: shouldUnlock = stats.devWordleStreak >= 7
        case .wordleStreak30: shouldUnlock = stats.devWordleStreak >= 30
        case .wordleGenius: shouldUnlock = stats.devWordleFirstTryWins >= 1
        case .wordleSharp: shouldUnlock = stats.devWordleTwoOrLessWins >= 5
        case .firstLeet: shouldUnlock = stats.devLeetSolves >= 1
        case .leetSolves5: shouldUnlock = stats.devLeetSolves >= 5
        case .leetSolves10: shouldUnlock = stats.devLeetSolves >= 10
        case .leetSolves25: shouldUnlock = stats.devLeetSolves >= 25
        case .leetStreak3: shouldUnlock = stats.devLeetStreak >= 3
        case .leetStreak5: shouldUnlock = stats.devLeetStreak >= 5
        case .leetStreak10: shouldUnlock = stats.devLeetStreak >= 10
        case .leetHardMode: shouldUnlock = stats.devLeetHardSolves >= 1
        }
        
        if shouldUnlock {
            unlockBadge(type)
        }
    }
    
    private func unlockBadge(_ type: BadgeType) {
        let badge = Badge(type: type)
        unlockedBadges.append(badge)
        showBadgeUnlocked = badge
        saveData()
        
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showBadgeUnlocked = nil
        }
    }
    
    func hasBadge(_ type: BadgeType) -> Bool {
        unlockedBadges.contains { $0.type == type }
    }
    
    // MARK: - Stats Tracking
    
    func trackPostRead(postId: String? = nil) {
        stats.postsRead += 1
        incrementDailyReadCount()
        if let postId {
            markPostEngagement(postId: postId, read: true)
        }
        checkTimeOfDayBadges()
        checkWeekendBadge()
        updateChallengeProgress(type: .readPosts)
        
        checkAndUnlockBadge(.firstRead)
        checkAndUnlockBadge(.reader5)
        checkAndUnlockBadge(.reader10)
        checkAndUnlockBadge(.reader25)
        checkAndUnlockBadge(.reader50)
        checkAndUnlockBadge(.reader100)
        checkAndUnlockBadge(.reader250)
        checkAndUnlockBadge(.reader500)
        checkAndUnlockBadge(.speedReader)
        checkAndUnlockBadge(.knowledgeSeeker)
        
        saveData()
    }
    
    func trackCommentPosted() {
        stats.commentsPosted += 1
        updateChallengeProgress(type: .commentOnPost)
        
        checkAndUnlockBadge(.firstComment)
        checkAndUnlockBadge(.commenter5)
        checkAndUnlockBadge(.commenter10)
        checkAndUnlockBadge(.commenter25)
        checkAndUnlockBadge(.commenter50)
        checkAndUnlockBadge(.socialButterfly)
        
        saveData()
    }
    
    func trackPostLiked() {
        stats.postsLiked += 1
        updateChallengeProgress(type: .likeContent)
        
        checkAndUnlockBadge(.firstLike)
        checkAndUnlockBadge(.curator10)
        checkAndUnlockBadge(.curator25)
        checkAndUnlockBadge(.curator50)
        checkAndUnlockBadge(.curator100)
        checkAndUnlockBadge(.socialButterfly)
        
        saveData()
    }
    
    func trackHighlightCreated(postId: String? = nil) {
        stats.highlightsCreated += 1
        if let postId {
            markPostEngagement(postId: postId, highlighted: true)
        }
        updateChallengeProgress(type: .createHighlights)
        
        checkAndUnlockBadge(.firstHighlight)
        checkAndUnlockBadge(.highlighter10)
        checkAndUnlockBadge(.highlighter25)
        checkAndUnlockBadge(.highlighter50)
        checkAndUnlockBadge(.knowledgeSeeker)
        
        saveData()
    }
    
    func trackNoteCreated(postId: String? = nil) {
        stats.notesCreated += 1
        if let postId {
            markPostEngagement(postId: postId, noted: true)
        }
        updateChallengeProgress(type: .createNotes)
        
        checkAndUnlockBadge(.firstNote)
        checkAndUnlockBadge(.writer5)
        checkAndUnlockBadge(.writer10)
        checkAndUnlockBadge(.writer25)
        checkAndUnlockBadge(.knowledgeSeeker)
        
        saveData()
    }
    
    func trackFolderCreated() {
        stats.foldersCreated += 1
        updateChallengeProgress(type: .saveToFolder)
        
        checkAndUnlockBadge(.firstFolder)
        checkAndUnlockBadge(.organizer5)
        checkAndUnlockBadge(.organizer10)
        checkAndUnlockBadge(.masterCurator)
        
        saveData()
    }
    
    private func checkTimeOfDayBadges() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour < 7 {
            stats.earlyBirdReads += 1
            checkAndUnlockBadge(.earlyBird)
            updateChallengeProgress(type: .earlyReader)
        } else if hour >= 23 {
            stats.nightOwlReads += 1
            checkAndUnlockBadge(.nightOwl)
            updateChallengeProgress(type: .nightReader)
        }
    }
    
    private func checkWeekendBadge() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        if weekday == 1 || weekday == 7 {
            stats.weekendReads += 1
            checkAndUnlockBadge(.weekendReader)
            checkAndUnlockBadge(.weekendWarrior)
            updateChallengeProgress(type: .readWeekend)
        }
    }

    // MARK: - Rest Games Tracking

    @MainActor
    func trackDevWordleWin(attempts: Int) {
        stats.devWordleWins += 1
        stats.devWordlePlays += 1

        if attempts == 1 {
            stats.devWordleFirstTryWins += 1
        }
        if attempts <= 2 {
            stats.devWordleTwoOrLessWins += 1
        }

        stats.devWordleStreak = DevWordleStorage.shared.currentStreak

        updateChallengeProgress(type: .winWordle)
        updateChallengeProgress(type: .playWordle)
        if attempts <= 3 {
            updateChallengeProgress(type: .wordlePrecision)
        }

        checkDevWordleBadges()
        GameCenterManager.shared.syncRestGameAchievements(from: stats)
        saveData()
    }

    @MainActor
    func trackDevWordlePlayed() {
        stats.devWordlePlays += 1
        stats.devWordleStreak = DevWordleStorage.shared.currentStreak

        updateChallengeProgress(type: .playWordle)
        saveData()
    }

    @MainActor
    func trackDevLeetSolved(difficulty: DevLeetDifficulty) {
        stats.devLeetSolves += 1
        stats.devLeetStreak = DevLeetStorage.shared.currentStreak

        if difficulty == .hard {
            stats.devLeetHardSolves += 1
        }

        updateChallengeProgress(type: .solveLeet)

        checkDevLeetBadges()
        GameCenterManager.shared.syncRestGameAchievements(from: stats)
        saveData()
    }

    private func checkDevWordleBadges() {
        checkAndUnlockBadge(.firstWordle)
        checkAndUnlockBadge(.wordleWins5)
        checkAndUnlockBadge(.wordleWins10)
        checkAndUnlockBadge(.wordleWins25)
        checkAndUnlockBadge(.wordleWins50)
        checkAndUnlockBadge(.wordleStreak7)
        checkAndUnlockBadge(.wordleStreak30)
        checkAndUnlockBadge(.wordleGenius)
        checkAndUnlockBadge(.wordleSharp)
    }

    private func checkDevLeetBadges() {
        checkAndUnlockBadge(.firstLeet)
        checkAndUnlockBadge(.leetSolves5)
        checkAndUnlockBadge(.leetSolves10)
        checkAndUnlockBadge(.leetSolves25)
        checkAndUnlockBadge(.leetStreak3)
        checkAndUnlockBadge(.leetStreak5)
        checkAndUnlockBadge(.leetStreak10)
        checkAndUnlockBadge(.leetHardMode)
    }

    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func incrementDailyReadCount() {
        let today = Self.todayKey
        if stats.todayReadDate != today {
            stats.todayReadDate = today
            stats.todayReadCount = 0
        }
        stats.todayReadCount += 1
    }

    private func markPostEngagement(postId: String, read: Bool = false, highlighted: Bool = false, noted: Bool = false) {
        var engagement = stats.postEngagement[postId] ?? PostEngagement()
        if read { engagement.read = true }
        if highlighted { engagement.highlighted = true }
        if noted { engagement.noted = true }
        stats.postEngagement[postId] = engagement
    }
    
    // MARK: - Progress Info
    
    var totalBadgesCount: Int {
        BadgeType.allCases.count
    }
    
    var badgeCompletionPercentage: Double {
        Double(unlockedBadges.count) / Double(totalBadgesCount)
    }
}

struct GamificationStats: Codable {
    var postsRead: Int = 0
    var commentsPosted: Int = 0
    var postsLiked: Int = 0
    var highlightsCreated: Int = 0
    var notesCreated: Int = 0
    var foldersCreated: Int = 0
    var weeklyStreak: Int = 0
    var earlyBirdReads: Int = 0
    var nightOwlReads: Int = 0
    var weekendReads: Int = 0
    var todayReadDate: String?
    var todayReadCount: Int = 0
    var perfectWeeks: Int = 0
    var postEngagement: [String: PostEngagement] = [:]
    var devWordleWins: Int = 0
    var devWordlePlays: Int = 0
    var devWordleFirstTryWins: Int = 0
    var devWordleTwoOrLessWins: Int = 0
    var devWordleStreak: Int = 0
    var devLeetSolves: Int = 0
    var devLeetHardSolves: Int = 0
    var devLeetStreak: Int = 0

    var knowledgeSeekerPosts: Int {
        postEngagement.values.filter { $0.read && $0.highlighted && $0.noted }.count
    }
}

struct PostEngagement: Codable, Equatable {
    var read: Bool = false
    var highlighted: Bool = false
    var noted: Bool = false
}
