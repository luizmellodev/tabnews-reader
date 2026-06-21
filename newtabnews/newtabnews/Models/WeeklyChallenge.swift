//
//  WeeklyChallenge.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/02/26.
//

import Foundation
import SwiftUI

enum ChallengeType: String, Codable, CaseIterable {
    case readPosts = "read_posts"
    case commentOnPost = "comment_on_post"
    case likeContent = "like_content"
    case createHighlights = "create_highlights"
    case saveToFolder = "save_to_folder"
    case readCategory = "read_category"
    case createNotes = "create_notes"
    case readWeekend = "read_weekend"
    case earlyReader = "early_reader"
    case nightReader = "night_reader"
    case shareKnowledge = "share_knowledge"
    case discoverNew = "discover_new"
    case deepDive = "deep_dive"
    case socialButterfly = "social_butterfly"
    case curator = "curator"
    case researcher = "researcher"

    // Rest games challenges
    case winWordle = "win_wordle"
    case playWordle = "play_wordle"
    case solveLeet = "solve_leet"
    case wordlePrecision = "wordle_precision"
    
    var title: String {
        switch self {
        case .readPosts: return "Leitor da Semana"
        case .commentOnPost: return "Participante Ativo"
        case .likeContent: return "Curador Engajado"
        case .createHighlights: return "Marcador de Ideias"
        case .saveToFolder: return "Organizador"
        case .readCategory: return "Explorador de Temas"
        case .createNotes: return "Escritor de Anotações"
        case .readWeekend: return "Leitor de Fim de Semana"
        case .earlyReader: return "Madrugador"
        case .nightReader: return "Coruja Noturna"
        case .shareKnowledge: return "Compartilhador"
        case .discoverNew: return "Descobridor"
        case .deepDive: return "Mergulho Profundo"
        case .socialButterfly: return "Social"
        case .curator: return "Curador Premium"
        case .researcher: return "Pesquisador"
        case .winWordle: return "DevWordle da Semana"
        case .playWordle: return "Jogador Diário"
        case .solveLeet: return "DevLeet da Semana"
        case .wordlePrecision: return "Palpite Preciso"
        }
    }
    
    func description(goal: Int) -> String {
        switch self {
        case .readPosts: return "Leia \(goal) posts"
        case .commentOnPost: return "Comente em \(goal) \(goal == 1 ? "post" : "posts")"
        case .likeContent: return "Curta \(goal) posts"
        case .createHighlights: return "Destaque \(goal) \(goal == 1 ? "trecho" : "trechos")"
        case .saveToFolder: return "Salve \(goal) posts em pastas"
        case .readCategory: return "Leia posts sobre temas variados"
        case .createNotes: return "Faça \(goal) \(goal == 1 ? "anotação" : "anotações")"
        case .readWeekend: return "Leia \(goal) posts no fim de semana"
        case .earlyReader: return "Leia \(goal) posts antes das 8h"
        case .nightReader: return "Leia \(goal) posts depois das 22h"
        case .shareKnowledge: return "Comente compartilhando conhecimento"
        case .discoverNew: return "Explore \(goal) posts novos"
        case .deepDive: return "Leia posts longos (>5 min)"
        case .socialButterfly: return "Interaja em \(goal) discussões"
        case .curator: return "Organize sua biblioteca"
        case .researcher: return "Destaque e anote em \(goal) posts"
        case .winWordle: return "Vença \(goal) \(goal == 1 ? "DevWordle" : "DevWordles")"
        case .playWordle: return "Jogue DevWordle \(goal) \(goal == 1 ? "vez" : "vezes")"
        case .solveLeet: return "Complete o desafio DevLeet da semana"
        case .wordlePrecision: return "Vença DevWordle em até 3 tentativas"
        }
    }
    
    var icon: String {
        switch self {
        case .readPosts: return "book.fill"
        case .commentOnPost: return "bubble.left.and.bubble.right.fill"
        case .likeContent: return "heart.fill"
        case .createHighlights: return "highlighter"
        case .saveToFolder: return "folder.badge.plus"
        case .readCategory: return "sparkles"
        case .createNotes: return "note.text.badge.plus"
        case .readWeekend: return "sun.max.fill"
        case .earlyReader: return "sunrise.fill"
        case .nightReader: return "moon.stars.fill"
        case .shareKnowledge: return "lightbulb.fill"
        case .discoverNew: return "safari.fill"
        case .deepDive: return "book.closed.fill"
        case .socialButterfly: return "person.3.fill"
        case .curator: return "star.fill"
        case .researcher: return "magnifyingglass"
        case .winWordle, .playWordle: return "character.textbox"
        case .solveLeet: return "chevron.left.forwardslash.chevron.right"
        case .wordlePrecision: return "scope"
        }
    }
    
    var color: Color {
        switch self {
        case .readPosts: return .blue
        case .commentOnPost: return .green
        case .likeContent: return .pink
        case .createHighlights: return .yellow
        case .saveToFolder: return .purple
        case .readCategory: return .orange
        case .createNotes: return .orange
        case .readWeekend: return .cyan
        case .earlyReader: return .orange
        case .nightReader: return .indigo
        case .shareKnowledge: return .yellow
        case .discoverNew: return .blue
        case .deepDive: return .purple
        case .socialButterfly: return .pink
        case .curator: return .yellow
        case .researcher: return .teal
        case .winWordle: return .green
        case .playWordle: return .mint
        case .solveLeet: return .blue
        case .wordlePrecision: return .orange
        }
    }
}

struct WeeklyChallenge: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ChallengeType
    let goal: Int
    var progress: Int
    let startDate: Date
    let endDate: Date
    
    var isCompleted: Bool {
        progress >= goal
    }
    
    var progressPercentage: Double {
        min(Double(progress) / Double(goal), 1.0)
    }
    
    init(type: ChallengeType, goal: Int, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.type = type
        self.goal = goal
        self.progress = 0
        self.startDate = startDate
        self.endDate = endDate
    }
}
