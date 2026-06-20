//
//  Extensions.swift
//  newtabnews
//
//  Created by Luiz Mello on 27/07/23.
//

import Foundation
import SwiftUI

public func getFormattedDate(value: String) -> String {
    // Parse ISO8601 date
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: value) else {
        return "Data desconhecida"
    }
    
    let now = Date()
    let calendar = Calendar.current
    let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
    
    // Menos de 1 hora
    if let hours = components.hour, hours == 0,
       let minutes = components.minute, minutes < 60 {
        return "Há pouco"
    }
    
    // Menos de 24 horas
    if let days = components.day, days == 0,
       let hours = components.hour, hours > 0 {
        return hours == 1 ? "Há 1 hora" : "Há \(hours) horas"
    }
    
    // 1 dia ou mais
    if let days = components.day, days > 0 {
        return days == 1 ? "Há 1 dia" : "Há \(days) dias"
    }
    
    return "Há pouco"
}

extension String {
    var readingTimeInMinutes: Int {
        let wordsPerMinute = 200 // Velocidade média de leitura em português
        let words = self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        return max(1, wordCount / wordsPerMinute)
    }
    
    var readingTimeFormatted: String {
        let minutes = readingTimeInMinutes
        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) min"
        }
    }
    
    /// Remove markdown comum para previews de texto puro (feed, TTS, etc.)
    var plainTextFromMarkdown: String {
        var cleaned = self
        
        cleaned = cleaned.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^\)]+)\)"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^\)]+)\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"https?://[^\s<>]+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^---+\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"(?m)^-\s+"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"<!--[\s\S]*?-->"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"[ \t]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func feedPreview(maxLength: Int = 200) -> String {
        let flowingText = plainTextFromMarkdown
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        guard flowingText.count > maxLength else {
            return flowingText
        }
        
        return String(flowingText.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}



enum Theme: Int {
    case light
    case dark
    case system
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil  // nil = seguir o sistema
        }
    }
}

enum ContentStrategy: String, CaseIterable, Hashable {
    case relevant = "relevant"
    case new = "new"

    var displayName: String {
        switch self {
        case .relevant:
            return "Relevantes"
        case .new:
            return "Recentes"
        }
    }

    var icon: String {
        switch self {
        case .relevant:
            return "flame.fill"
        case .new:
            return "clock.fill"
        }
    }
}

extension Array where Element == PostRequest {
    func filtered(by query: String) -> [PostRequest] {
        guard !query.isEmpty else { return self }
        return filter { post in
            guard let title = post.title else { return false }
            return title.localizedCaseInsensitiveContains(query)
        }
    }
}
