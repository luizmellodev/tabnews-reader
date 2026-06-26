import SwiftUI

enum AlgoSpotLearnLinks {
    static let algorithmsGuide = URL(string: "https://www.geeksforgeeks.org/dsa/algorithms/")!
}

struct AlgoSpotLearnSheet: View {
    let challenge: AlgoSpotChallenge
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
                            Text("Algoritmo correto")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(.white.opacity(0.45))

                            Text(challenge.answer)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AlgoSpotTheme.accentLight)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let caseNote = challenge.caseNote {
                            Label("Complexidade: \(caseNote)", systemImage: "clock")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }

                        section(title: "O que é", body: challenge.whatItIs)

                        section(title: "Por quê este código?", body: challenge.explanation)

                        if let hint = challenge.hint {
                            section(title: "Dica", body: hint)
                        }

                        if let url = URL(string: challenge.reference) {
                            RestGameSecondaryButton(title: "Ver referência") {
                                onReadMore?(url)
                            }
                        }

                        RestGameSecondaryButton(title: "Guia de algoritmos") {
                            onReadMore?(AlgoSpotLearnLinks.algorithmsGuide)
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

struct AlgoSpotIntroLearnSheet: View {
    var onReadMore: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                RestGameBackground(animated: false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Leia o corpo do código — o nome da função foi removido de propósito.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))

                        VStack(alignment: .leading, spacing: 10) {
                            introRow("Loops", "Bubble, Selection, Insertion…")
                            introRow("Divide", "Merge sort, Quick sort, Busca binária…")
                            introRow("Grafos", "DFS, BFS, Dijkstra, Floyd-Warshall…")
                            introRow("Padrões", "Two pointers, Sliding window, Hash map…")
                        }

                        Text("Procure estruturas reconhecíveis: loops aninhados, recursão, filas, relaxamento de distâncias.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        RestGameSecondaryButton(title: "Guia de algoritmos") {
                            onReadMore?(AlgoSpotLearnLinks.algorithmsGuide)
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

    private func introRow(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AlgoSpotTheme.accentLight)
                .frame(width: 72, alignment: .leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
