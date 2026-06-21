import SwiftUI

struct DevWordleBoardView: View {
    let rows: [DevWordleGuessRow]
    let currentRowIndex: Int
    let currentGuess: String
    let revealedRows: Set<Int>
    let shakeRow: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: DevWordleEngine.wordLength)

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<DevWordleEngine.maxAttempts, id: \.self) { rowIndex in
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<DevWordleEngine.wordLength, id: \.self) { column in
                        DevWordleTileView(
                            letter: letter(for: rowIndex, column: column),
                            result: tileResult(for: rowIndex, column: column),
                            isActiveRow: rowIndex == currentRowIndex,
                            revealDelay: Double(column) * 0.08
                        )
                    }
                }
                .modifier(ShakeEffect(animating: shakeRow && rowIndex == currentRowIndex))
            }
        }
    }

    private func letter(for row: Int, column: Int) -> Character? {
        if row == currentRowIndex {
            guard column < currentGuess.count else { return nil }
            return currentGuess[currentGuess.index(currentGuess.startIndex, offsetBy: column)]
        }
        return rows[row].letters[column]?.first
    }

    private func tileResult(for row: Int, column: Int) -> DevWordleLetterResult? {
        guard revealedRows.contains(row) else { return nil }
        return rows[row].results[column]
    }
}

private struct DevWordleTileView: View {
    let letter: Character?
    let result: DevWordleLetterResult?
    let isActiveRow: Bool
    let revealDelay: Double

    @State private var revealed = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 2)
                }

            if let letter {
                Text(String(letter))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(foregroundColor)
            }
        }
        .frame(height: 56)
        .scaleEffect(flipScale)
        .animation(flipAnimation, value: revealed)
        .animation(nil, value: letter)
        .onAppear { updateReveal() }
        .onChange(of: result) { _, _ in updateReveal() }
    }

    private var flipScale: CGFloat {
        guard result != nil else { return 1 }
        return revealed ? 1 : 0.85
    }

    private var flipAnimation: Animation? {
        result == nil ? nil : .spring(response: 0.34, dampingFraction: 0.72).delay(revealDelay)
    }

    private func updateReveal() {
        if result != nil {
            revealed = true
        }
    }

    private var backgroundColor: Color {
        guard revealed, let result else {
            return isActiveRow ? Color.white.opacity(0.06) : Color.white.opacity(0.04)
        }
        switch result {
        case .correct: return Color(red: 0.42, green: 0.67, blue: 0.36)
        case .present: return Color(red: 0.78, green: 0.68, blue: 0.30)
        case .absent: return Color.white.opacity(0.14)
        }
    }

    private var borderColor: Color {
        guard revealed, result != nil else {
            return letter == nil ? Color.white.opacity(0.18) : Color.white.opacity(0.35)
        }
        return backgroundColor
    }

    private var foregroundColor: Color {
        guard revealed, result != nil else { return .white }
        return .white
    }
}

private struct ShakeEffect: ViewModifier {
    var animating: Bool

    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: animating) { _, shouldShake in
                guard shouldShake else {
                    shakeOffset = 0
                    return
                }
                withAnimation(.linear(duration: 0.06).repeatCount(6, autoreverses: true)) {
                    shakeOffset = 6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    shakeOffset = 0
                }
            }
    }
}
