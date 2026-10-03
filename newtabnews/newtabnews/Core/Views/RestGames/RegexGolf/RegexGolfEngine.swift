import Foundation

struct RegexGolfPuzzle: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let prompt: String
    let match: [String]
    let noMatch: [String]
    let solution: String
    let par: Int
    let difficulty: String?
    let hint: String?
    let explanation: String
}

/// Resultado de avaliar a regex digitada contra todas as palavras do puzzle
struct RegexGolfEvaluation: Equatable {
    /// Regex compila (padrão vazio conta como inválido para não "casar tudo")
    let isValid: Bool
    /// Range casado em cada palavra de `match` (nil = não casou)
    let matchRanges: [NSRange?]
    let noMatchRanges: [NSRange?]

    var matchedCount: Int { matchRanges.filter { $0 != nil }.count }
    var leakedCount: Int { noMatchRanges.filter { $0 != nil }.count }

    var isSolved: Bool {
        isValid && matchRanges.allSatisfy { $0 != nil } && noMatchRanges.allSatisfy { $0 == nil }
    }

    static func empty(for puzzle: RegexGolfPuzzle) -> RegexGolfEvaluation {
        RegexGolfEvaluation(
            isValid: false,
            matchRanges: Array(repeating: nil, count: puzzle.match.count),
            noMatchRanges: Array(repeating: nil, count: puzzle.noMatch.count)
        )
    }
}

enum RegexGolfEngine {
    static let freeTotalRounds = 5

    /// Busca (não full match), sem flags: mesmo critério usado para validar o conteúdo
    static func evaluate(_ pattern: String, puzzle: RegexGolfPuzzle) -> RegexGolfEvaluation {
        guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) else {
            return .empty(for: puzzle)
        }

        func firstRange(in text: String) -> NSRange? {
            let range = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.range
            return range.flatMap { $0.location == NSNotFound ? nil : $0 }
        }

        return RegexGolfEvaluation(
            isValid: true,
            matchRanges: puzzle.match.map(firstRange),
            noMatchRanges: puzzle.noMatch.map(firstRange)
        )
    }

    /// 100 pontos no par. Cada caractere a menos que o par vale +10; cada um a mais, -5 (mínimo 20).
    static func score(length: Int, par: Int) -> Int {
        if length <= par {
            return 100 + (par - length) * 10
        }
        return max(20, 100 - (length - par) * 5)
    }

    /// Teclado do iOS troca aspas e traços por versões "bonitas", que quebram a regex
    static func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2014}", with: "--")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2026}", with: "...")
    }
}

struct RegexGolfDictionary {
    let puzzles: [RegexGolfPuzzle]

    static let daily = load(resource: "regex_golf_daily")
    static let free = load(resource: "regex_golf_free")

    func dailyPuzzle(for date: Date = .now) -> RegexGolfPuzzle? {
        guard !puzzles.isEmpty else { return nil }
        return puzzles[abs(BigOSchedule.dayIndex(for: date)) % puzzles.count]
    }

    func randomPuzzle(excluding usedIDs: Set<String>) -> RegexGolfPuzzle? {
        let pool = puzzles.filter { !usedIDs.contains($0.id) }
        return pool.randomElement() ?? puzzles.randomElement()
    }

    private static func load(resource: String) -> RegexGolfDictionary {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return RegexGolfDictionary(puzzles: [])
        }
        return RegexGolfDictionary(puzzles: payload.puzzles)
    }

    private struct Payload: Decodable {
        let puzzles: [RegexGolfPuzzle]
    }
}

// MARK: - Storage

struct RegexGolfSavedState: Codable, Equatable {
    let puzzleID: String
    let pattern: String
    let solved: Bool
    let finished: Bool
}

@MainActor
enum RegexGolfStorage {
    // Mesmas chaves que ScenarioQuizStorage(prefix: "regexGolf") usa
    private static let currentStreakKey = "regexGolfCurrentStreak"

    static func loadState(for dateKey: String) -> RegexGolfSavedState? {
        guard let data = UserDefaults.standard.data(forKey: "regexGolf_state_\(dateKey)") else { return nil }
        return try? JSONDecoder().decode(RegexGolfSavedState.self, from: data)
    }

    static func saveState(_ state: RegexGolfSavedState, for dateKey: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: "regexGolf_state_\(dateKey)")
    }

    static func summary(for dateKey: String = ScenarioQuizEngine.dateKey()) -> ScenarioQuizDailySummary {
        let state = loadState(for: dateKey)
        return ScenarioQuizDailySummary(
            played: state?.finished == true,
            won: state?.solved == true,
            currentStreak: UserDefaults.standard.integer(forKey: currentStreakKey)
        )
    }

    /// Mesma regra de streak dos outros diários
    static func recordResult(solved: Bool, dateKey: String) {
        ScenarioQuizStorage(prefix: "regexGolf").recordResult(correct: solved, dateKey: dateKey)
    }
}
