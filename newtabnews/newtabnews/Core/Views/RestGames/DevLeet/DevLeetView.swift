import SwiftUI

struct DevLeetView: View {
    @State private var weekKey = DevLeetSchedule.weekKey()
    @State private var isSolved = DevLeetStorage.shared.isSolved(weekKey: DevLeetSchedule.weekKey())
    @State private var showHonorSheet = false
    @State private var showSolutionSheet = false
    @State private var showOnboarding = !RestGameOnboarding.hasSeen(.devLeet)

    private let problem = DevLeetCatalog.shared.weeklyProblem()

    var body: some View {
        ZStack {
            RestGameBackground(animated: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    paperCallout
                    problemCard
                    examplesSection
                    constraintsSection

                    if problem.hasSolutions {
                        solutionButton
                    }

                    if isSolved {
                        solvedBanner
                    } else {
                        markSolvedButton
                    }

                    if isSolved {
                        DevLeetCountdownLabel()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }

            if showOnboarding {
                RestGameOnboardingOverlay.devLeet {
                    RestGameOnboarding.markSeen(.devLeet)
                    showOnboarding = false
                }
            }
        }
        .onAppear {
            RestFeedbackManager.shared.prepare()
            refreshState()
        }
        .sheet(isPresented: $showHonorSheet) {
            DevLeetHonorSheet(
                onConfirm: {
                    DevLeetStorage.shared.markSolved(weekKey: weekKey)
                    RestFeedbackManager.shared.confirm()
                    isSolved = true
                    showHonorSheet = false
                },
                onCancel: {
                    showHonorSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSolutionSheet) {
            if let solutions = problem.solutions {
                DevLeetSolutionSheet(problemTitle: problem.title, solutions: solutions)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DevLeet")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Desafio semanal · papel e caneta")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 10) {
                difficultyBadge
                Text("#\(problem.leetcodeNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.top, 12)
    }

    private var difficultyBadge: some View {
        Text(problem.difficulty.displayName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(problem.difficulty.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(problem.difficulty.color.opacity(0.15), in: Capsule())
    }

    private var paperCallout: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "pencil.and.outline")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pegue papel e caneta")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Escreva a solução à mão, é assim que funciona no Google, Meta e Amazon. Sem IDE. Sem autocomplete. Só você e o problema.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.orange.opacity(0.25), lineWidth: 1)
        }
    }

    private var problemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(problem.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if let description = problem.displayDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !problem.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(problem.topics, id: \.self) { topic in
                            Text(topic)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }

            if let url = problem.leetcodeURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Ver no LeetCode")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Exemplos")

            ForEach(Array(problem.examples.enumerated()), id: \.element.id) { index, example in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exemplo \(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))

                    exampleBlock("Entrada", example.input)
                    exampleBlock("Saída", example.output)

                    if let explanation = example.explanation {
                        exampleBlock("Explicação", explanation)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Restrições")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(problem.constraints, id: \.self) { constraint in
                    Text("• \(constraint)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var solutionButton: some View {
        Button {
            RestFeedbackManager.shared.tap()
            showSolutionSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ver solução de referência")
                        .font(.subheadline.weight(.semibold))
                    Text("Python · Java · JavaScript · C++")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.cyan.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }

    private var markSolvedButton: some View {
        Button {
            RestFeedbackManager.shared.tap()
            showHonorSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Marcar como resolvido")
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(.white, in: Capsule())
            .shadow(color: .white.opacity(0.15), radius: 16, y: 8)
        }
        .buttonStyle(RestGameScaleButtonStyle())
    }

    private var solvedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Marcado como resolvido")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Até semana que vem com um desafio novo.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()
        }
        .padding(16)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.green.opacity(0.25), lineWidth: 1)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.45))
    }

    private func exampleBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshState() {
        weekKey = DevLeetSchedule.weekKey()
        isSolved = DevLeetStorage.shared.isSolved(weekKey: weekKey)
    }
}

private struct DevLeetHonorSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .frame(width: 72, height: 72)
                .background(.orange.opacity(0.12), in: Circle())

            VStack(spacing: 10) {
                Text("Seja honesto consigo")
                    .font(.title3.weight(.bold))

                Text("Você só está se enganando se marcar como resolvido sem ter feito de verdade.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Pegou papel, escreveu o código e rastreou a solução?")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text("Sim, resolvi")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: Capsule())
                }

                Button(action: onCancel) {
                    Text("Ainda não — voltar ao problema")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
    }
}

private struct DevLeetSolutionSheet: View {
    let problemTitle: String
    let solutions: DevLeetSolutions

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: DevLeetSolutionLanguage

    init(problemTitle: String, solutions: DevLeetSolutions) {
        self.problemTitle = problemTitle
        self.solutions = solutions
        _selectedLanguage = State(initialValue: solutions.availableLanguages.first ?? .python)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Compare com o que você escreveu no papel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                Picker("Linguagem", selection: $selectedLanguage) {
                    ForEach(solutions.availableLanguages) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: true) {
                    Text(solutions.code(for: selectedLanguage) ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
            .navigationTitle(problemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct DevLeetCountdownLabel: View {
    var prefix: String = "Próximo desafio em"
    var onDarkBackground = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("\(prefix) \(DevLeetSchedule.formattedRemaining(from: context.date))")
                .font(onDarkBackground ? .caption2.weight(.semibold) : .subheadline)
                .monospacedDigit()
                .foregroundStyle(onDarkBackground ? .white.opacity(0.5) : .secondary)
        }
    }
}
