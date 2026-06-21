//
//  Badge.swift
//  newtabnews
//
//  Created by Luiz Mello on 20/02/26.
//

import Foundation
import SwiftUI

enum BadgeType: String, Codable, CaseIterable {
    // Reading badges
    case firstRead = "first_read"
    case reader5 = "reader_5"
    case reader10 = "reader_10"
    case reader25 = "reader_25"
    case reader50 = "reader_50"
    case reader100 = "reader_100"
    case reader250 = "reader_250"
    case reader500 = "reader_500"
    
    // Engagement badges
    case firstComment = "first_comment"
    case commenter5 = "commenter_5"
    case commenter10 = "commenter_10"
    case commenter25 = "commenter_25"
    case commenter50 = "commenter_50"
    
    // Like badges
    case firstLike = "first_like"
    case curator10 = "curator_10"
    case curator25 = "curator_25"
    case curator50 = "curator_50"
    case curator100 = "curator_100"
    
    // Highlight badges
    case firstHighlight = "first_highlight"
    case highlighter10 = "highlighter_10"
    case highlighter25 = "highlighter_25"
    case highlighter50 = "highlighter_50"
    
    // Note badges
    case firstNote = "first_note"
    case writer5 = "writer_5"
    case writer10 = "writer_10"
    case writer25 = "writer_25"
    
    // Organization badges
    case firstFolder = "first_folder"
    case organizer5 = "organizer_5"
    case organizer10 = "organizer_10"
    
    // Streak badges
    case weeklyStreak3 = "weekly_streak_3"
    case weeklyStreak5 = "weekly_streak_5"
    case weeklyStreak10 = "weekly_streak_10"
    case weeklyStreak20 = "weekly_streak_20"
    
    // Time-based badges
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case weekendReader = "weekend_reader"
    case weekendWarrior = "weekend_warrior"
    
    // Special badges
    case speedReader = "speed_reader"
    case perfectWeek = "perfect_week"
    case socialButterfly = "social_butterfly"
    case knowledgeSeeker = "knowledge_seeker"
    case masterCurator = "master_curator"

    // DevWordle badges
    case firstWordle = "first_wordle"
    case wordleWins5 = "wordle_wins_5"
    case wordleWins10 = "wordle_wins_10"
    case wordleWins25 = "wordle_wins_25"
    case wordleWins50 = "wordle_wins_50"
    case wordleStreak7 = "wordle_streak_7"
    case wordleStreak30 = "wordle_streak_30"
    case wordleGenius = "wordle_genius"
    case wordleSharp = "wordle_sharp"

    // DevLeet badges
    case firstLeet = "first_leet"
    case leetSolves5 = "leet_solves_5"
    case leetSolves10 = "leet_solves_10"
    case leetSolves25 = "leet_solves_25"
    case leetStreak3 = "leet_streak_3"
    case leetStreak5 = "leet_streak_5"
    case leetStreak10 = "leet_streak_10"
    case leetHardMode = "leet_hard_mode"
    
    var title: String {
        switch self {
        case .firstRead: return "Primeira Leitura"
        case .reader5: return "Leitor Iniciante"
        case .reader10: return "Leitor Curioso"
        case .reader25: return "Leitor Dedicado"
        case .reader50: return "Leitor Ávido"
        case .reader100: return "Leitor Expert"
        case .reader250: return "Leitor Master"
        case .reader500: return "Leitor Lendário"
        case .firstComment: return "Primeira Voz"
        case .commenter5: return "Conversador"
        case .commenter10: return "Debatedor"
        case .commenter25: return "Comunicador"
        case .commenter50: return "Influenciador"
        case .firstLike: return "Primeira Curtida"
        case .curator10: return "Curador"
        case .curator25: return "Curador Expert"
        case .curator50: return "Curador Master"
        case .curator100: return "Curador Lendário"
        case .firstHighlight: return "Primeiro Destaque"
        case .highlighter10: return "Marcador"
        case .highlighter25: return "Destacador"
        case .highlighter50: return "Marcador Expert"
        case .firstNote: return "Primeira Anotação"
        case .writer5: return "Escritor"
        case .writer10: return "Anotador"
        case .writer25: return "Documentador"
        case .firstFolder: return "Organizador"
        case .organizer5: return "Arquivista"
        case .organizer10: return "Bibliotecário"
        case .weeklyStreak3: return "Consistente"
        case .weeklyStreak5: return "Dedicado"
        case .weeklyStreak10: return "Compromissado"
        case .weeklyStreak20: return "Lendário"
        case .earlyBird: return "Madrugador"
        case .nightOwl: return "Coruja Noturna"
        case .weekendReader: return "Leitor de Fim de Semana"
        case .weekendWarrior: return "Guerreiro do Fim de Semana"
        case .speedReader: return "Leitor Veloz"
        case .perfectWeek: return "Semana Perfeita"
        case .socialButterfly: return "Social"
        case .knowledgeSeeker: return "Buscador de Conhecimento"
        case .masterCurator: return "Curador Master"
        case .firstWordle: return "Primeiro DevWordle"
        case .wordleWins5: return "Palpiteiro"
        case .wordleWins10: return "Cracker de Código"
        case .wordleWins25: return "Lexicógrafo Dev"
        case .wordleWins50: return "Mestre das Letras"
        case .wordleStreak7: return "Sequência Semanal"
        case .wordleStreak30: return "Imparável"
        case .wordleGenius: return "Gênio"
        case .wordleSharp: return "Precisão"
        case .firstLeet: return "Primeiro Algoritmo"
        case .leetSolves5: return "Coder Iniciante"
        case .leetSolves10: return "Problem Solver"
        case .leetSolves25: return "Engenheiro Dev"
        case .leetStreak3: return "Leet Consistente"
        case .leetStreak5: return "Leet Dedicado"
        case .leetStreak10: return "Veterano Leet"
        case .leetHardMode: return "Modo Hard"
        }
    }
    
    var description: String {
        switch self {
        case .firstRead: return "Leu seu primeiro post"
        case .reader5: return "Leu 5 posts"
        case .reader10: return "Leu 10 posts"
        case .reader25: return "Leu 25 posts"
        case .reader50: return "Leu 50 posts"
        case .reader100: return "Leu 100 posts"
        case .reader250: return "Leu 250 posts"
        case .reader500: return "Leu 500 posts"
        case .firstComment: return "Fez seu primeiro comentário"
        case .commenter5: return "Fez 5 comentários"
        case .commenter10: return "Fez 10 comentários"
        case .commenter25: return "Fez 25 comentários"
        case .commenter50: return "Fez 50 comentários"
        case .firstLike: return "Curtiu seu primeiro post"
        case .curator10: return "Curtiu 10 posts"
        case .curator25: return "Curtiu 25 posts"
        case .curator50: return "Curtiu 50 posts"
        case .curator100: return "Curtiu 100 posts"
        case .firstHighlight: return "Fez seu primeiro destaque"
        case .highlighter10: return "Fez 10 destaques"
        case .highlighter25: return "Fez 25 destaques"
        case .highlighter50: return "Fez 50 destaques"
        case .firstNote: return "Fez sua primeira anotação"
        case .writer5: return "Fez 5 anotações"
        case .writer10: return "Fez 10 anotações"
        case .writer25: return "Fez 25 anotações"
        case .firstFolder: return "Criou sua primeira pasta"
        case .organizer5: return "Criou 5 pastas"
        case .organizer10: return "Criou 10 pastas"
        case .weeklyStreak3: return "Visitou por 3 semanas seguidas"
        case .weeklyStreak5: return "Visitou por 5 semanas seguidas"
        case .weeklyStreak10: return "Visitou por 10 semanas seguidas"
        case .weeklyStreak20: return "Visitou por 20 semanas seguidas"
        case .earlyBird: return "Leu um post antes das 7h"
        case .nightOwl: return "Leu um post depois das 23h"
        case .weekendReader: return "Leu posts em 5 fins de semana"
        case .weekendWarrior: return "Leu posts em 10 fins de semana"
        case .speedReader: return "Leu 10 posts em um dia"
        case .perfectWeek: return "Completou todos desafios da semana"
        case .socialButterfly: return "Curtiu e comentou 20 vezes"
        case .knowledgeSeeker: return "Leu, destacou e anotou em 10 posts"
        case .masterCurator: return "Organizou 50 posts em pastas"
        case .firstWordle: return "Venceu seu primeiro DevWordle"
        case .wordleWins5: return "Venceu 5 DevWordles"
        case .wordleWins10: return "Venceu 10 DevWordles"
        case .wordleWins25: return "Venceu 25 DevWordles"
        case .wordleWins50: return "Venceu 50 DevWordles"
        case .wordleStreak7: return "Sequência de 7 dias no DevWordle"
        case .wordleStreak30: return "Sequência de 30 dias no DevWordle"
        case .wordleGenius: return "Acertou a palavra na 1ª tentativa"
        case .wordleSharp: return "Venceu em até 2 tentativas, 5 vezes"
        case .firstLeet: return "Completou seu primeiro DevLeet"
        case .leetSolves5: return "Completou 5 desafios DevLeet"
        case .leetSolves10: return "Completou 10 desafios DevLeet"
        case .leetSolves25: return "Completou 25 desafios DevLeet"
        case .leetStreak3: return "Sequência de 3 semanas no DevLeet"
        case .leetStreak5: return "Sequência de 5 semanas no DevLeet"
        case .leetStreak10: return "Sequência de 10 semanas no DevLeet"
        case .leetHardMode: return "Completou um DevLeet de dificuldade Hard"
        }
    }
    
    var icon: String {
        switch self {
        case .firstRead: return "book.fill"
        case .reader5, .reader10: return "books.vertical.fill"
        case .reader25, .reader50: return "text.book.closed.fill"
        case .reader100, .reader250: return "graduationcap.fill"
        case .reader500: return "crown.fill"
        case .firstComment, .commenter5: return "bubble.left.and.bubble.right.fill"
        case .commenter10, .commenter25: return "person.wave.2.fill"
        case .commenter50: return "megaphone.fill"
        case .firstLike, .curator10: return "heart.fill"
        case .curator25, .curator50: return "star.fill"
        case .curator100: return "crown.fill"
        case .firstHighlight, .highlighter10: return "highlighter"
        case .highlighter25, .highlighter50: return "paintbrush.fill"
        case .firstNote, .writer5: return "note.text"
        case .writer10, .writer25: return "pencil.and.list.clipboard"
        case .firstFolder, .organizer5: return "folder.fill"
        case .organizer10: return "archivebox.fill"
        case .weeklyStreak3, .weeklyStreak5: return "flame.fill"
        case .weeklyStreak10: return "sparkles"
        case .weeklyStreak20: return "trophy.fill"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .weekendReader: return "beach.umbrella.fill"
        case .weekendWarrior: return "figure.surfing"
        case .speedReader: return "bolt.fill"
        case .perfectWeek: return "checkmark.seal.fill"
        case .socialButterfly: return "person.3.fill"
        case .knowledgeSeeker: return "brain.head.profile"
        case .masterCurator: return "star.leadinghalf.filled"
        case .firstWordle, .wordleWins5: return "character.textbox"
        case .wordleWins10, .wordleWins25: return "textformat.abc"
        case .wordleWins50: return "crown.fill"
        case .wordleStreak7: return "flame.fill"
        case .wordleStreak30: return "bolt.fill"
        case .wordleGenius: return "lightbulb.fill"
        case .wordleSharp: return "scope"
        case .firstLeet, .leetSolves5: return "chevron.left.forwardslash.chevron.right"
        case .leetSolves10, .leetSolves25: return "function"
        case .leetStreak3, .leetStreak5: return "calendar.badge.clock"
        case .leetStreak10: return "trophy.fill"
        case .leetHardMode: return "flame.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstRead, .reader5: return .blue
        case .reader10, .reader25: return .purple
        case .reader50, .reader100: return .orange
        case .reader250: return .red
        case .reader500: return .yellow
        case .firstComment, .commenter5: return .green
        case .commenter10, .commenter25: return .teal
        case .commenter50: return .mint
        case .firstLike, .curator10: return .pink
        case .curator25, .curator50: return .red
        case .curator100: return .yellow
        case .firstHighlight, .highlighter10: return .yellow
        case .highlighter25, .highlighter50: return .orange
        case .firstNote, .writer5: return .orange
        case .writer10, .writer25: return .brown
        case .firstFolder, .organizer5: return .indigo
        case .organizer10: return .purple
        case .weeklyStreak3: return .red
        case .weeklyStreak5: return .orange
        case .weeklyStreak10: return .pink
        case .weeklyStreak20: return .yellow
        case .earlyBird: return .orange
        case .nightOwl: return .indigo
        case .weekendReader: return .cyan
        case .weekendWarrior: return .blue
        case .speedReader: return .yellow
        case .perfectWeek: return .green
        case .socialButterfly: return .pink
        case .knowledgeSeeker: return .purple
        case .masterCurator: return .yellow
        case .firstWordle, .wordleWins5: return .green
        case .wordleWins10, .wordleWins25: return .teal
        case .wordleWins50: return .yellow
        case .wordleStreak7: return .orange
        case .wordleStreak30: return .red
        case .wordleGenius: return .yellow
        case .wordleSharp: return .mint
        case .firstLeet, .leetSolves5: return .blue
        case .leetSolves10, .leetSolves25: return .indigo
        case .leetStreak3: return .orange
        case .leetStreak5: return .red
        case .leetStreak10: return .yellow
        case .leetHardMode: return .red
        }
    }
    
    var requirement: Int {
        switch self {
        case .firstRead: return 1
        case .reader5: return 5
        case .reader10: return 10
        case .reader25: return 25
        case .reader50: return 50
        case .reader100: return 100
        case .reader250: return 250
        case .reader500: return 500
        case .firstComment: return 1
        case .commenter5: return 5
        case .commenter10: return 10
        case .commenter25: return 25
        case .commenter50: return 50
        case .firstLike: return 1
        case .curator10: return 10
        case .curator25: return 25
        case .curator50: return 50
        case .curator100: return 100
        case .firstHighlight: return 1
        case .highlighter10: return 10
        case .highlighter25: return 25
        case .highlighter50: return 50
        case .firstNote: return 1
        case .writer5: return 5
        case .writer10: return 10
        case .writer25: return 25
        case .firstFolder: return 1
        case .organizer5: return 5
        case .organizer10: return 10
        case .weeklyStreak3: return 3
        case .weeklyStreak5: return 5
        case .weeklyStreak10: return 10
        case .weeklyStreak20: return 20
        case .earlyBird, .nightOwl: return 1
        case .weekendReader: return 5
        case .weekendWarrior: return 10
        case .speedReader: return 10
        case .perfectWeek: return 1
        case .socialButterfly: return 20
        case .knowledgeSeeker: return 10
        case .masterCurator: return 50
        case .firstWordle, .firstLeet, .wordleGenius, .leetHardMode: return 1
        case .wordleWins5, .leetSolves5: return 5
        case .wordleWins10, .leetSolves10: return 10
        case .wordleWins25, .leetSolves25: return 25
        case .wordleWins50: return 50
        case .wordleStreak7: return 7
        case .wordleStreak30: return 30
        case .wordleSharp: return 5
        case .leetStreak3: return 3
        case .leetStreak5: return 5
        case .leetStreak10: return 10
        }
    }
}

struct Badge: Identifiable, Codable, Equatable {
    let id: UUID
    let type: BadgeType
    let unlockedAt: Date
    
    init(type: BadgeType, unlockedAt: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.unlockedAt = unlockedAt
    }
}
