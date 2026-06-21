import Foundation
import SwiftUI

enum DevLeetDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var displayName: String {
        switch self {
        case .easy: return "Fácil"
        case .medium: return "Médio"
        case .hard: return "Difícil"
        }
    }
}

struct DevLeetExample: Codable, Equatable, Identifiable {
    let input: String
    let output: String
    let explanation: String?

    var id: String { input + output }
}

struct DevLeetSolutions: Codable, Equatable {
    var python: String?
    var java: String?
    var javascript: String?
    var cpp: String?

    var availableLanguages: [DevLeetSolutionLanguage] {
        DevLeetSolutionLanguage.allCases.filter { code(for: $0) != nil }
    }

    func code(for language: DevLeetSolutionLanguage) -> String? {
        switch language {
        case .python: python
        case .java: java
        case .javascript: javascript
        case .cpp: cpp
        }
    }
}

enum DevLeetSolutionLanguage: String, CaseIterable, Identifiable, Codable {
    case python
    case java
    case javascript
    case cpp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .python: "Python"
        case .java: "Java"
        case .javascript: "JavaScript"
        case .cpp: "C++"
        }
    }
}

struct DevLeetProblem: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let difficulty: DevLeetDifficulty
    let leetcodeNumber: Int
    let topics: [String]
    let description: String
    let examples: [DevLeetExample]
    let constraints: [String]
    let solutions: DevLeetSolutions?

    var hasSolutions: Bool {
        guard let solutions else { return false }
        return !solutions.availableLanguages.isEmpty
    }

    var leetcodeURL: URL? {
        URL(string: "https://leetcode.com/problems/\(id)/")
    }

    var displayDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        let meaningful = lines.filter { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return false }
            if value.range(of: #"^Example \d+:$"#, options: .regularExpression) != nil { return false }
            if value == "Constraints:" { return false }
            return true
        }

        guard !meaningful.isEmpty else { return nil }
        return meaningful.joined(separator: "\n")
    }
}

enum DevLeetSchedule {
    private static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func weekKey(for date: Date = .now) -> String {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    static var nextChallengeAt: Date {
        let startOfToday = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: .now)
        let daysUntilMonday = weekday == 2 ? 7 : (9 - weekday) % 7
        let daysToAdd = daysUntilMonday == 0 ? 7 : daysUntilMonday
        return calendar.date(byAdding: .day, value: daysToAdd, to: startOfToday) ?? .now
    }

    static func remainingInterval(from date: Date = .now) -> TimeInterval {
        max(0, nextChallengeAt.timeIntervalSince(date))
    }

    static func formattedRemaining(from date: Date = .now) -> String {
        let total = Int(remainingInterval(from: date))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    static func previousWeekKey(from weekKey: String) -> String? {
        guard let date = date(from: weekKey) else { return nil }
        guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: date) else { return nil }
        return Self.weekKey(for: previous)
    }

    private static func date(from weekKey: String) -> Date? {
        let parts = weekKey.split(separator: "-W")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else { return nil }

        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = year
        components.weekday = 2
        return calendar.date(from: components)
    }
}

struct DevLeetCatalog {
    let problems: [DevLeetProblem]

    static let shared: DevLeetCatalog = {
        if let loaded = loadFromBundle() {
            return loaded
        }
        return fallback
    }()

    func weeklyProblem(for date: Date = .now) -> DevLeetProblem {
        let key = DevLeetSchedule.weekKey(for: date)
        let index = abs(stableHash(key)) % problems.count
        return problems[index]
    }

    private static func loadFromBundle() -> DevLeetCatalog? {
        guard let url = Bundle.main.url(forResource: "dev_leet_problems", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawProblems = object["problems"] as? [[String: Any]] else {
            return nil
        }

        let decoder = JSONDecoder()
        var problems: [DevLeetProblem] = []
        var skipped = 0

        for rawProblem in rawProblems {
            guard JSONSerialization.isValidJSONObject(rawProblem),
                  let problemData = try? JSONSerialization.data(withJSONObject: rawProblem),
                  let problem = try? decoder.decode(DevLeetProblem.self, from: problemData) else {
                skipped += 1
                continue
            }
            problems.append(problem)
        }

        #if DEBUG
        if skipped > 0 {
            print("DevLeet catalog skipped \(skipped) invalid problems")
        }
        #endif

        guard !problems.isEmpty else { return nil }
        return DevLeetCatalog(problems: problems)
    }

    private static let fallback = DevLeetCatalog(problems: [
        DevLeetProblem(
            id: "two-sum",
            title: "Two Sum",
            difficulty: .easy,
            leetcodeNumber: 1,
            topics: ["Array", "Hash Table"],
            description: "Given an array of integers nums and an integer target, return indices of the two numbers such that they add up to target.",
            examples: [
                DevLeetExample(input: "nums = [2,7,11,15], target = 9", output: "[0,1]", explanation: "Because nums[0] + nums[1] == 9, we return [0, 1].")
            ],
            constraints: ["2 <= nums.length <= 10^4"],
            solutions: DevLeetSolutions(
                python: """
                def twoSum(nums, target):
                    seen = {}
                    for i, num in enumerate(nums):
                        complement = target - num
                        if complement in seen:
                            return [seen[complement], i]
                        seen[num] = i
                """,
                java: """
                public int[] twoSum(int[] nums, int target) {
                    Map<Integer, Integer> seen = new HashMap<>();
                    for (int i = 0; i < nums.length; i++) {
                        int complement = target - nums[i];
                        if (seen.containsKey(complement)) {
                            return new int[] { seen.get(complement), i };
                        }
                        seen.put(nums[i], i);
                    }
                    return new int[0];
                }
                """,
                javascript: """
                function twoSum(nums, target) {
                    const seen = new Map();
                    for (let i = 0; i < nums.length; i++) {
                        const complement = target - nums[i];
                        if (seen.has(complement)) return [seen.get(complement), i];
                        seen.set(nums[i], i);
                    }
                }
                """,
                cpp: """
                vector<int> twoSum(vector<int>& nums, int target) {
                    unordered_map<int, int> seen;
                    for (int i = 0; i < nums.size(); i++) {
                        int complement = target - nums[i];
                        if (seen.count(complement)) return { seen[complement], i };
                        seen[nums[i]] = i;
                    }
                    return {};
                }
                """
            )
        )
    ])

    private func stableHash(_ string: String) -> Int {
        string.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value))
        }
    }
}

struct DevLeetWeeklySummary {
    let solved: Bool
    let currentStreak: Int
    let problemTitle: String
    let difficulty: DevLeetDifficulty
}

enum DevLeetHubSummary {
    static func current(date: Date = .now) -> DevLeetWeeklySummary {
        let weekKey = DevLeetSchedule.weekKey(for: date)
        let problem = DevLeetCatalog.shared.weeklyProblem(for: date)
        return DevLeetStorage.shared.summary(for: weekKey, problem: problem)
    }
}

final class DevLeetStorage {
    static let shared = DevLeetStorage()

    private enum Keys {
        static let currentStreak = "devLeetCurrentStreak"
        static let maxStreak = "devLeetMaxStreak"
        static let lastSolvedWeek = "devLeetLastSolvedWeek"
    }

    private init() {}

    func isSolved(weekKey: String) -> Bool {
        UserDefaults.standard.bool(forKey: solvedKey(weekKey))
    }

    func markSolved(weekKey: String) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: solvedKey(weekKey))
        updateStreak(for: weekKey)
    }

    func summary(for weekKey: String, problem: DevLeetProblem) -> DevLeetWeeklySummary {
        DevLeetWeeklySummary(
            solved: isSolved(weekKey: weekKey),
            currentStreak: currentStreak,
            problemTitle: problem.title,
            difficulty: problem.difficulty
        )
    }

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: Keys.currentStreak)
    }

    private func updateStreak(for weekKey: String) {
        let defaults = UserDefaults.standard
        let lastSolved = defaults.string(forKey: Keys.lastSolvedWeek)
        var streak = defaults.integer(forKey: Keys.currentStreak)

        if lastSolved == weekKey {
            return
        }

        if let lastSolved, DevLeetSchedule.previousWeekKey(from: weekKey) == lastSolved {
            streak += 1
        } else if lastSolved == nil {
            streak = 1
        } else {
            streak = 1
        }

        defaults.set(streak, forKey: Keys.currentStreak)
        defaults.set(max(streak, defaults.integer(forKey: Keys.maxStreak)), forKey: Keys.maxStreak)
        defaults.set(weekKey, forKey: Keys.lastSolvedWeek)
    }

    private func solvedKey(_ weekKey: String) -> String {
        "devLeet_solved_\(weekKey)"
    }
}
