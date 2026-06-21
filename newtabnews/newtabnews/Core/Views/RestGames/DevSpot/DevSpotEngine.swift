import Foundation

struct DevSpotRound: Equatable {
    let devTerm: String
    let decoy: String
    let devOnLeft: Bool

    var leftWord: String { devOnLeft ? devTerm : decoy }
    var rightWord: String { devOnLeft ? decoy : devTerm }

    func isDevTerm(_ word: String) -> Bool {
        word == devTerm
    }

    func side(for word: String) -> DevSpotSide? {
        if word == leftWord { return .left }
        if word == rightWord { return .right }
        return nil
    }
}

enum DevSpotSide: Equatable {
    case left
    case right
}

struct DevSpotPair: Decodable, Equatable {
    let dev: String
    let decoy: String
}

struct DevSpotDictionary {
    let pairs: [DevSpotPair]
    let decoys: [String]

    static let shared: DevSpotDictionary = {
        if let loaded = loadFromBundle() {
            return loaded
        }
        return fallback
    }()

    func makeRound(usedPairs: Set<String> = []) -> DevSpotRound? {
        guard !pairs.isEmpty else { return nil }

        for pair in pairs.shuffled() {
            let key = pairKey(pair.dev, pair.decoy)
            guard !usedPairs.contains(key) else { continue }

            return DevSpotRound(
                devTerm: pair.dev,
                decoy: pair.decoy,
                devOnLeft: Bool.random()
            )
        }

        if let pair = pairs.randomElement() {
            return DevSpotRound(
                devTerm: pair.dev,
                decoy: pair.decoy,
                devOnLeft: Bool.random()
            )
        }

        return nil
    }

    private func pairKey(_ dev: String, _ decoy: String) -> String {
        [dev, decoy].sorted().joined(separator: "|")
    }

    private static func loadFromBundle() -> DevSpotDictionary? {
        guard let url = Bundle.main.url(forResource: "dev_spot_words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.pairs.isEmpty else {
            return nil
        }
        return DevSpotDictionary(pairs: payload.pairs, decoys: payload.decoys)
    }

    private static let fallback = DevSpotDictionary(
        pairs: [
            DevSpotPair(dev: "ARC", decoy: "RPC"),
            DevSpotPair(dev: "ViewModifier", decoy: "ViewModel"),
            DevSpotPair(dev: "CQRS", decoy: "CORS"),
            DevSpotPair(dev: "MVCC", decoy: "MVC"),
            DevSpotPair(dev: "Retain Cycle", decoy: "Release Train"),
            DevSpotPair(dev: "Type Erasure", decoy: "Type Inference"),
            DevSpotPair(dev: "Circuit Breaker", decoy: "Circuit Board"),
            DevSpotPair(dev: "Garbage Collection", decoy: "Garbage Collector"),
            DevSpotPair(dev: "Race Condition", decoy: "Rate Limiting"),
            DevSpotPair(dev: "Dependency Injection", decoy: "Dependency Graph")
        ],
        decoys: []
    )

    private struct Payload: Decodable {
        let pairs: [DevSpotPair]
        let decoys: [String]
    }
}

enum DevSpotEngine {
    static let totalRounds = 10

    static func isCorrect(round: DevSpotRound, selectedSide: DevSpotSide) -> Bool {
        switch selectedSide {
        case .left: return round.devOnLeft
        case .right: return !round.devOnLeft
        }
    }
}
