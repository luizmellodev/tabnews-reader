import SwiftUI

/// Dicas de uso exibidas após o onboarding (e em Perfil > Ver Dicas Novamente).
/// Usa o mesmo OnboardingPageView do onboarding para manter o visual preto e branco.
struct OnboardingTipsView: View {
    @Binding var showOnboarding: Bool
    @State private var currentTip = 0

    private let tips: [OnboardingPage] = [
        OnboardingPage(
            title: "Segure um post",
            subtitle: "Na lista de posts, segure um item para ver os atalhos:",
            imageName: "hand.tap.fill",
            secondaryImageName: "ellipsis.circle",
            illustration: .postMenu
        ),
        OnboardingPage(
            title: "Destaque e anote",
            subtitle: "Dentro de um post, toque em Destacar e selecione o trecho. Use Anotar para guardar suas ideias sobre a leitura.",
            imageName: "highlighter",
            secondaryImageName: "note.text"
        ),
        OnboardingPage(
            title: "Sua Biblioteca",
            subtitle: "Curtidos, Ler Depois, destaques, anotações e pastas ficam na aba Biblioteca. Para criar uma pasta, toque no ícone de pasta com + no topo.",
            imageName: "books.vertical.fill",
            secondaryImageName: "folder.badge.plus"
        ),
        OnboardingPage(
            title: "Conheça quem escreve",
            subtitle: "Toque no @ do autor de um post ou comentário para ver o perfil, os TabCoins e as publicações da pessoa.",
            imageName: "person.crop.circle.fill",
            secondaryImageName: "at"
        ),
        OnboardingPage(
            title: "Jogos Dev",
            subtitle: "Na aba Perfil, abra Jogos Dev: desafios diários como Regex Golf, DevWordle e Big O, com rankings no Game Center.",
            imageName: "gamecontroller.fill",
            secondaryImageName: "trophy.fill"
        ),
        OnboardingPage(
            title: "App não oficial",
            subtitle: "Este app não é oficial do TabNews e não tem vínculo com Filipe Deschamps. É um projeto independente e open source, feito para complementar o site oficial.",
            imageName: "heart.fill",
            secondaryImageName: "chevron.left.forwardslash.chevron.right"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("Background")
                    .ignoresSafeArea()
                Image("ruido")
                    .resizable()
                    .scaledToFill()
                    .blendMode(.overlay)
                    .ignoresSafeArea()

                TabView(selection: $currentTip) {
                    ForEach(0..<tips.count, id: \.self) { index in
                        OnboardingPageView(
                            page: tips[index],
                            pageIndex: index,
                            currentPage: currentTip,
                            isLast: index == tips.count - 1,
                            screenSize: geometry.size,
                            finishTitle: "Começar a usar",
                            completion: completeTips
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack {
                    HStack {
                        Spacer()
                        if currentTip < tips.count - 1 {
                            Button("Pular", action: completeTips)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                    }
                    Spacer()
                }
                .animation(.easeOut(duration: 0.2), value: currentTip)

                // Mesmo indicador do onboarding
                HStack(spacing: 8) {
                    ForEach(0..<tips.count, id: \.self) { index in
                        Circle()
                            .fill(currentTip == index ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(currentTip == index ? 1.2 : 1)
                            .animation(.spring(), value: currentTip)
                    }
                }
                .padding()
                .offset(y: geometry.size.height * 0.4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dica \(currentTip + 1) de \(tips.count)")
            }
        }
    }

    private func completeTips() {
        UserDefaults.standard.set(true, forKey: "hasSeenTipsOnboarding")
        withAnimation {
            showOnboarding = false
        }
    }
}
