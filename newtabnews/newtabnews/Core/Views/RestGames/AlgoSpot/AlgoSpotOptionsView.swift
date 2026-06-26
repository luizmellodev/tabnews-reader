import SwiftUI

private enum AlgoSpotOptionVisualState {
    case neutral
    case selected
    case correct
    case wrong
    case dimmed
}

struct AlgoSpotOptionsView: View {
    let options: [String]
    let phase: AlgoSpotPhase
    let selectedAnswer: String?
    let correctAnswer: String
    let wasCorrect: Bool
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(options, id: \.self) { option in
                AlgoSpotOptionButton(
                    label: option,
                    state: visualState(for: option),
                    onTap: { onSelect(option) }
                )
            }
        }
    }

    private func visualState(for option: String) -> AlgoSpotOptionVisualState {
        guard phase == .revealing else {
            return selectedAnswer == option ? .selected : .neutral
        }
        if option == correctAnswer { return .correct }
        if selectedAnswer == option && !wasCorrect { return .wrong }
        return .dimmed
    }
}

private struct AlgoSpotOptionButton: View {
    let label: String
    let state: AlgoSpotOptionVisualState
    let onTap: () -> Void

    @State private var shake = false

    var body: some View {
        Button {
            guard state == .neutral || state == .selected else { return }
            RestFeedbackManager.shared.tap()
            onTap()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 64)
                .padding(.horizontal, 8)
                .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: state == .neutral ? 1 : 2)
                }
                .shadow(color: shadowColor, radius: state == .correct ? 20 : 6, y: 3)
                .offset(x: shake ? -6 : 0)
        }
        .buttonStyle(RestGameScaleButtonStyle())
        .disabled(state != .neutral && state != .selected)
        .animation(RestGameTheme.quickSpring, value: state)
        .onChange(of: state) { _, newState in
            guard newState == .wrong else { return }
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) {
                shake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shake = false
            }
        }
    }

    private var background: some ShapeStyle {
        switch state {
        case .neutral: return AnyShapeStyle(.white.opacity(0.08))
        case .selected: return AnyShapeStyle(AlgoSpotTheme.accent.opacity(0.22))
        case .correct: return AnyShapeStyle(Color.green.opacity(0.35))
        case .wrong: return AnyShapeStyle(Color.red.opacity(0.3))
        case .dimmed: return AnyShapeStyle(.white.opacity(0.04))
        }
    }

    private var borderColor: Color {
        switch state {
        case .neutral: return .white.opacity(0.12)
        case .selected: return AlgoSpotTheme.accent.opacity(0.7)
        case .correct: return .green.opacity(0.8)
        case .wrong: return .red.opacity(0.7)
        case .dimmed: return .white.opacity(0.06)
        }
    }

    private var shadowColor: Color {
        switch state {
        case .correct: return .green.opacity(0.4)
        case .wrong: return .red.opacity(0.3)
        case .selected: return AlgoSpotTheme.accent.opacity(0.25)
        default: return .clear
        }
    }
}
