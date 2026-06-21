//
//  SearchQueryParser.swift
//  newtabnews
//

import Foundation

enum SearchQuery: Equatable {
    case author(String)
    case post(user: String, slug: String)
    case local(String)
}

enum SearchQueryParser {
    private static let usernamePattern = #"^[a-z0-9_-]+$"#
    private static let slugPattern = #"^[a-z0-9_-]+$"#
    private static let userSlugPattern = #"^([a-z0-9_-]+)/([a-z0-9_-]+)$"#

    static func parse(_ rawInput: String) -> SearchQuery? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("@") {
            let username = String(trimmed.dropFirst())
            if isValidUsername(username) {
                return .author(username)
            }
        }

        if let postReference = parsePostReference(from: trimmed) {
            return postReference
        }

        return .local(trimmed)
    }

    private static func parsePostReference(from input: String) -> SearchQuery? {
        if let url = URL(string: input), let post = parseTabNewsURL(url) {
            return post
        }

        if input.contains("tabnews.com.br") {
            let normalized = input
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")

            if let slashIndex = normalized.firstIndex(of: "/") {
                let path = String(normalized[slashIndex...])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let post = parseUserSlugPath(path) {
                    return post
                }
            }
        }

        return parseUserSlugPath(input)
    }

    private static func parseTabNewsURL(_ url: URL) -> SearchQuery? {
        guard url.host?.contains("tabnews.com.br") == true else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2 else { return nil }

        let user = components[0].lowercased()
        let slug = components[1].lowercased()

        guard isValidUsername(user), isValidSlug(slug) else { return nil }
        return .post(user: user, slug: slug)
    }

    private static func parseUserSlugPath(_ path: String) -> SearchQuery? {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let regex = try? NSRegularExpression(pattern: userSlugPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              match.numberOfRanges == 3,
              let userRange = Range(match.range(at: 1), in: normalized),
              let slugRange = Range(match.range(at: 2), in: normalized) else {
            return nil
        }

        let user = String(normalized[userRange]).lowercased()
        let slug = String(normalized[slugRange]).lowercased()

        guard isValidUsername(user), isValidSlug(slug) else { return nil }
        return .post(user: user, slug: slug)
    }

    private static func isValidUsername(_ value: String) -> Bool {
        matches(value.lowercased(), pattern: usernamePattern)
    }

    private static func isValidSlug(_ value: String) -> Bool {
        matches(value.lowercased(), pattern: slugPattern)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }
}
