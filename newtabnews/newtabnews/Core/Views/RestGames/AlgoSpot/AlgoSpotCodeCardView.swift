import SwiftUI

enum AlgoSpotTheme {
    static let accent = Color(red: 0.98, green: 0.62, blue: 0.22)
    static let accentLight = Color(red: 1.0, green: 0.78, blue: 0.45)
    static let keywordColor = Color(red: 1.0, green: 0.82, blue: 0.45)
    static let stringColor = Color(red: 0.45, green: 0.92, blue: 0.72)
}

struct AlgoSpotCodeCardView: View {
    let snippet: String

    @State private var appeared = false

    private var lines: [String] {
        AlgoSpotChallenge.stripFunctionDeclaration(from: snippet)
            .components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pseudocódigo")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.45))

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.25))
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(highlighted(line))
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AlgoSpotTheme.accent.opacity(0.6), AlgoSpotTheme.accentLight.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: AlgoSpotTheme.accent.opacity(0.15), radius: 16, y: 6)
        }
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(RestGameTheme.spring) {
                appeared = true
            }
        }
    }

    private static let keywordPattern: NSRegularExpression? = {
        let keywords = ["function", "return", "while", "down", "else", "for", "if", "not", "and", "or", "in", "to"]
        let joined = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return try? NSRegularExpression(pattern: "\\b(?:\(joined))\\b")
    }()

    private func highlighted(_ line: String) -> AttributedString {
        var result = AttributedString(line)
        result.foregroundColor = .white.opacity(0.88)

        guard let regex = Self.keywordPattern else { return result }

        let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
        for match in matches {
            guard let range = Range(match.range, in: line) else { continue }
            guard let attrStart = AttributedString.Index(range.lowerBound, within: result),
                  let attrEnd = AttributedString.Index(range.upperBound, within: result) else { continue }

            result[attrStart..<attrEnd].foregroundColor = AlgoSpotTheme.keywordColor
            result[attrStart..<attrEnd].font = .system(size: 14, weight: .semibold, design: .monospaced)
        }

        return result
    }
}
