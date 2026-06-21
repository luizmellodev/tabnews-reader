import SwiftUI

struct DevWordleKeyboardView: View {
    let keyboardStates: [Character: DevWordleLetterResult]
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    private let rows: [[Character]] = [
        Array("QWERTYUIOP"),
        Array("ASDFGHJKL"),
        Array("ZXCVBNM")
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    if row.first == "Z" {
                        keyboardButton(title: "⌫", width: 52, background: Color.white.opacity(0.14)) {
                            onDelete()
                        }
                    }

                    ForEach(row, id: \.self) { letter in
                        keyboardButton(title: String(letter), width: 34, background: keyColor(for: letter)) {
                            onLetter(letter)
                        }
                    }

                    if row.first == "Z" {
                        keyboardButton(title: "↵", width: 52, background: Color.white.opacity(0.14)) {
                            onSubmit()
                        }
                    }
                }
            }
        }
    }

    private func keyboardButton(title: String, width: CGFloat, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: title.count > 1 ? 18 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: width, height: 48)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }

    private func keyColor(for letter: Character) -> Color {
        guard let state = keyboardStates[letter] else {
            return Color.white.opacity(0.14)
        }
        switch state {
        case .correct: return Color(red: 0.42, green: 0.67, blue: 0.36)
        case .present: return Color(red: 0.78, green: 0.68, blue: 0.30)
        case .absent: return Color.white.opacity(0.14)
        }
    }
}
