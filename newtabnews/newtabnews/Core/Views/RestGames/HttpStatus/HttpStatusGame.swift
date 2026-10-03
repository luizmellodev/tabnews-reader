import SwiftUI

enum HttpStatusTheme {
    static let accent = Color(red: 0.16, green: 0.72, blue: 0.62)
    static let accentLight = Color(red: 0.42, green: 0.9, blue: 0.8)
}

extension ScenarioQuizConfig {
    static let httpStatus = ScenarioQuizConfig(
        storagePrefix: "httpStatus",
        title: "HTTP Status",
        icon: "network",
        accent: HttpStatusTheme.accent,
        accentLight: HttpStatusTheme.accentLight,
        question: "Qual status code o servidor deve responder?",
        dailyResource: "http_status_daily",
        freeResource: "http_status_free",
        optionsInSingleColumn: false,
        monospacedOptions: false,
        leaderboard: .httpStatus,
        onboardingID: .httpStatus,
        onboardingSteps: [
            "Leia a situação: o que chegou na API e o que o servidor sabe.",
            "Escolha o status code correto entre 4 opções.",
            "Diário: 1 desafio por dia. Livre: 10 rounds."
        ],
        introText: "O primeiro dígito do status code já diz muito sobre a resposta.",
        introRows: [
            ScenarioQuizIntroRow(term: "1xx", detail: "Informativo: a requisição chegou, continue"),
            ScenarioQuizIntroRow(term: "2xx", detail: "Sucesso: deu certo"),
            ScenarioQuizIntroRow(term: "3xx", detail: "Redirecionamento: procure em outro lugar"),
            ScenarioQuizIntroRow(term: "4xx", detail: "Erro do cliente: o problema está na requisição"),
            ScenarioQuizIntroRow(term: "5xx", detail: "Erro do servidor: a requisição era válida, o servidor falhou")
        ],
        introFootnote: "Pegadinha clássica: 401 é \"não sei quem você é\", 403 é \"sei quem você é, mas não pode\".",
        learnMoreTitle: "Status codes na MDN",
        learnMoreURL: URL(string: "https://developer.mozilla.org/pt-BR/docs/Web/HTTP/Reference/Status")!,
        perfectMessage: "200 OK. Você é a RFC 9110 em pessoa.",
        goodMessage: "Sua API seria um prazer de consumir.",
        okMessage: "Razoável. Cuidado pra não responder 200 com erro no corpo.",
        lowMessage: "500 Internal Server Error. Bora revisar a MDN?"
    )
}

struct HttpStatusView: View {
    var body: some View {
        ScenarioQuizView(config: .httpStatus)
    }
}

/// Preview do hub: códigos passando como num log de requisições
struct HttpStatusHubPreview: View {
    private let entries: [(method: String, code: String, color: Color)] = [
        ("GET", "200", .green),
        ("POST", "201", .green),
        ("PUT", "409", .orange),
        ("GET", "304", .cyan),
        ("DELETE", "403", .orange),
        ("GET", "503", .red)
    ]

    @State private var offset = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                let entry = entries[(offset + row) % entries.count]
                HStack(spacing: 6) {
                    Text(entry.method)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 40, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(entry.code)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(entry.color.opacity(row == 0 ? 1 : 0.55))
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.white.opacity(row == 0 ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeInOut(duration: 0.5)) {
                    offset = (offset + 1) % entries.count
                }
            }
        }
    }
}
