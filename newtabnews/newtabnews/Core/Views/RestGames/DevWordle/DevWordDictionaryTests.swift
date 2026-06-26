import Foundation

#if DEBUG
enum DevWordDictionaryTests {
    static func runAll(on dictionary: DevWordDictionary) {
        DevWordDictionaryValidation.assertValid(
            answers: dictionary.answers,
            extras: dictionary.extras,
            practice: dictionary.practiceAnswers
        )

        for word in dictionary.answers + dictionary.practiceAnswers + dictionary.extras {
            precondition(word.count == DevWordDictionaryValidation.wordLength)
            precondition(word.allSatisfy(\.isLetter))
        }

        let answerSet = Set(dictionary.answers)
        precondition(dictionary.practiceAnswers.allSatisfy { !answerSet.contains($0) })
        precondition(dictionary.answers.count >= DevWordDictionaryValidation.minAnswers)
        precondition(dictionary.practiceAnswers.count >= DevWordDictionaryValidation.minPractice)
    }
}
#endif
