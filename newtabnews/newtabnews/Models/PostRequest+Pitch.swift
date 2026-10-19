//
//  PostRequest+Pitch.swift
//  newtabnews
//

import Foundation

enum PitchFilter {
    static let storageKey = "hidePitchPosts"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    /// Formatos usados pela comunidade para marcar divulgação de projeto:
    /// "Pitch: …", "PITCH - …", "[Pitch] …", "… (pitch)", "#pitch".
    /// "Pitch deck: como montar" não conta: depois de "pitch" precisa vir um separador.
    private static let patterns: [NSRegularExpression] = [
        #"^\W*pitch\s*[:：\-–—|/]"#,
        #"[\[\(\{【]\s*pitch\s*[\]\)\}】]"#,
        #"#pitch\b"#
    ].map { try! NSRegularExpression(pattern: $0) }

    static func isPitch(title: String?) -> Bool {
        guard let title else { return false }
        let normalized = title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(normalized.startIndex..., in: normalized)
        return patterns.contains { $0.firstMatch(in: normalized, range: range) != nil }
    }

    /// Remove os Pitches quando a opção está ligada no Perfil.
    static func apply(to posts: [PostRequest]) -> [PostRequest] {
        guard isEnabled else { return posts }
        return posts.filter { !isPitch(title: $0.title) }
    }
}
