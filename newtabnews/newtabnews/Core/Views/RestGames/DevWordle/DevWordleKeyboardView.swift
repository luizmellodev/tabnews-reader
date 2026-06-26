import SwiftUI

struct DevWordleKeyboardView: View {
    let keyboardStates: [Character: DevWordleLetterResult]
    var isEnabled = true
    let onLetter: (Character) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void

    private let keyHeight: CGFloat = 48
    private let letterKeyWidth: CGFloat = 34
    private let keySpacing: CGFloat = 6
    private let deleteKeyWidth: CGFloat = 54
    private let enterKeyWidth: CGFloat = 96

    private let rows: [[Character]] = [
        Array("QWERTYUIOP"),
        Array("ASDFGHJKL"),
        Array("ZXCVBNM")
    ]

    private var topRowWidth: CGFloat {
        rowWidth(for: rows[0].count)
    }

    private var secondRowLeading: CGFloat {
        (topRowWidth - rowWidth(for: rows[1].count)) / 2
    }

    /// Z fica na coluna do S — um passo à direita do A.
    private var thirdRowLeading: CGFloat {
        secondRowLeading + letterKeyWidth + keySpacing
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 {
                    HStack(spacing: keySpacing) {
                        ForEach(row, id: \.self) { letter in
                            letterButton(for: letter)
                        }
                    }
                } else if index == 1 {
                    HStack(spacing: keySpacing) {
                        Spacer(minLength: secondRowLeading)
                        ForEach(row, id: \.self) { letter in
                            letterButton(for: letter)
                        }
                        Spacer(minLength: secondRowLeading)
                    }
                } else {
                    HStack(spacing: keySpacing) {
                        Spacer(minLength: thirdRowLeading)

                        ForEach(row, id: \.self) { letter in
                            letterButton(for: letter)
                        }

                        actionButton(width: deleteKeyWidth, action: onDelete) {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            HStack(spacing: keySpacing) {
                Spacer(minLength: 0)

                actionButton(width: enterKeyWidth, action: onSubmit) {
                    Text("↵")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.35)
        .allowsHitTesting(isEnabled)
    }

    private func rowWidth(for keyCount: Int) -> CGFloat {
        CGFloat(keyCount) * letterKeyWidth + CGFloat(keyCount - 1) * keySpacing
    }

    private func letterButton(for letter: Character) -> some View {
        let isAbsent = keyboardStates[letter] == .absent

        return Button {
            onLetter(letter)
        } label: {
            Text(String(letter))
                .font(.system(size: 15, weight: isAbsent ? .medium : .semibold, design: .rounded))
                .foregroundStyle(keyForeground(for: letter))
                .frame(width: letterKeyWidth, height: keyHeight)
                .background(keyColor(for: letter), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if isAbsent {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    }
                }
                .opacity(isAbsent ? 0.72 : 1)
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }

    private func actionButton<Label: View>(
        width: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .frame(width: width, height: keyHeight)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        case .absent: return Color(red: 0.16, green: 0.16, blue: 0.18)
        }
    }

    private func keyForeground(for letter: Character) -> Color {
        keyboardStates[letter] == .absent ? .white.opacity(0.22) : .white
    }
}
