import SwiftUI

enum BigOLearnLinks {
    static let bigOGuide = URL(string: "https://www.freecodecamp.org/news/big-o-notation-examples-time-complexity-explained/")!
}

struct BigOLearnSheet: View {
    let challenge: BigOChallenge
    let wasCorrect: Bool
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        resultBanner

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resposta correta")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.45))

                            Text(challenge.answer)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(BigOTheme.accentLight)
                        }

                        if let caseNote = challenge.caseNote {
                            Label(caseNote.capitalized, systemImage: "info.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }

                        section(title: "Por quê?", body: challenge.explanation)

                        if let hint = challenge.hint {
                            section(title: "Dica", body: hint)
                        }

                        if let url = URL(string: challenge.reference) {
                            RestGameSecondaryButton(title: "Ver referência") {
                                onReadMore?(url)
                            }
                        }

                        RestGameSecondaryButton(title: "Ler mais sobre Big O") {
                            onReadMore?(BigOLearnLinks.bigOGuide)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 8)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider().overlay(Color.white.opacity(0.12))

                    RestGamePrimaryButton(title: "Continuar") {
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Entender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var resultBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(wasCorrect ? .green : .orange)
            Text(wasCorrect ? "Você acertou!" : "Quase — revise abaixo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background((wasCorrect ? Color.green : Color.orange).opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BigOIntroLearnSheet: View {
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Big O mede como o tempo ou espaço cresce quando a entrada aumenta.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))

                        VStack(alignment: .leading, spacing: 10) {
                            introRow("O(1)", "Constante — não depende de n")
                            introRow("O(log n)", "Logarítmico — divide o problema")
                            introRow("O(n)", "Linear — um passe sobre n")
                            introRow("O(n²)", "Quadrático — loops aninhados")
                        }

                        Text("Analise loops, recursão e estruturas de dados. Sempre considere o pior caso, salvo indicação contrária.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        RestGameSecondaryButton(title: "Guia completo de Big O") {
                            onReadMore?(BigOLearnLinks.bigOGuide)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Dica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func introRow(_ notation: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(notation)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(BigOTheme.accentLight)
                .frame(width: 72, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
