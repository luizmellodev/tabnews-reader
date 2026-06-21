//
//  GamificationView.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/02/26.
//

import SwiftUI

struct GamificationView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var selectedTab: GamificationTab = .challenges
    
    enum GamificationTab: String, CaseIterable {
        case challenges = "Desafios"
        case badges = "Badges"
        
        var icon: String {
            switch self {
            case .challenges: return "target"
            case .badges: return "star.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(GamificationTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == .challenges {
                            challengesContent
                        } else {
                            badgesContent
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Conquistas")
            .navigationBarTitleDisplayMode(.large)
            .background {
                ZStack {
                    Color("Background")
                        .ignoresSafeArea()
                    Image("ruido")
                        .resizable()
                        .scaledToFill()
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                }
            }
        }
    }
    
    // MARK: - Challenges Content
    
    private var challengesContent: some View {
        VStack(spacing: 20) {
            weeklyProgressCard
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Desafios desta Semana")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if gamificationManager.weeklyChallenges.isEmpty {
                    emptyStateView
                } else {
                    ForEach(gamificationManager.weeklyChallenges) { challenge in
                        WeeklyChallengeCard(challenge: challenge)
                    }
                }
            }
        }
    }
    
    private var weeklyProgressCard: some View {
        let completedCount = gamificationManager.weeklyChallenges.filter { $0.isCompleted }.count
        let totalCount = gamificationManager.weeklyChallenges.count
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progresso Semanal")
                        .font(.headline)
                    Text("Desafios concluídos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: completedCount)
                    
                    Text("\(completedCount)/\(totalCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            if completedCount == totalCount && totalCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Todos os desafios concluídos! 🎉")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Badges Content
    
    private var badgesContent: some View {
        VStack(spacing: 20) {
            badgeProgressCard
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Seus Badges")
                    .font(.title3)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(BadgeType.allCases, id: \.self) { badgeType in
                        BadgeCard(
                            badgeType: badgeType,
                            isUnlocked: gamificationManager.hasBadge(badgeType),
                            currentProgress: getCurrentProgress(for: badgeType)
                        )
                    }
                }
            }
        }
    }
    
    private var badgeProgressCard: some View {
        let percentage = gamificationManager.badgeCompletionPercentage
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coleção de Badges")
                        .font(.headline)
                    Text("\(gamificationManager.unlockedBadges.count) de \(gamificationManager.totalBadgesCount) desbloqueados")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: percentage)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: percentage)
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            ProgressView(value: percentage)
                .tint(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Novos desafios em breve!")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentProgress(for badgeType: BadgeType) -> Int {
        let stats = gamificationManager.stats
        
        switch badgeType {
        case .firstRead, .reader5, .reader10, .reader25, .reader50, .reader100, .reader250, .reader500:
            return stats.postsRead
        case .firstComment, .commenter5, .commenter10, .commenter25, .commenter50:
            return stats.commentsPosted
        case .firstLike, .curator10, .curator25, .curator50, .curator100:
            return stats.postsLiked
        case .firstHighlight, .highlighter10, .highlighter25, .highlighter50:
            return stats.highlightsCreated
        case .firstNote, .writer5, .writer10, .writer25:
            return stats.notesCreated
        case .firstFolder, .organizer5, .organizer10:
            return stats.foldersCreated
        case .weeklyStreak3, .weeklyStreak5, .weeklyStreak10, .weeklyStreak20:
            return stats.weeklyStreak
        case .earlyBird:
            return stats.earlyBirdReads
        case .nightOwl:
            return stats.nightOwlReads
        case .weekendReader, .weekendWarrior:
            return stats.weekendReads
        case .speedReader, .perfectWeek:
            return 0 // TODO: implementar tracking específico
        case .socialButterfly:
            return stats.postsLiked + stats.commentsPosted
        case .knowledgeSeeker:
            return 0 // TODO: implementar tracking específico
        case .masterCurator:
            return stats.foldersCreated
        case .firstWordle, .wordleWins5, .wordleWins10, .wordleWins25, .wordleWins50:
            return stats.devWordleWins
        case .wordleStreak7, .wordleStreak30:
            return stats.devWordleStreak
        case .wordleGenius:
            return stats.devWordleFirstTryWins
        case .wordleSharp:
            return stats.devWordleTwoOrLessWins
        case .firstLeet, .leetSolves5, .leetSolves10, .leetSolves25:
            return stats.devLeetSolves
        case .leetStreak3, .leetStreak5, .leetStreak10:
            return stats.devLeetStreak
        case .leetHardMode:
            return stats.devLeetHardSolves
        }
    }
}

// MARK: - Weekly Challenge Card

struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(challenge.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: challenge.type.icon)
                        .font(.title3)
                        .foregroundStyle(challenge.type.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.type.title)
                        .font(.headline)
                    Text(challenge.type.description(goal: challenge.goal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(challenge.progress)/\(challenge.goal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(challenge.progressPercentage * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(challenge.type.color)
                            .frame(
                                width: geometry.size.width * challenge.progressPercentage,
                                height: 8
                            )
                            .animation(.spring(), value: challenge.progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Badge Card

struct BadgeCard: View {
    let badgeType: BadgeType
    let isUnlocked: Bool
    let currentProgress: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badgeType.color.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)
                
                if isUnlocked {
                    Image(systemName: badgeType.icon)
                        .font(.title2)
                        .foregroundStyle(badgeType.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(badgeType.title)
                .font(.caption2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
            
            if !isUnlocked {
                Text("\(currentProgress)/\(badgeType.requirement)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6).opacity(isUnlocked ? 1 : 0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? badgeType.color.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Badge Unlocked Banner

struct BadgeUnlockedBanner: View {
    let badge: Badge
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        badge.type.color.opacity(0.2)
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: badge.type.icon)
                    .font(.title2)
                    .foregroundStyle(badge.type.color)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🎉")
                        .font(.caption)
                    Text("Badge Desbloqueado!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                Text(badge.type.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(badge.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: badge.type.color.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [badge.type.color.opacity(0.5), badge.type.color],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .padding(.horizontal)
        .offset(y: isAnimating ? 0 : -100)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
            
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    GamificationView()
}
