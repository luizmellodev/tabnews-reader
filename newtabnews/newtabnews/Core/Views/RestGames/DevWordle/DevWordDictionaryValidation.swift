import Foundation

enum DevWordDictionaryValidation {
    static let wordLength = 5
    static let minAnswers = 150
    static let minExtras = 150
    static let minPractice = 150

    static func blocklist() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "dev_word_blocklist", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(words)
    }

    static func validate(
        answers: [String],
        extras: [String],
        practice: [String]
    ) -> [String] {
        var errors: [String] = []
        let blocked = blocklist()

        func checkList(_ name: String, _ list: [String]) {
            var seen = Set<String>()
            for word in list {
                if word.count != wordLength || !word.allSatisfy(\.isLetter) {
                    errors.append("\(name): invalid word \"\(word)\"")
                }
                if blocked.contains(word) {
                    errors.append("\(name): blocklisted \"\(word)\"")
                }
                if seen.contains(word) {
                    errors.append("\(name): duplicate \"\(word)\"")
                }
                seen.insert(word)
            }
        }

        checkList("answers", answers)
        checkList("extraGuesses", extras)
        checkList("practiceAnswers", practice)

        let answerSet = Set(answers)
        let overlap = practice.filter { answerSet.contains($0) }
        if !overlap.isEmpty {
            errors.append("overlap answers/practice: \(overlap.joined(separator: ", "))")
        }

        let expectedPractice = extras.filter { !answerSet.contains($0) }.sorted()
        if practice.sorted() != expectedPractice {
            errors.append(
                "practiceAnswers must equal extraGuesses minus answers (expected \(expectedPractice.count), got \(practice.count))"
            )
        }

        if answers.count < minAnswers {
            errors.append("answers too small: \(answers.count) < \(minAnswers)")
        }
        if extras.count < minExtras {
            errors.append("extraGuesses too small: \(extras.count) < \(minExtras)")
        }
        if practice.count < minPractice {
            errors.append("practiceAnswers too small: \(practice.count) < \(minPractice)")
        }

        return errors
    }

    #if DEBUG
    static func assertValid(answers: [String], extras: [String], practice: [String]) {
        let errors = validate(answers: answers, extras: extras, practice: practice)
        if !errors.isEmpty {
            assertionFailure("DevWordDictionary validation failed:\n" + errors.joined(separator: "\n"))
        }
    }
    #endif
}
