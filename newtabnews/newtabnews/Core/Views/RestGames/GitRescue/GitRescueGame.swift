import SwiftUI

enum GitRescueTheme {
    // Laranja do logo do Git
    static let accent = Color(red: 0.94, green: 0.32, blue: 0.2)
    static let accentLight = Color(red: 1.0, green: 0.55, blue: 0.42)
}

extension ScenarioQuizConfig {
    static let gitRescue = ScenarioQuizConfig(
        storagePrefix: "gitRescue",
        title: "Git Rescue",
        icon: "arrow.triangle.branch",
        accent: GitRescueTheme.accent,
        accentLight: GitRescueTheme.accentLight,
        question: "Qual comando salva o dia?",
        dailyResource: "git_rescue_daily",
        freeResource: "git_rescue_free",
        optionsInSingleColumn: true,
        monospacedOptions: true,
        leaderboard: .gitRescue,
        onboardingID: .gitRescue,
        onboardingSteps: [
            "Um repositório está em apuros. Leia a situação e o terminal.",
            "Escolha o comando que resolve sem causar outro desastre.",
            "Diário: 1 resgate por dia. Livre: 10 rounds."
        ],
        introText: "Quase tudo no Git tem volta. O segredo é escolher o comando que resolve sem reescrever o que já foi compartilhado.",
        introRows: [
            ScenarioQuizIntroRow(term: "git reflog", detail: "Histórico de onde o HEAD esteve. Salva commits \"perdidos\""),
            ScenarioQuizIntroRow(term: "git revert", detail: "Desfaz um commit criando outro. Seguro em branch compartilhada"),
            ScenarioQuizIntroRow(term: "git reset", detail: "Move a branch para trás. --soft mantém tudo staged"),
            ScenarioQuizIntroRow(term: "git restore", detail: "Descarta mudanças locais ou tira do stage"),
            ScenarioQuizIntroRow(term: "git stash", detail: "Guarda mudanças para depois")
        ],
        introFootnote: "Regra de ouro: se já deu push, prefira revert. Se precisar forçar, use --force-with-lease.",
        learnMoreTitle: "Documentação do Git",
        learnMoreURL: URL(string: "https://git-scm.com/docs")!,
        perfectMessage: "Você é a pessoa que o time chama quando o main quebra.",
        goodMessage: "Nenhum force push acidental hoje. Orgulho.",
        okMessage: "Dá pra sobreviver. Deixe o git reflog anotado num post-it.",
        lowMessage: "rm -rf .git && git clone? Calma, bora revisar a doc."
    )
}

struct GitRescueView: View {
    var body: some View {
        ScenarioQuizView(config: .gitRescue)
    }
}

/// Preview do hub: um grafo de commits com uma branch que "volta" pro lugar
struct GitRescueHubPreview: View {
    @State private var rescued = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let midY = geo.size.height * 0.62
            let branchY = geo.size.height * 0.22
            let xs = (0..<4).map { width * (0.12 + CGFloat($0) * 0.25) }

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: xs[0], y: midY))
                    path.addLine(to: CGPoint(x: xs[3], y: midY))
                }
                .stroke(.white.opacity(0.25), lineWidth: 2)

                Path { path in
                    path.move(to: CGPoint(x: xs[1], y: midY))
                    path.addQuadCurve(to: CGPoint(x: xs[2], y: branchY), control: CGPoint(x: xs[1], y: branchY))
                }
                .trim(from: 0, to: rescued ? 1 : 0)
                .stroke(GitRescueTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == 3 && !rescued ? Color.red.opacity(0.8) : Color.white.opacity(0.85))
                        .frame(width: 10, height: 10)
                        .position(x: xs[index], y: midY)
                }

                Circle()
                    .fill(GitRescueTheme.accentLight)
                    .frame(width: 12, height: 12)
                    .scaleEffect(rescued ? 1 : 0.2)
                    .opacity(rescued ? 1 : 0)
                    .position(x: xs[2], y: branchY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeInOut(duration: 0.8)) { rescued = true }
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeInOut(duration: 0.5)) { rescued = false }
            }
        }
    }
}
