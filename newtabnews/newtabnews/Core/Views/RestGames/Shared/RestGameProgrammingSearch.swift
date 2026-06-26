import Foundation

enum RestGameProgrammingSearch {
    static func programmingSearchURL(for term: String) -> URL? {
        let query = "O que é \(term) na programação"
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
