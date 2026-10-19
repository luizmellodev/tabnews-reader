//
//  OnboardingView.swift
//  newtabnews
//
//  Created by Luiz Mello on 31/03/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "TabNews",
            subtitle: "O app não oficial da sua plataforma favorita de conteúdo de tecnologia",
            imageName: "square.text.square.fill",
            secondaryImageName: "square.text.square"
        ),
        OnboardingPage(
            title: "Notificações",
            subtitle: "Receba notificações locais sobre novas newsletters. Simples e direto.",
            imageName: "bell.fill",
            secondaryImageName: "bell.badge"
        ),
        OnboardingPage(
            title: "Leitura",
            subtitle: "Escolha como quer ler: no app ou no site oficial. Recomendamos o site para uma experiência markdown completa",
            imageName: "doc.text.fill",
            secondaryImageName: "arrow.up.forward.app"
        ),
        OnboardingPage(
            title: "Jogos Dev",
            subtitle: "Descanse entre as leituras com desafios diários como Regex Golf, DevWordle e Big O. Dispute rankings no Game Center!",
            imageName: "gamecontroller.fill",
            secondaryImageName: "trophy.fill"
        ),
        OnboardingPage(
            title: "Além do App",
            subtitle: "Widgets para tela inicial, Apple Watch e muito mais. Seu TabNews em todos os lugares!",
            imageName: "applewatch",
            secondaryImageName: "square.grid.2x2"
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
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            pageIndex: index,
                            currentPage: currentPage,
                            isLast: index == pages.count - 1,
                            screenSize: geometry.size,
                            completion: {
                                withAnimation {
                                    showOnboarding = false
                                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                                    // Garantir que os tips vão aparecer após o onboarding inicial
                                    UserDefaults.standard.set(false, forKey: "hasSeenTipsOnboarding")
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(currentPage == index ? 1.2 : 1)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding()
                .offset(y: geometry.size.height * 0.4)
            }
        }
    }
}

/// Também usado pelas dicas (OnboardingTipsView), para as duas telas terem o mesmo visual
struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let secondaryImageName: String
    var illustration: OnboardingIllustration = .none
}

enum OnboardingIllustration {
    case none
    /// Réplica em preto e branco do menu de toque longo dos posts
    case postMenu
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int
    let isLast: Bool
    let screenSize: CGSize
    var finishTitle = "Começar"
    let completion: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var showContent = false
    @State private var showIcon = false
    @State private var showSecondaryImage = false
    @State private var entranceTask: Task<Void, Never>?
    
    private var isActive: Bool { currentPage == pageIndex }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icons
            ZStack {
                // Principal entra girando com zoom
                Image(systemName: page.imageName)
                    .font(.system(size: 65, weight: .light))
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(showIcon ? 360 : 0))
                    .opacity(showIcon ? 1 : 0)
                    .scaleEffect(showIcon ? 1 : 0.5)
                
                // Secundário sai do centro e assenta inclinado no canto
                Image(systemName: page.secondaryImageName)
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(.primary.opacity(0.7))
                    .offset(x: showSecondaryImage ? 30 : 0, y: showSecondaryImage ? -30 : 0)
                    .rotationEffect(.degrees(showSecondaryImage ? 15 : 0))
                    .opacity(showSecondaryImage ? 1 : 0)
                    .scaleEffect(showSecondaryImage ? 1 : 0.5)
            }
            .frame(height: screenSize.height * 0.2)
            
            VStack(spacing: 24) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                Text(page.subtitle)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                if page.illustration == .postMenu {
                    OnboardingPostMenuIllustration()
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
            }
            
            Spacer()
            
            if isLast {
                Button {
                    completion()
                } label: {
                    Text(finishTitle)
                        .font(.headline)
                        .foregroundStyle(.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary)
                        }
                        .padding(.horizontal, 32)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
                .frame(height: 100)
        }
        .padding()
        .onAppear {
            syncWithActiveState()
        }
        .onChange(of: isActive) { _, _ in
            syncWithActiveState()
        }
        .onDisappear {
            entranceTask?.cancel()
        }
    }

    private func syncWithActiveState() {
        if isActive {
            playEntranceAnimation()
        } else {
            resetContent()
        }
    }

    private func resetContent() {
        entranceTask?.cancel()
        showContent = false
        showIcon = false
        showSecondaryImage = false
    }

    private func playEntranceAnimation() {
        entranceTask?.cancel()
        showContent = false
        showIcon = false
        showSecondaryImage = false

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                showIcon = true
                showContent = true
                showSecondaryImage = true
            }
            return
        }

        entranceTask = Task { @MainActor in
            // Aguarda um frame para o SwiftUI registrar o estado "oculto" antes de animar
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled, isActive else { return }

            withAnimation(.spring(duration: 0.7)) {
                showIcon = true
                showContent = true
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, isActive else { return }

            withAnimation(.spring(duration: 0.7)) {
                showSecondaryImage = true
            }
        }
    }
}

/// Mesmos itens e ordem do contextMenu de PostRow, em preto e branco
private struct OnboardingPostMenuIllustration: View {
    private let items: [(title: String, icon: String)] = [
        ("Curtir", "heart"),
        ("Ler Depois", "bookmark"),
        ("Ouvir Post", "speaker.wave.2"),
        ("Salvar em Pasta", "folder.badge.plus")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.title)
                    Spacer()
                    Image(systemName: item.icon)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

                if index < items.count - 1 {
                    Divider()
                }
            }
        }
        .foregroundStyle(.primary)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .frame(maxWidth: 240)
        .accessibilityElement(children: .combine)
    }
}
